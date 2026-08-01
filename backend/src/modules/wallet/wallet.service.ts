import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  NotificationType,
  PaymentStatus,
  Prisma,
  TransactionSource,
  TransactionType,
} from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { buildPagination, paginate, PaginationQueryDto } from '../../common/utils/pagination.util';

@Injectable()
export class WalletService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly notifications: NotificationsService,
  ) {}

  async getBalance(userId: string) {
    const wallet = await this.ensureWallet(userId);
    return { walletId: wallet.id, balance: Number(wallet.balance) };
  }

  async getTransactions(userId: string, query: PaginationQueryDto) {
    const wallet = await this.ensureWallet(userId);
    const { skip, take, page, limit } = buildPagination(query);

    const [items, total] = await this.prisma.$transaction([
      this.prisma.transaction.findMany({
        where: { walletId: wallet.id },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.transaction.count({ where: { walletId: wallet.id } }),
    ]);

    return paginate(items, total, page, limit);
  }

  /**
   * Adds money to a wallet and records the ledger entry atomically. All
   * inbound money (refunds, referral bonuses, top-ups) flows through here.
   */
  async credit(
    userId: string,
    amount: number,
    source: TransactionSource,
    description: string,
    referenceId?: string,
  ) {
    if (amount <= 0) throw new BadRequestException('Credit amount must be positive');
    const wallet = await this.ensureWallet(userId);

    const updated = await this.prisma.$transaction(async (tx) => {
      const result = await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance: { increment: amount } },
      });

      await tx.transaction.create({
        data: {
          walletId: wallet.id,
          type: TransactionType.CREDIT,
          source,
          amount,
          description,
          referenceId,
        },
      });

      return result;
    });

    return { balance: Number(updated.balance) };
  }

  /** Removes money from a wallet, refusing to go negative. */
  async debit(
    userId: string,
    amount: number,
    source: TransactionSource,
    description: string,
    referenceId?: string,
  ) {
    if (amount <= 0) throw new BadRequestException('Debit amount must be positive');
    const wallet = await this.ensureWallet(userId);

    if (Number(wallet.balance) < amount) {
      throw new BadRequestException('Insufficient wallet balance');
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      // Conditional update guards against a concurrent debit draining the balance
      const affected = await tx.wallet.updateMany({
        where: { id: wallet.id, balance: { gte: amount } },
        data: { balance: { decrement: amount } },
      });
      if (affected.count === 0) {
        throw new BadRequestException('Insufficient wallet balance');
      }

      await tx.transaction.create({
        data: {
          walletId: wallet.id,
          type: TransactionType.DEBIT,
          source,
          amount,
          description,
          referenceId,
        },
      });

      return tx.wallet.findUniqueOrThrow({ where: { id: wallet.id } });
    });

    return { balance: Number(updated.balance) };
  }

  /** Resolves the caller's patient profile, then applies the referral code. */
  async applyReferralBonusForUser(userId: string, referralCode: string) {
    const patient = await this.prisma.patient.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!patient) throw new NotFoundException('Patient profile not found');
    return this.applyReferralBonus(referralCode, patient.id);
  }

  /**
   * Credits the referral bonus to the owner of the code and permanently links
   * the new patient to them so the code cannot be reused on this account.
   */
  async applyReferralBonus(referralCode: string, newPatientId: string) {
    const referrer = await this.prisma.patient.findUnique({
      where: { referralCode },
      select: { id: true, userId: true },
    });
    if (!referrer) throw new BadRequestException('Invalid referral code');
    if (referrer.id === newPatientId) {
      throw new BadRequestException('You cannot refer yourself');
    }

    const newPatient = await this.prisma.patient.findUnique({
      where: { id: newPatientId },
      select: { referredById: true },
    });
    if (newPatient?.referredById) {
      throw new BadRequestException('A referral code has already been applied to this account');
    }

    const bonus = Number(this.config.get<string>('REFERRAL_BONUS', '100'));

    await this.prisma.patient.update({
      where: { id: newPatientId },
      data: { referredById: referrer.id },
    });

    await this.credit(
      referrer.userId,
      bonus,
      TransactionSource.REFERRAL_BONUS,
      'Referral bonus',
      newPatientId,
    );

    await this.notifications.send({
      userId: referrer.userId,
      type: NotificationType.OFFER,
      title: 'Referral bonus credited',
      body: `₹${bonus} has been added to your wallet for a successful referral.`,
    });

    return { message: `Referral applied. ₹${bonus} credited to the referrer.` };
  }

  // -------------------------------------------------------
  // THERAPIST EARNINGS
  // -------------------------------------------------------

  /**
   * Aggregates earnings from completed, paid appointments over a period.
   * The platform fee is excluded because it is never the therapist's money.
   */
  async getTherapistEarnings(userId: string, period: 'daily' | 'weekly' | 'monthly' | 'yearly') {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!therapist) throw new NotFoundException('Therapist profile not found');

    const { start, previousStart } = this.periodBounds(period);

    const currentRows = await this.prisma.appointment.findMany({
      where: {
        therapistId: therapist.id,
        status: 'COMPLETED',
        scheduledDate: { gte: start },
        payment: { status: PaymentStatus.PAID },
      },
      select: { type: true, consultationFee: true },
    });

    const previousRows = await this.prisma.appointment.findMany({
      where: {
        therapistId: therapist.id,
        status: 'COMPLETED',
        scheduledDate: { gte: previousStart, lt: start },
        payment: { status: PaymentStatus.PAID },
      },
      select: { consultationFee: true },
    });

    const sum = (rows: { consultationFee: Prisma.Decimal }[]) =>
      rows.reduce((acc, r) => acc + Number(r.consultationFee), 0);

    const total = sum(currentRows);
    const previousTotal = sum(previousRows);

    const byType = currentRows.reduce<Record<string, number>>((acc, row) => {
      acc[row.type] = (acc[row.type] ?? 0) + Number(row.consultationFee);
      return acc;
    }, {});

    const changePercent =
      previousTotal === 0 ? (total > 0 ? 100 : 0) : ((total - previousTotal) / previousTotal) * 100;

    return {
      period,
      totalEarnings: Math.round(total * 100) / 100,
      previousPeriodEarnings: Math.round(previousTotal * 100) / 100,
      changePercent: Math.round(changePercent * 10) / 10,
      breakdown: {
        clinicVisit: byType.CLINIC_VISIT ?? 0,
        homeVisit: byType.HOME_VISIT ?? 0,
        videoConsultation: byType.VIDEO_CONSULTATION ?? 0,
      },
      sessionCount: currentRows.length,
    };
  }

  /** Payout history for the therapist wallet screen. */
  async getPayouts(userId: string, query: PaginationQueryDto) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!therapist) throw new NotFoundException('Therapist profile not found');

    const { skip, take, page, limit } = buildPagination(query);

    const [items, total] = await this.prisma.$transaction([
      this.prisma.payout.findMany({
        where: { therapistId: therapist.id },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.payout.count({ where: { therapistId: therapist.id } }),
    ]);

    return paginate(items, total, page, limit);
  }

  // -------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------

  /** Lazily creates the wallet so legacy accounts never hit a missing row. */
  private async ensureWallet(userId: string) {
    const existing = await this.prisma.wallet.findUnique({ where: { userId } });
    if (existing) return existing;
    return this.prisma.wallet.create({ data: { userId } });
  }

  private periodBounds(period: 'daily' | 'weekly' | 'monthly' | 'yearly') {
    const start = new Date();
    const previousStart = new Date();

    switch (period) {
      case 'daily':
        start.setHours(0, 0, 0, 0);
        previousStart.setDate(previousStart.getDate() - 1);
        previousStart.setHours(0, 0, 0, 0);
        break;
      case 'weekly':
        start.setDate(start.getDate() - start.getDay());
        start.setHours(0, 0, 0, 0);
        previousStart.setTime(start.getTime() - 7 * 86_400_000);
        break;
      case 'monthly':
        start.setDate(1);
        start.setHours(0, 0, 0, 0);
        previousStart.setMonth(start.getMonth() - 1, 1);
        previousStart.setHours(0, 0, 0, 0);
        break;
      case 'yearly':
        start.setMonth(0, 1);
        start.setHours(0, 0, 0, 0);
        previousStart.setFullYear(start.getFullYear() - 1, 0, 1);
        previousStart.setHours(0, 0, 0, 0);
        break;
    }

    return { start, previousStart };
  }
}
