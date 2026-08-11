import {
  BadRequestException,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { AuthProvider, User, UserRole } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { PrismaService } from '../../database/prisma.service';
import { FirebaseService } from '../notifications/firebase.service';
import { SmsService } from './sms.service';
import {
  AuthTokensDto,
  ForgotPasswordDto,
  PasswordLoginDto,
  ResetPasswordDto,
  SendOtpDto,
  SocialLoginDto,
  VerifyOtpDto,
} from './dto/auth.dto';

const OTP_TTL_SECONDS = 300; // 5 minutes
const OTP_MAX_ATTEMPTS = 5;
const BCRYPT_ROUNDS = 12;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly sms: SmsService,
    private readonly firebase: FirebaseService,
  ) {}

  // -------------------------------------------------------
  // OTP LOGIN
  // -------------------------------------------------------

  /**
   * Generates a 6-digit OTP, stores only its bcrypt hash, and dispatches
   * it via SMS. The plain code is never persisted or returned.
   */
  async sendOtp(dto: SendOtpDto): Promise<{ message: string; expiresIn: number }> {
    const phone = dto.phone;

    // Throttle: block if 3+ unconsumed OTPs were issued in the last 10 minutes
    const recentCount = await this.prisma.otpCode.count({
      where: {
        phone,
        consumed: false,
        createdAt: { gte: new Date(Date.now() - 10 * 60 * 1000) },
      },
    });
    if (recentCount >= 3) {
      throw new BadRequestException('Too many OTP requests. Please try again later.');
    }

    const code = this.generateNumericCode(6);
    const codeHash = await bcrypt.hash(code, BCRYPT_ROUNDS);

    const existingUser = await this.prisma.user.findUnique({ where: { phone } });

    await this.prisma.otpCode.create({
      data: {
        phone,
        codeHash,
        purpose: 'LOGIN',
        userId: existingUser?.id,
        expiresAt: new Date(Date.now() + OTP_TTL_SECONDS * 1000),
      },
    });

    await this.sms.sendOtp(`${dto.countryCode ?? '+91'}${phone}`, code);

    return { message: 'OTP sent successfully', expiresIn: OTP_TTL_SECONDS };
  }

  /**
   * Verifies the OTP. If the phone number is new, a user record (plus the
   * role-specific profile and wallet) is created in a single transaction.
   */
  async verifyOtp(dto: VerifyOtpDto): Promise<AuthTokensDto & { user: SafeUser }> {
    const otpRecord = await this.prisma.otpCode.findFirst({
      where: { phone: dto.phone, consumed: false, purpose: 'LOGIN' },
      orderBy: { createdAt: 'desc' },
    });

    if (!otpRecord) throw new BadRequestException('No active OTP found. Please request a new one.');
    if (otpRecord.expiresAt < new Date()) throw new BadRequestException('OTP has expired');
    if (otpRecord.attempts >= OTP_MAX_ATTEMPTS) {
      throw new BadRequestException('Maximum attempts exceeded. Request a new OTP.');
    }

    const isValid = await bcrypt.compare(dto.otp, otpRecord.codeHash);
    if (!isValid) {
      await this.prisma.otpCode.update({
        where: { id: otpRecord.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException('Invalid OTP');
    }

    await this.prisma.otpCode.update({
      where: { id: otpRecord.id },
      data: { consumed: true },
    });

    let user = await this.prisma.user.findUnique({ where: { phone: dto.phone } });
    if (!user) {
      user = await this.createUserWithProfile({
        phone: dto.phone,
        role: UserRole.PATIENT,
        fullName: 'New User',
        authProvider: AuthProvider.PHONE_OTP,
      });
    }

    await this.markVerifiedAndStoreFcm(user.id, dto.fcmToken);
    return this.issueSession(user);
  }

  // -------------------------------------------------------
  // SOCIAL LOGIN (Google / Apple via Firebase)
  // -------------------------------------------------------

  /**
   * Verifies a Firebase ID token server-side, then links or creates the
   * matching local user. Works for both Google and Apple sign-in because
   * Firebase normalises both into the same token format.
   */
  async socialLogin(dto: SocialLoginDto): Promise<AuthTokensDto & { user: SafeUser }> {
    const decoded = await this.firebase.verifyIdToken(dto.idToken);

    const provider =
      decoded.firebase?.sign_in_provider === 'apple.com'
        ? AuthProvider.APPLE
        : AuthProvider.GOOGLE;

    let user = await this.prisma.user.findFirst({
      where: {
        OR: [
          { firebaseUid: decoded.uid },
          ...(decoded.email ? [{ email: decoded.email }] : []),
        ],
      },
    });

    if (user) {
      // Link the Firebase UID on first social sign-in for an existing account
      if (!user.firebaseUid) {
        user = await this.prisma.user.update({
          where: { id: user.id },
          data: { firebaseUid: decoded.uid, authProvider: provider },
        });
      }
    } else {
      user = await this.createUserWithProfile({
        phone: decoded.phone_number?.replace(/^\+91/, '') ?? `fb_${decoded.uid.slice(0, 10)}`,
        email: decoded.email ?? null,
        fullName: decoded.name ?? 'New User',
        avatarUrl: decoded.picture ?? null,
        firebaseUid: decoded.uid,
        role: dto.role ?? UserRole.PATIENT,
        authProvider: provider,
      });
    }

    await this.markVerifiedAndStoreFcm(user.id, dto.fcmToken);
    return this.issueSession(user);
  }

  // -------------------------------------------------------
  // PASSWORD LOGIN (therapist / admin)
  // -------------------------------------------------------

  async passwordLogin(dto: PasswordLoginDto): Promise<AuthTokensDto & { user: SafeUser }> {
    const user = await this.prisma.user.findUnique({ where: { phone: dto.phone } });

    // Same generic error for unknown user and wrong password (no user enumeration)
    if (!user?.passwordHash) throw new UnauthorizedException('Invalid credentials');
    if (!user.isActive) throw new UnauthorizedException('Account is deactivated');

    const matches = await bcrypt.compare(dto.password, user.passwordHash);
    if (!matches) throw new UnauthorizedException('Invalid credentials');

    await this.markVerifiedAndStoreFcm(user.id, dto.fcmToken);
    return this.issueSession(user);
  }

  // -------------------------------------------------------
  // FORGOT / RESET PASSWORD
  // -------------------------------------------------------

  async forgotPassword(dto: ForgotPasswordDto): Promise<{ message: string }> {
    const user = await this.prisma.user.findUnique({ where: { phone: dto.phone } });

    // Always return success to avoid leaking which numbers are registered
    if (user) {
      const code = this.generateNumericCode(6);
      await this.prisma.otpCode.create({
        data: {
          phone: dto.phone,
          userId: user.id,
          codeHash: await bcrypt.hash(code, BCRYPT_ROUNDS),
          purpose: 'RESET_PASSWORD',
          expiresAt: new Date(Date.now() + OTP_TTL_SECONDS * 1000),
        },
      });
      await this.sms.sendPasswordResetOtp(`+91${dto.phone}`, code);
    }

    return { message: 'If the number is registered, a reset OTP has been sent' };
  }

  async resetPassword(dto: ResetPasswordDto): Promise<{ message: string }> {
    const otpRecord = await this.prisma.otpCode.findFirst({
      where: { phone: dto.phone, purpose: 'RESET_PASSWORD', consumed: false },
      orderBy: { createdAt: 'desc' },
    });

    if (!otpRecord || otpRecord.expiresAt < new Date()) {
      throw new BadRequestException('Invalid or expired OTP');
    }
    if (!(await bcrypt.compare(dto.otp, otpRecord.codeHash))) {
      await this.prisma.otpCode.update({
        where: { id: otpRecord.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException('Invalid OTP');
    }

    const passwordHash = await bcrypt.hash(dto.newPassword, BCRYPT_ROUNDS);

    await this.prisma.$transaction([
      this.prisma.otpCode.update({ where: { id: otpRecord.id }, data: { consumed: true } }),
      this.prisma.user.update({
        where: { phone: dto.phone },
        data: { passwordHash },
      }),
      // Force re-login everywhere after a password change
      this.prisma.refreshToken.updateMany({
        where: { userId: otpRecord.userId ?? undefined },
        data: { revoked: true },
      }),
    ]);

    return { message: 'Password reset successfully' };
  }

  // -------------------------------------------------------
  // TOKEN MANAGEMENT
  // -------------------------------------------------------

  /**
   * Rotates the refresh token: the presented token is revoked and a fresh
   * pair is issued. Reuse of a revoked token is treated as theft and revokes
   * the entire family for that user.
   */
  async refreshTokens(refreshToken: string): Promise<AuthTokensDto> {
    let payload: { sub: string };
    try {
      payload = await this.jwt.verifyAsync(refreshToken, {
        secret: this.config.getOrThrow<string>('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const tokenHash = this.hashToken(refreshToken);
    const stored = await this.prisma.refreshToken.findFirst({
      where: { userId: payload.sub, tokenHash },
    });

    if (!stored) throw new UnauthorizedException('Refresh token not recognised');

    if (stored.revoked) {
      await this.prisma.refreshToken.updateMany({
        where: { userId: payload.sub },
        data: { revoked: true },
      });
      throw new UnauthorizedException('Refresh token reuse detected. Please log in again.');
    }

    if (stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Refresh token expired');
    }

    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: payload.sub } });

    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { revoked: true },
    });

    const { user: _omit, ...tokens } = await this.issueSession(user);
    return tokens;
  }

  async logout(userId: string, refreshToken?: string): Promise<{ message: string }> {
    if (refreshToken) {
      await this.prisma.refreshToken.updateMany({
        where: { userId, tokenHash: this.hashToken(refreshToken) },
        data: { revoked: true },
      });
    } else {
      await this.prisma.refreshToken.updateMany({ where: { userId }, data: { revoked: true } });
    }
    return { message: 'Logged out successfully' };
  }

  // -------------------------------------------------------
  // INTERNALS
  // -------------------------------------------------------

  private async issueSession(user: User): Promise<AuthTokensDto & { user: SafeUser }> {
    const payload = { sub: user.id, role: user.role, phone: user.phone };

    const accessExpiry = this.config.get<string>('JWT_ACCESS_EXPIRY', '15m');
    const refreshExpiry = this.config.get<string>('JWT_REFRESH_EXPIRY', '30d');

    const accessToken = await this.jwt.signAsync(payload, {
      secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
      expiresIn: accessExpiry,
    });

    const refreshToken = await this.jwt.signAsync(
      { sub: user.id },
      {
        secret: this.config.getOrThrow<string>('JWT_REFRESH_SECRET'),
        expiresIn: refreshExpiry,
      },
    );

    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: this.hashToken(refreshToken),
        expiresAt: new Date(Date.now() + this.parseDuration(refreshExpiry)),
      },
    });

    return {
      accessToken,
      refreshToken,
      expiresIn: Math.floor(this.parseDuration(accessExpiry) / 1000),
      user: this.toSafeUser(user),
    };
  }

  /** Creates the user plus role profile and wallet atomically. */
  private async createUserWithProfile(data: {
    phone: string;
    role: UserRole;
    fullName: string;
    authProvider: AuthProvider;
    email?: string | null;
    avatarUrl?: string | null;
    firebaseUid?: string | null;
  }): Promise<User> {
    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          phone: data.phone,
          role: data.role,
          fullName: data.fullName,
          email: data.email ?? null,
          avatarUrl: data.avatarUrl ?? null,
          firebaseUid: data.firebaseUid ?? null,
          authProvider: data.authProvider,
          isVerified: true,
        },
      });

      await tx.wallet.create({ data: { userId: user.id } });

      if (data.role === UserRole.PATIENT) {
        await tx.patient.create({ data: { userId: user.id } });
      } else if (data.role === UserRole.THERAPIST) {
        await tx.therapist.create({ data: { userId: user.id } });
      }

      return user;
    });
  }

  private async markVerifiedAndStoreFcm(userId: string, fcmToken?: string) {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    const existingTokens = (user.fcmTokens as string[]) ?? [];
    const tokens = fcmToken
      ? Array.from(new Set([...existingTokens, fcmToken]))
      : existingTokens;

    await this.prisma.user.update({
      where: { id: userId },
      data: { isVerified: true, fcmTokens: tokens },
    });
  }

  private generateNumericCode(length: number): string {
    // crypto.randomInt is cryptographically secure, unlike Math.random
    const max = 10 ** length;
    return crypto.randomInt(0, max).toString().padStart(length, '0');
  }

  /** Refresh tokens are stored as SHA-256 digests so a DB leak cannot replay them. */
  private hashToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  /** Converts "15m" / "30d" / "24h" / "60s" into milliseconds. */
  private parseDuration(value: string): number {
    const match = /^(\d+)([smhd])$/.exec(value.trim());
    if (!match) return 15 * 60 * 1000;
    const amount = Number(match[1]);
    const unit = match[2];
    const factors: Record<string, number> = {
      s: 1000,
      m: 60_000,
      h: 3_600_000,
      d: 86_400_000,
    };
    return amount * factors[unit];
  }

  private toSafeUser(user: User): SafeUser {
    return {
      id: user.id,
      fullName: user.fullName,
      phone: user.phone,
      email: user.email,
      role: user.role,
      avatarUrl: user.avatarUrl,
      isVerified: user.isVerified,
    };
  }
}

export interface SafeUser {
  id: string;
  fullName: string;
  phone: string;
  email: string | null;
  role: UserRole;
  avatarUrl: string | null;
  isVerified: boolean;
}
