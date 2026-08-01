import { Injectable } from '@nestjs/common';
import {
  AppointmentStatus,
  AppointmentType,
  KycStatus,
  PaymentStatus,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { AnalyticsRangeDto } from './dto/admin.dto';

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Top KPI cards on the admin dashboard. Each metric is paired with its
   * month-over-month change so the UI can render the trend arrows.
   */
  async getDashboardStats() {
    const now = new Date();
    const thisMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const lastMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);

    const [
      totalUsers,
      totalTherapists,
      totalPatients,
      totalAppointments,
      revenueAgg,
      usersThisMonth,
      usersLastMonth,
      therapistsThisMonth,
      therapistsLastMonth,
      patientsThisMonth,
      patientsLastMonth,
      apptThisMonth,
      apptLastMonth,
      revenueThisMonth,
      revenueLastMonth,
    ] = await this.prisma.$transaction([
      this.prisma.user.count(),
      this.prisma.therapist.count(),
      this.prisma.patient.count(),
      this.prisma.appointment.count(),
      this.prisma.payment.aggregate({
        where: { status: PaymentStatus.PAID },
        _sum: { amount: true },
      }),
      this.prisma.user.count({ where: { createdAt: { gte: thisMonthStart } } }),
      this.prisma.user.count({
        where: { createdAt: { gte: lastMonthStart, lt: thisMonthStart } },
      }),
      this.prisma.therapist.count({ where: { createdAt: { gte: thisMonthStart } } }),
      this.prisma.therapist.count({
        where: { createdAt: { gte: lastMonthStart, lt: thisMonthStart } },
      }),
      this.prisma.patient.count({ where: { createdAt: { gte: thisMonthStart } } }),
      this.prisma.patient.count({
        where: { createdAt: { gte: lastMonthStart, lt: thisMonthStart } },
      }),
      this.prisma.appointment.count({ where: { createdAt: { gte: thisMonthStart } } }),
      this.prisma.appointment.count({
        where: { createdAt: { gte: lastMonthStart, lt: thisMonthStart } },
      }),
      this.prisma.payment.aggregate({
        where: { status: PaymentStatus.PAID, createdAt: { gte: thisMonthStart } },
        _sum: { amount: true },
      }),
      this.prisma.payment.aggregate({
        where: {
          status: PaymentStatus.PAID,
          createdAt: { gte: lastMonthStart, lt: thisMonthStart },
        },
        _sum: { amount: true },
      }),
    ]);

    return {
      totalUsers: { value: totalUsers, changePercent: this.change(usersThisMonth, usersLastMonth) },
      therapists: {
        value: totalTherapists,
        changePercent: this.change(therapistsThisMonth, therapistsLastMonth),
      },
      patients: {
        value: totalPatients,
        changePercent: this.change(patientsThisMonth, patientsLastMonth),
      },
      totalAppointments: {
        value: totalAppointments,
        changePercent: this.change(apptThisMonth, apptLastMonth),
      },
      totalRevenue: {
        value: Number(revenueAgg._sum.amount ?? 0),
        changePercent: this.change(
          Number(revenueThisMonth._sum.amount ?? 0),
          Number(revenueLastMonth._sum.amount ?? 0),
        ),
      },
    };
  }

  /** Secondary cards: pending payments, unpaid bookings, leave, active offers. */
  async getSecondaryStats() {
    const now = new Date();

    const [pendingPayments, unpaidAppointments, therapistsOnLeave, activeOffers] =
      await this.prisma.$transaction([
        this.prisma.payment.aggregate({
          where: { status: PaymentStatus.PENDING },
          _count: { _all: true },
          _sum: { amount: true },
        }),
        this.prisma.appointment.aggregate({
          where: {
            payment: null,
            status: { in: [AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED] },
          },
          _count: { _all: true },
          _sum: { totalAmount: true },
        }),
        this.prisma.therapist.count({ where: { isAvailable: false } }),
        this.prisma.coupon.count({
          where: { isActive: true, validFrom: { lte: now }, validUntil: { gte: now } },
        }),
      ]);

    return {
      pendingPayments: {
        count: pendingPayments._count._all,
        amount: Number(pendingPayments._sum.amount ?? 0),
      },
      unpaidAppointments: {
        count: unpaidAppointments._count._all,
        amount: Number(unpaidAppointments._sum.totalAmount ?? 0),
      },
      therapistsOnLeave,
      activeOffers,
    };
  }

  /**
   * Monthly appointment counts split by outcome, used by the stacked line
   * chart. Months with no data are emitted as zeros so the axis stays even.
   */
  async getAppointmentsOverview(months = 6) {
    const start = this.monthsAgo(months - 1);

    const rows = await this.prisma.appointment.findMany({
      where: { scheduledDate: { gte: start } },
      select: { scheduledDate: true, status: true },
    });

    const buckets = this.emptyMonthBuckets(months, () => ({
      completed: 0,
      upcoming: 0,
      cancelled: 0,
    }));

    for (const row of rows) {
      const key = this.monthKey(row.scheduledDate);
      const bucket = buckets.get(key);
      if (!bucket) continue;

      if (row.status === AppointmentStatus.COMPLETED) bucket.completed += 1;
      else if (
        row.status === AppointmentStatus.CANCELLED ||
        row.status === AppointmentStatus.REJECTED
      )
        bucket.cancelled += 1;
      else bucket.upcoming += 1;
    }

    return Array.from(buckets.entries()).map(([month, values]) => ({ month, ...values }));
  }

  /** Monthly captured revenue for the bar chart. */
  async getRevenueOverview(months = 6) {
    const start = this.monthsAgo(months - 1);

    const rows = await this.prisma.payment.findMany({
      where: { status: PaymentStatus.PAID, createdAt: { gte: start } },
      select: { createdAt: true, amount: true },
    });

    const buckets = this.emptyMonthBuckets(months, () => ({ revenue: 0 }));

    for (const row of rows) {
      const bucket = buckets.get(this.monthKey(row.createdAt));
      if (bucket) bucket.revenue += Number(row.amount);
    }

    const series = Array.from(buckets.entries()).map(([month, values]) => ({
      month,
      revenue: Math.round(values.revenue * 100) / 100,
    }));

    return {
      series,
      total: series.reduce((sum, point) => sum + point.revenue, 0),
    };
  }

  /** Donut chart: share of bookings by appointment type. */
  async getAppointmentsByType() {
    const grouped = await this.prisma.appointment.groupBy({
      by: ['type'],
      _count: { _all: true },
    });

    const total = grouped.reduce((sum, g) => sum + g._count._all, 0) || 1;

    return Object.values(AppointmentType).map((type) => {
      const count = grouped.find((g) => g.type === type)?._count._all ?? 0;
      return {
        type,
        count,
        percentage: Math.round((count / total) * 1000) / 10,
      };
    });
  }

  /** Leaderboard of therapists by completed appointment volume. */
  async getTopTherapists(limit = 5) {
    const therapists = await this.prisma.therapist.findMany({
      take: limit,
      orderBy: [{ ratingAvg: 'desc' }, { ratingCount: 'desc' }],
      select: {
        id: true,
        ratingAvg: true,
        user: { select: { fullName: true, avatarUrl: true } },
        _count: { select: { appointments: { where: { status: AppointmentStatus.COMPLETED } } } },
      },
    });

    return therapists.map((t) => ({
      id: t.id,
      fullName: t.user.fullName,
      avatarUrl: t.user.avatarUrl,
      rating: t.ratingAvg,
      appointmentCount: t._count.appointments,
    }));
  }

  /** Latest bookings table on the dashboard. */
  async getLatestAppointments(limit = 5) {
    return this.prisma.appointment.findMany({
      take: limit,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        type: true,
        status: true,
        scheduledDate: true,
        startTime: true,
        totalAmount: true,
        patient: { select: { user: { select: { fullName: true, avatarUrl: true } } } },
        therapist: { select: { user: { select: { fullName: true } } } },
        payment: { select: { status: true } },
      },
    });
  }

  async getRecentReviews(limit = 5) {
    return this.prisma.review.findMany({
      take: limit,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        rating: true,
        comment: true,
        createdAt: true,
        author: { select: { fullName: true, avatarUrl: true } },
        therapist: { select: { user: { select: { fullName: true } } } },
      },
    });
  }

  /**
   * Exportable revenue report over an arbitrary date range, broken down by
   * appointment type and net of refunds.
   */
  async getRevenueReport(dto: AnalyticsRangeDto) {
    const from = new Date(dto.fromDate);
    const to = new Date(`${dto.toDate}T23:59:59`);

    const [payments, refundAgg] = await this.prisma.$transaction([
      this.prisma.payment.findMany({
        where: {
          status: { in: [PaymentStatus.PAID, PaymentStatus.PARTIALLY_REFUNDED] },
          createdAt: { gte: from, lte: to },
        },
        select: {
          amount: true,
          createdAt: true,
          appointment: { select: { type: true, platformFee: true, consultationFee: true } },
        },
      }),
      this.prisma.refund.aggregate({
        where: { createdAt: { gte: from, lte: to } },
        _sum: { amount: true },
        _count: { _all: true },
      }),
    ]);

    const byType = payments.reduce<Record<string, { count: number; amount: number }>>(
      (acc, payment) => {
        const key = payment.appointment.type;
        acc[key] ??= { count: 0, amount: 0 };
        acc[key].count += 1;
        acc[key].amount += Number(payment.amount);
        return acc;
      },
      {},
    );

    const gross = payments.reduce((sum, p) => sum + Number(p.amount), 0);
    const platformEarnings = payments.reduce(
      (sum, p) => sum + Number(p.appointment.platformFee),
      0,
    );
    const refunded = Number(refundAgg._sum.amount ?? 0);

    return {
      range: { from: dto.fromDate, to: dto.toDate },
      grossRevenue: Math.round(gross * 100) / 100,
      refundedAmount: Math.round(refunded * 100) / 100,
      netRevenue: Math.round((gross - refunded) * 100) / 100,
      platformEarnings: Math.round(platformEarnings * 100) / 100,
      transactionCount: payments.length,
      refundCount: refundAgg._count._all,
      byType,
    };
  }

  /** Growth report: new signups and bookings per month over a range. */
  async getGrowthReport(months = 12) {
    const start = this.monthsAgo(months - 1);

    const [users, appointments] = await this.prisma.$transaction([
      this.prisma.user.findMany({
        where: { createdAt: { gte: start } },
        select: { createdAt: true, role: true },
      }),
      this.prisma.appointment.findMany({
        where: { createdAt: { gte: start } },
        select: { createdAt: true },
      }),
    ]);

    const buckets = this.emptyMonthBuckets(months, () => ({
      patients: 0,
      therapists: 0,
      appointments: 0,
    }));

    for (const user of users) {
      const bucket = buckets.get(this.monthKey(user.createdAt));
      if (!bucket) continue;
      if (user.role === UserRole.PATIENT) bucket.patients += 1;
      if (user.role === UserRole.THERAPIST) bucket.therapists += 1;
    }

    for (const appointment of appointments) {
      const bucket = buckets.get(this.monthKey(appointment.createdAt));
      if (bucket) bucket.appointments += 1;
    }

    return Array.from(buckets.entries()).map(([month, values]) => ({ month, ...values }));
  }

  /** Counts that drive the sidebar badges and the KYC queue. */
  async getPendingCounts() {
    const [kyc, tickets, refunds, payouts] = await this.prisma.$transaction([
      this.prisma.therapist.count({ where: { kycStatus: KycStatus.PENDING } }),
      this.prisma.supportTicket.count({ where: { status: 'OPEN' } }),
      this.prisma.refund.count({ where: { status: PaymentStatus.PENDING } }),
      this.prisma.payout.count({ where: { status: PaymentStatus.PENDING } }),
    ]);

    return { pendingKyc: kyc, openTickets: tickets, pendingRefunds: refunds, pendingPayouts: payouts };
  }

  // -------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------

  private change(current: number, previous: number): number {
    if (previous === 0) return current > 0 ? 100 : 0;
    return Math.round(((current - previous) / previous) * 1000) / 10;
  }

  private monthsAgo(count: number): Date {
    const date = new Date();
    date.setMonth(date.getMonth() - count, 1);
    date.setHours(0, 0, 0, 0);
    return date;
  }

  private monthKey(date: Date): string {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
  }

  /** Pre-seeds a map with one entry per month so gaps render as zeros. */
  private emptyMonthBuckets<T>(months: number, factory: () => T): Map<string, T> {
    const buckets = new Map<string, T>();
    for (let i = months - 1; i >= 0; i--) {
      const date = new Date();
      date.setMonth(date.getMonth() - i, 1);
      buckets.set(this.monthKey(date), factory());
    }
    return buckets;
  }
}
