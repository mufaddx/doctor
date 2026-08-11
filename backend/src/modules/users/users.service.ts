import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../database/prisma.service';
import { UploadsService } from '../uploads/uploads.service';
import { ChangePasswordDto, UpdateProfileDto } from './dto/user.dto';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly uploads: UploadsService,
  ) {}

  /**
   * Returns the full profile including the role-specific relation so the
   * mobile apps can hydrate their entire profile screen in one call.
   */
  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        countryCode: true,
        avatarUrl: true,
        role: true,
        isVerified: true,
        createdAt: true,
        wallet: { select: { balance: true } },
        patient: {
          select: {
            id: true,
            dateOfBirth: true,
            gender: true,
            medicalHistory: true,
            referralCode: true,
            addresses: { orderBy: { isDefault: 'desc' } },
          },
        },
        therapist: {
          select: {
            id: true,
            specialization: true,
            experienceYears: true,
            bio: true,
            clinicFee: true,
            homeVisitFee: true,
            videoFee: true,
            ratingAvg: true,
            ratingCount: true,
            kycStatus: true,
            isAvailable: true,
            clinicAddress: true,
          },
        },
        admin: { select: { id: true, permissions: true, isSuper: true } },
      },
    });

    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    // Email uniqueness must be checked explicitly to return a friendly message
    if (dto.email) {
      const clash = await this.prisma.user.findFirst({
        where: { email: dto.email, NOT: { id: userId } },
        select: { id: true },
      });
      if (clash) throw new BadRequestException('This email is already in use');
    }

    return this.prisma.user.update({
      where: { id: userId },
      data: {
        fullName: dto.fullName,
        email: dto.email,
        patient:
          dto.dateOfBirth || dto.gender || dto.medicalHistory
            ? {
                update: {
                  dateOfBirth: dto.dateOfBirth ? new Date(dto.dateOfBirth) : undefined,
                  gender: dto.gender,
                  medicalHistory: dto.medicalHistory,
                },
              }
            : undefined,
      },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        avatarUrl: true,
        role: true,
      },
    });
  }

  /** Uploads the avatar to Firebase Storage and stores the public URL. */
  async updateAvatar(userId: string, file: Express.Multer.File) {
    if (!file) throw new BadRequestException('No image file provided');

    const url = await this.uploads.uploadImage(file, `avatars/${userId}`);

    return this.prisma.user.update({
      where: { id: userId },
      data: { avatarUrl: url },
      select: { id: true, avatarUrl: true },
    });
  }

  async changePassword(userId: string, dto: ChangePasswordDto) {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });

    if (!user.passwordHash) {
      throw new BadRequestException(
        'This account uses OTP or social login and has no password set',
      );
    }
    if (!(await bcrypt.compare(dto.currentPassword, user.passwordHash))) {
      throw new BadRequestException('Current password is incorrect');
    }

    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: { passwordHash: await bcrypt.hash(dto.newPassword, 12) },
      }),
      // Invalidate all sessions so a stolen token cannot survive the change
      this.prisma.refreshToken.updateMany({
        where: { userId },
        data: { revoked: true },
      }),
    ]);

    return { message: 'Password changed successfully. Please log in again.' };
  }

  async registerFcmToken(userId: string, token: string) {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { fcmTokens: true },
    });
    const fcmTokens = (user.fcmTokens as string[]) ?? [];

    if (!fcmTokens.includes(token)) {
      await this.prisma.user.update({
        where: { id: userId },
        data: { fcmTokens: [...fcmTokens, token] },
      });
    }
    return { message: 'Device registered for push notifications' };
  }

  async removeFcmToken(userId: string, token: string) {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { fcmTokens: true },
    });
    const fcmTokens = (user.fcmTokens as string[]) ?? [];

    await this.prisma.user.update({
      where: { id: userId },
      data: { fcmTokens: fcmTokens.filter((t) => t !== token) },
    });
    return { message: 'Device unregistered' };
  }

  /**
   * Soft delete: the account is deactivated and sessions killed, but the
   * records are retained because appointments and payments reference them
   * and healthcare records must remain auditable.
   */
  async deactivateAccount(userId: string) {
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: { isActive: false, fcmTokens: [] },
      }),
      this.prisma.refreshToken.updateMany({ where: { userId }, data: { revoked: true } }),
    ]);
    return { message: 'Account deactivated' };
  }

  /** Resolves the patient profile id for a given user id. */
  async getPatientId(userId: string): Promise<string> {
    const patient = await this.prisma.patient.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!patient) throw new NotFoundException('Patient profile not found');
    return patient.id;
  }

  /** Resolves the therapist profile id for a given user id. */
  async getTherapistId(userId: string): Promise<string> {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!therapist) throw new NotFoundException('Therapist profile not found');
    return therapist.id;
  }

  async assertRole(userId: string, role: UserRole) {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { role: true },
    });
    return user.role === role;
  }
}
