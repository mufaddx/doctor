import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  KycStatus,
  NotificationType,
  PaymentStatus,
  Prisma,
  TicketStatus,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { WalletService } from '../wallet/wallet.service';
import {
  buildOrderBy,
  buildPagination,
  paginate,
  PaginationQueryDto,
} from '../../common/utils/pagination.util';
import {
  BroadcastNotificationDto,
  CreateBannerDto,
  CreateBlogDto,
  CreateFaqDto,
  KycDecisionDto,
  ListUsersDto,
  ProcessPayoutDto,
  UpdateTicketDto,
} from './dto/admin.dto';

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly wallet: WalletService,
  ) {}

  // -------------------------------------------------------
  // USERS
  // -------------------------------------------------------

  async listUsers(query: ListUsersDto) {
    const { skip, take, page, limit } = buildPagination(query);

    const where: Prisma.UserWhereInput = {
      ...(query.role ? { role: query.role } : {}),
      ...(query.isActive !== undefined ? { isActive: query.isActive } : {}),
      ...(query.search
        ? {
            OR: [
              { fullName: { contains: query.search } },
              { email: { contains: query.search } },
              { phone: { contains: query.search } },
            ],
          }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.user.findMany({
        where,
        skip,
        take,
        orderBy: buildOrderBy(query, ['fullName', 'createdAt', 'role']),
        select: {
          id: true,
          fullName: true,
          email: true,
          phone: true,
          role: true,
          avatarUrl: true,
          isActive: true,
          isVerified: true,
          createdAt: true,
          therapist: { select: { id: true, kycStatus: true, ratingAvg: true } },
          patient: { select: { id: true } },
        },
      }),
      this.prisma.user.count({ where }),
    ]);

    return paginate(items, total, page, limit);
  }

  async getUserDetail(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        role: true,
        avatarUrl: true,
        isActive: true,
        isVerified: true,
        authProvider: true,
        createdAt: true,
        wallet: { select: { balance: true } },
        patient: {
          select: {
            id: true,
            gender: true,
            dateOfBirth: true,
            referralCode: true,
            addresses: true,
            _count: { select: { appointments: true } },
          },
        },
        therapist: {
          select: {
            id: true,
            specialization: true,
            experienceYears: true,
            kycStatus: true,
            ratingAvg: true,
            ratingCount: true,
            certificates: true,
            bankDetail: { select: { bankName: true, ifscCode: true, verified: true } },
            _count: { select: { appointments: true } },
          },
        },
      },
    });

    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  /** Blocks or unblocks an account; blocking also kills active sessions. */
  async setUserActive(userId: string, isActive: boolean) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    if (user.role === UserRole.SUPER_ADMIN) {
      throw new BadRequestException('A super admin account cannot be deactivated');
    }

    await this.prisma.$transaction([
      this.prisma.user.update({ where: { id: userId }, data: { isActive } }),
      ...(isActive
        ? []
        : [
            this.prisma.refreshToken.updateMany({
              where: { userId },
              data: { revoked: true },
            }),
          ]),
    ]);

    return { message: isActive ? 'User activated' : 'User deactivated' };
  }

  // -------------------------------------------------------
  // KYC
  // -------------------------------------------------------

  async listKycQueue(query: PaginationQueryDto & { status?: KycStatus }) {
    const { skip, take, page, limit } = buildPagination(query);

    const where: Prisma.TherapistWhereInput = {
      kycStatus: query.status ?? KycStatus.PENDING,
      ...(query.search
        ? { user: { fullName: { contains: query.search } } }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.therapist.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'asc' },
        select: {
          id: true,
          specialization: true,
          experienceYears: true,
          kycStatus: true,
          createdAt: true,
          user: { select: { id: true, fullName: true, phone: true, email: true, avatarUrl: true } },
          certificates: true,
          bankDetail: { select: { bankName: true, ifscCode: true, verified: true } },
        },
      }),
      this.prisma.therapist.count({ where }),
    ]);

    return paginate(items, total, page, limit);
  }

  /**
   * Approving a therapist makes them discoverable in patient search; the
   * certificates are marked verified in the same transaction.
   */
  async decideKyc(therapistId: string, dto: KycDecisionDto) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { id: therapistId },
      select: { id: true, userId: true, kycStatus: true },
    });
    if (!therapist) throw new NotFoundException('Therapist not found');

    if (therapist.kycStatus === KycStatus.APPROVED && dto.approve) {
      throw new BadRequestException('This therapist is already approved');
    }

    const status = dto.approve ? KycStatus.APPROVED : KycStatus.REJECTED;

    await this.prisma.$transaction([
      this.prisma.therapist.update({
        where: { id: therapistId },
        data: { kycStatus: status },
      }),
      this.prisma.certificate.updateMany({
        where: { therapistId },
        data: { verified: dto.approve },
      }),
      ...(dto.approve
        ? [
            this.prisma.bankDetail.updateMany({
              where: { therapistId },
              data: { verified: true },
            }),
          ]
        : []),
    ]);

    await this.notifications.send({
      userId: therapist.userId,
      type: NotificationType.SYSTEM,
      title: dto.approve ? 'Verification approved' : 'Verification rejected',
      body: dto.approve
        ? 'Your profile is verified. You can now receive bookings.'
        : `Your verification was rejected. ${dto.reason ?? 'Please re-upload valid documents.'}`,
      data: { therapistId },
    });

    return { message: `KYC ${status.toLowerCase()}` };
  }

  // -------------------------------------------------------
  // PAYOUTS
  // -------------------------------------------------------

  /**
   * Computes what each therapist is owed: consultation fees from completed,
   * paid appointments minus everything already paid out.
   */
  async getPendingPayouts() {
    const therapists = await this.prisma.therapist.findMany({
      where: { kycStatus: KycStatus.APPROVED },
      select: {
        id: true,
        user: { select: { fullName: true, avatarUrl: true } },
        bankDetail: { select: { bankName: true, ifscCode: true, verified: true } },
        appointments: {
          where: { status: 'COMPLETED', payment: { status: PaymentStatus.PAID } },
          select: { consultationFee: true },
        },
        payouts: {
          where: { status: { in: [PaymentStatus.PAID, PaymentStatus.PENDING] } },
          select: { amount: true },
        },
      },
    });

    return therapists
      .map((t) => {
        const earned = t.appointments.reduce((sum, a) => sum + Number(a.consultationFee), 0);
        const paidOut = t.payouts.reduce((sum, p) => sum + Number(p.amount), 0);
        return {
          therapistId: t.id,
          fullName: t.user.fullName,
          avatarUrl: t.user.avatarUrl,
          bankVerified: t.bankDetail?.verified ?? false,
          bankName: t.bankDetail?.bankName ?? null,
          totalEarned: Math.round(earned * 100) / 100,
          alreadyPaid: Math.round(paidOut * 100) / 100,
          pendingAmount: Math.round((earned - paidOut) * 100) / 100,
        };
      })
      .filter((t) => t.pendingAmount > 0);
  }

  async createPayout(dto: ProcessPayoutDto) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { id: dto.therapistId },
      select: { id: true, userId: true, bankDetail: { select: { verified: true } } },
    });
    if (!therapist) throw new NotFoundException('Therapist not found');
    if (!therapist.bankDetail?.verified) {
      throw new BadRequestException('Bank details must be verified before a payout');
    }

    const payout = await this.prisma.payout.create({
      data: {
        therapistId: dto.therapistId,
        amount: dto.amount,
        status: PaymentStatus.PAID,
        processedAt: new Date(),
      },
    });

    await this.notifications.send({
      userId: therapist.userId,
      type: NotificationType.PAYMENT,
      title: 'Payout processed',
      body: `₹${dto.amount} has been transferred to your registered bank account.`,
      data: { payoutId: payout.id },
    });

    return payout;
  }

  async listPayouts(query: PaginationQueryDto) {
    const { skip, take, page, limit } = buildPagination(query);

    const [items, total] = await this.prisma.$transaction([
      this.prisma.payout.findMany({
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        include: {
          therapist: { select: { id: true, user: { select: { fullName: true } } } },
        },
      }),
      this.prisma.payout.count(),
    ]);

    return paginate(items, total, page, limit);
  }

  // -------------------------------------------------------
  // BROADCAST NOTIFICATIONS
  // -------------------------------------------------------

  /** Sends a push + in-app notification to an entire audience segment. */
  async broadcast(dto: BroadcastNotificationDto) {
    const where: Prisma.UserWhereInput = {
      isActive: true,
      ...(dto.audience === 'ALL' ? {} : { role: dto.audience as UserRole }),
    };

    const users = await this.prisma.user.findMany({ where, select: { id: true } });

    return this.notifications.sendBulk(
      users.map((u) => u.id),
      { type: NotificationType.SYSTEM, title: dto.title, body: dto.body },
    );
  }

  // -------------------------------------------------------
  // CMS: BANNERS / BLOGS / FAQS
  // -------------------------------------------------------

  async listBanners(activeOnly = false) {
    return this.prisma.banner.findMany({
      where: activeOnly ? { isActive: true } : {},
      orderBy: { sortOrder: 'asc' },
    });
  }

  async createBanner(dto: CreateBannerDto) {
    return this.prisma.banner.create({ data: dto });
  }

  async updateBanner(id: string, dto: Partial<CreateBannerDto>) {
    return this.prisma.banner.update({ where: { id }, data: dto });
  }

  async deleteBanner(id: string) {
    await this.prisma.banner.delete({ where: { id } });
    return { message: 'Banner deleted' };
  }

  async listBlogs(query: PaginationQueryDto, publishedOnly = false) {
    const { skip, take, page, limit } = buildPagination(query);

    const where: Prisma.BlogWhereInput = {
      ...(publishedOnly ? { published: true } : {}),
      ...(query.search ? { title: { contains: query.search } } : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.blog.findMany({ where, skip, take, orderBy: { createdAt: 'desc' } }),
      this.prisma.blog.count({ where }),
    ]);

    return paginate(items, total, page, limit);
  }

  async getBlogBySlug(slug: string) {
    const blog = await this.prisma.blog.findUnique({ where: { slug } });
    if (!blog) throw new NotFoundException('Blog not found');
    return blog;
  }

  async createBlog(dto: CreateBlogDto) {
    return this.prisma.blog.create({
      data: { ...dto, slug: dto.slug ?? this.slugify(dto.title) },
    });
  }

  async updateBlog(id: string, dto: Partial<CreateBlogDto>) {
    return this.prisma.blog.update({ where: { id }, data: dto });
  }

  async deleteBlog(id: string) {
    await this.prisma.blog.delete({ where: { id } });
    return { message: 'Blog deleted' };
  }

  async listFaqs(category?: string) {
    return this.prisma.faq.findMany({
      where: category ? { category } : {},
      orderBy: { sortOrder: 'asc' },
    });
  }

  async createFaq(dto: CreateFaqDto) {
    return this.prisma.faq.create({ data: dto });
  }

  async updateFaq(id: string, dto: Partial<CreateFaqDto>) {
    return this.prisma.faq.update({ where: { id }, data: dto });
  }

  async deleteFaq(id: string) {
    await this.prisma.faq.delete({ where: { id } });
    return { message: 'FAQ deleted' };
  }

  // -------------------------------------------------------
  // SUPPORT TICKETS
  // -------------------------------------------------------

  async listTickets(query: PaginationQueryDto & { status?: TicketStatus }) {
    const { skip, take, page, limit } = buildPagination(query);

    const where: Prisma.SupportTicketWhereInput = {
      ...(query.status ? { status: query.status } : {}),
      ...(query.search
        ? { subject: { contains: query.search } }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.supportTicket.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        include: {
          user: { select: { id: true, fullName: true, phone: true, role: true, avatarUrl: true } },
        },
      }),
      this.prisma.supportTicket.count({ where }),
    ]);

    return paginate(items, total, page, limit);
  }

  async updateTicket(id: string, dto: UpdateTicketDto) {
    const ticket = await this.prisma.supportTicket.update({
      where: { id },
      data: { status: dto.status },
      include: { user: { select: { id: true } } },
    });

    if (dto.status === TicketStatus.RESOLVED) {
      await this.notifications.send({
        userId: ticket.user.id,
        type: NotificationType.SYSTEM,
        title: 'Support ticket resolved',
        body: `Your ticket "${ticket.subject}" has been resolved.`,
        data: { ticketId: ticket.id },
      });
    }

    return ticket;
  }

  // -------------------------------------------------------
  // AUDIT LOGS
  // -------------------------------------------------------

  async listAuditLogs(query: PaginationQueryDto) {
    const { skip, take, page, limit } = buildPagination(query);

    const where: Prisma.AuditLogWhereInput = query.search
      ? {
          OR: [
            { action: { contains: query.search } },
            { entityType: { contains: query.search } },
          ],
        }
      : {};

    const [items, total] = await this.prisma.$transaction([
      this.prisma.auditLog.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        include: { user: { select: { fullName: true, role: true } } },
      }),
      this.prisma.auditLog.count({ where }),
    ]);

    return paginate(items, total, page, limit);
  }

  private slugify(title: string): string {
    return title
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '')
      .slice(0, 80);
  }
}
