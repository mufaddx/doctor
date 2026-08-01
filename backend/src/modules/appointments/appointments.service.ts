import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  AppointmentStatus,
  AppointmentType,
  NotificationType,
  Prisma,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { AvailabilityService } from '../availability/availability.service';
import { CouponsService } from '../coupons/coupons.service';
import { NotificationsService } from '../notifications/notifications.service';
import { buildPagination, paginate } from '../../common/utils/pagination.util';
import {
  CancelAppointmentDto,
  CreateAppointmentDto,
  ListAppointmentsDto,
  RejectAppointmentDto,
  RescheduleAppointmentDto,
} from './dto/appointment.dto';

/** Free-cancellation window before the appointment start. */
const FREE_CANCEL_HOURS = 12;

@Injectable()
export class AppointmentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly availability: AvailabilityService,
    private readonly coupons: CouponsService,
    private readonly notifications: NotificationsService,
    private readonly config: ConfigService,
  ) {}

  // -------------------------------------------------------
  // BOOKING
  // -------------------------------------------------------

  /**
   * Creates a PENDING appointment. The slot is validated against both the
   * therapist's working hours and existing bookings inside a serializable
   * transaction so two patients cannot claim the same slot concurrently.
   */
  async create(userId: string, dto: CreateAppointmentDto) {
    const patient = await this.prisma.patient.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!patient) throw new NotFoundException('Patient profile not found');

    const therapist = await this.prisma.therapist.findUnique({
      where: { id: dto.therapistId },
      select: {
        id: true,
        userId: true,
        isAvailable: true,
        kycStatus: true,
        clinicFee: true,
        homeVisitFee: true,
        videoFee: true,
        user: { select: { fullName: true } },
      },
    });
    if (!therapist) throw new NotFoundException('Therapist not found');
    if (therapist.kycStatus !== 'APPROVED' || !therapist.isAvailable) {
      throw new BadRequestException('This therapist is not accepting bookings right now');
    }

    // Home visits require a saved address belonging to this patient
    if (dto.type === AppointmentType.HOME_VISIT) {
      if (!dto.addressId) {
        throw new BadRequestException('An address is required for a home visit');
      }
      const address = await this.prisma.address.findFirst({
        where: { id: dto.addressId, patientId: patient.id },
        select: { id: true },
      });
      if (!address) throw new BadRequestException('Selected address does not belong to you');
    }

    const scheduledDate = new Date(`${dto.scheduledDate}T00:00:00`);
    const endTime = this.addMinutes(dto.startTime, dto.durationMinutes ?? 30);

    const consultationFee = this.feeFor(therapist, dto.type);
    const platformFee = Number(this.config.get<string>('PLATFORM_FEE', '20'));

    // Coupon is validated (but not consumed) before the appointment is written
    const discount = dto.couponCode
      ? await this.coupons.validateForAmount(dto.couponCode, patient.id, consultationFee)
      : { discountAmount: 0, couponId: null as string | null };

    const totalAmount = Math.max(
      0,
      Number(consultationFee) + platformFee - discount.discountAmount,
    );

    const appointment = await this.prisma.$transaction(
      async (tx) => {
        const bookable = await this.availability.isSlotBookable(
          therapist.id,
          scheduledDate,
          dto.startTime,
          endTime,
        );
        if (!bookable) {
          throw new BadRequestException('This slot is no longer available');
        }

        const created = await tx.appointment.create({
          data: {
            patientId: patient.id,
            therapistId: therapist.id,
            type: dto.type,
            status: AppointmentStatus.PENDING,
            scheduledDate,
            startTime: dto.startTime,
            endTime,
            durationMinutes: dto.durationMinutes ?? 30,
            addressId: dto.addressId,
            problem: dto.problem,
            notes: dto.notes,
            consultationFee,
            platformFee,
            discountAmount: discount.discountAmount,
            totalAmount,
          },
          include: this.detailInclude(),
        });

        if (discount.couponId) {
          await this.coupons.markRedeemed(tx, discount.couponId, patient.id);
        }

        return created;
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
    );

    await this.notifications.send({
      userId: therapist.userId,
      type: NotificationType.APPOINTMENT,
      title: 'New booking request',
      body: `You have a new ${this.readableType(dto.type)} request on ${dto.scheduledDate} at ${dto.startTime}`,
      data: { appointmentId: appointment.id },
    });

    return appointment;
  }

  // -------------------------------------------------------
  // LISTING
  // -------------------------------------------------------

  /** Returns appointments scoped to whichever role is calling. */
  async findAll(userId: string, role: UserRole, query: ListAppointmentsDto) {
    const { skip, take, page, limit } = buildPagination(query);
    const scope = await this.scopeFor(userId, role);

    const where: Prisma.AppointmentWhereInput = {
      ...scope,
      ...(query.status ? { status: query.status } : {}),
      ...(query.type ? { type: query.type } : {}),
      ...(query.fromDate || query.toDate
        ? {
            scheduledDate: {
              ...(query.fromDate ? { gte: new Date(query.fromDate) } : {}),
              ...(query.toDate ? { lte: new Date(`${query.toDate}T23:59:59`) } : {}),
            },
          }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.appointment.findMany({
        where,
        skip,
        take,
        orderBy: [{ scheduledDate: query.sortOrder ?? 'desc' }, { startTime: 'asc' }],
        include: this.listInclude(),
      }),
      this.prisma.appointment.count({ where }),
    ]);

    return paginate(items, total, page, limit);
  }

  /** Therapist dashboard: everything scheduled for today. */
  async findTodaySchedule(userId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!therapist) throw new NotFoundException('Therapist profile not found');

    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const end = new Date();
    end.setHours(23, 59, 59, 999);

    return this.prisma.appointment.findMany({
      where: {
        therapistId: therapist.id,
        scheduledDate: { gte: start, lte: end },
        status: {
          in: [
            AppointmentStatus.CONFIRMED,
            AppointmentStatus.IN_PROGRESS,
            AppointmentStatus.PENDING,
          ],
        },
      },
      orderBy: { startTime: 'asc' },
      include: this.listInclude(),
    });
  }

  async findOne(userId: string, role: UserRole, appointmentId: string) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id: appointmentId },
      include: this.detailInclude(),
    });
    if (!appointment) throw new NotFoundException('Appointment not found');

    await this.assertParticipant(appointment, userId, role);
    return appointment;
  }

  // -------------------------------------------------------
  // LIFECYCLE TRANSITIONS
  // -------------------------------------------------------

  /** Therapist accepts a pending request. */
  async accept(userId: string, appointmentId: string) {
    const appointment = await this.requireTherapistOwned(userId, appointmentId);

    if (appointment.status !== AppointmentStatus.PENDING) {
      throw new BadRequestException(
        `Only pending requests can be accepted (current status: ${appointment.status})`,
      );
    }

    const updated = await this.prisma.appointment.update({
      where: { id: appointmentId },
      data: { status: AppointmentStatus.CONFIRMED },
      include: this.detailInclude(),
    });

    await this.notifications.send({
      userId: updated.patient.user.id,
      type: NotificationType.APPOINTMENT,
      title: 'Appointment confirmed',
      body: `Your appointment with ${updated.therapist.user.fullName} is confirmed for ${this.formatDate(updated.scheduledDate)} at ${updated.startTime}`,
      data: { appointmentId: updated.id },
    });

    return updated;
  }

  /** Therapist rejects a pending request; any captured payment is refunded. */
  async reject(userId: string, appointmentId: string, dto: RejectAppointmentDto) {
    const appointment = await this.requireTherapistOwned(userId, appointmentId);

    if (appointment.status !== AppointmentStatus.PENDING) {
      throw new BadRequestException('Only pending requests can be rejected');
    }

    const updated = await this.prisma.appointment.update({
      where: { id: appointmentId },
      data: {
        status: AppointmentStatus.REJECTED,
        cancelReason: dto.reason,
        cancelledBy: UserRole.THERAPIST,
      },
      include: this.detailInclude(),
    });

    await this.notifications.send({
      userId: updated.patient.user.id,
      type: NotificationType.APPOINTMENT,
      title: 'Appointment declined',
      body: `${updated.therapist.user.fullName} could not take your ${this.formatDate(updated.scheduledDate)} appointment. Any payment will be refunded.`,
      data: { appointmentId: updated.id, reason: dto.reason },
    });

    return updated;
  }

  /**
   * Either party can cancel. Cancelling inside the free window makes the
   * booking eligible for a full refund, which the payments module reads.
   */
  async cancel(
    userId: string,
    role: UserRole,
    appointmentId: string,
    dto: CancelAppointmentDto,
  ) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id: appointmentId },
      include: this.detailInclude(),
    });
    if (!appointment) throw new NotFoundException('Appointment not found');
    await this.assertParticipant(appointment, userId, role);

    const cancellable: AppointmentStatus[] = [
      AppointmentStatus.PENDING,
      AppointmentStatus.CONFIRMED,
    ];
    if (!cancellable.includes(appointment.status)) {
      throw new BadRequestException(`Cannot cancel an appointment that is ${appointment.status}`);
    }

    const hoursUntilStart = this.hoursUntil(appointment.scheduledDate, appointment.startTime);
    const refundEligible = hoursUntilStart >= FREE_CANCEL_HOURS;

    const updated = await this.prisma.appointment.update({
      where: { id: appointmentId },
      data: {
        status: AppointmentStatus.CANCELLED,
        cancelReason: dto.reason,
        cancelledBy: role,
      },
      include: this.detailInclude(),
    });

    // Notify the other participant
    const recipientId =
      role === UserRole.PATIENT ? updated.therapist.user.id : updated.patient.user.id;

    await this.notifications.send({
      userId: recipientId,
      type: NotificationType.APPOINTMENT,
      title: 'Appointment cancelled',
      body: `The appointment on ${this.formatDate(updated.scheduledDate)} at ${updated.startTime} was cancelled.`,
      data: { appointmentId: updated.id },
    });

    return { ...updated, refundEligible };
  }

  /** Patient moves a confirmed booking to a different free slot. */
  async reschedule(userId: string, appointmentId: string, dto: RescheduleAppointmentDto) {
    const patient = await this.prisma.patient.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!patient) throw new NotFoundException('Patient profile not found');

    const appointment = await this.prisma.appointment.findFirst({
      where: { id: appointmentId, patientId: patient.id },
      include: this.detailInclude(),
    });
    if (!appointment) throw new NotFoundException('Appointment not found');

    if (
      appointment.status !== AppointmentStatus.CONFIRMED &&
      appointment.status !== AppointmentStatus.PENDING
    ) {
      throw new BadRequestException('Only upcoming appointments can be rescheduled');
    }

    const newDate = new Date(`${dto.scheduledDate}T00:00:00`);
    const newEnd = this.addMinutes(dto.startTime, appointment.durationMinutes);

    const bookable = await this.availability.isSlotBookable(
      appointment.therapistId,
      newDate,
      dto.startTime,
      newEnd,
    );
    if (!bookable) throw new BadRequestException('The selected slot is not available');

    const updated = await this.prisma.appointment.update({
      where: { id: appointmentId },
      data: {
        scheduledDate: newDate,
        startTime: dto.startTime,
        endTime: newEnd,
        // Moving the slot requires the therapist to confirm again
        status: AppointmentStatus.PENDING,
      },
      include: this.detailInclude(),
    });

    await this.notifications.send({
      userId: updated.therapist.user.id,
      type: NotificationType.APPOINTMENT,
      title: 'Appointment rescheduled',
      body: `${updated.patient.user.fullName} moved an appointment to ${dto.scheduledDate} at ${dto.startTime}. Please confirm.`,
      data: { appointmentId: updated.id },
    });

    return updated;
  }

  /** Therapist marks the session as started (unlocks the video room). */
  async start(userId: string, appointmentId: string) {
    const appointment = await this.requireTherapistOwned(userId, appointmentId);

    if (appointment.status !== AppointmentStatus.CONFIRMED) {
      throw new BadRequestException('Only confirmed appointments can be started');
    }

    return this.prisma.appointment.update({
      where: { id: appointmentId },
      data: { status: AppointmentStatus.IN_PROGRESS },
      include: this.detailInclude(),
    });
  }

  async complete(userId: string, appointmentId: string) {
    const appointment = await this.requireTherapistOwned(userId, appointmentId);

    if (
      appointment.status !== AppointmentStatus.IN_PROGRESS &&
      appointment.status !== AppointmentStatus.CONFIRMED
    ) {
      throw new BadRequestException('This appointment cannot be marked complete');
    }

    const updated = await this.prisma.appointment.update({
      where: { id: appointmentId },
      data: { status: AppointmentStatus.COMPLETED },
      include: this.detailInclude(),
    });

    await this.notifications.send({
      userId: updated.patient.user.id,
      type: NotificationType.APPOINTMENT,
      title: 'Session completed',
      body: 'Your session is complete. Please rate your experience.',
      data: { appointmentId: updated.id },
    });

    return updated;
  }

  /** Counters for the therapist dashboard cards. */
  async getTherapistStats(userId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!therapist) throw new NotFoundException('Therapist profile not found');

    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const end = new Date();
    end.setHours(23, 59, 59, 999);

    const todayWhere = {
      therapistId: therapist.id,
      scheduledDate: { gte: start, lte: end },
    };

    const [todayTotal, pending, videoToday, homeToday] = await this.prisma.$transaction([
      this.prisma.appointment.count({ where: todayWhere }),
      this.prisma.appointment.count({
        where: { therapistId: therapist.id, status: AppointmentStatus.PENDING },
      }),
      this.prisma.appointment.count({
        where: { ...todayWhere, type: AppointmentType.VIDEO_CONSULTATION },
      }),
      this.prisma.appointment.count({
        where: { ...todayWhere, type: AppointmentType.HOME_VISIT },
      }),
    ]);

    return {
      todayAppointments: todayTotal,
      pendingRequests: pending,
      videoConsultations: videoToday,
      homeVisits: homeToday,
    };
  }

  // -------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------

  private feeFor(
    therapist: { clinicFee: Prisma.Decimal; homeVisitFee: Prisma.Decimal; videoFee: Prisma.Decimal },
    type: AppointmentType,
  ): Prisma.Decimal {
    switch (type) {
      case AppointmentType.CLINIC_VISIT:
        return therapist.clinicFee;
      case AppointmentType.HOME_VISIT:
        return therapist.homeVisitFee;
      case AppointmentType.VIDEO_CONSULTATION:
        return therapist.videoFee;
    }
  }

  private async scopeFor(userId: string, role: UserRole): Promise<Prisma.AppointmentWhereInput> {
    if (role === UserRole.PATIENT) {
      const patient = await this.prisma.patient.findUnique({
        where: { userId },
        select: { id: true },
      });
      if (!patient) throw new NotFoundException('Patient profile not found');
      return { patientId: patient.id };
    }

    if (role === UserRole.THERAPIST) {
      const therapist = await this.prisma.therapist.findUnique({
        where: { userId },
        select: { id: true },
      });
      if (!therapist) throw new NotFoundException('Therapist profile not found');
      return { therapistId: therapist.id };
    }

    // Admins see everything
    return {};
  }

  private async assertParticipant(
    appointment: { patient: { userId: string }; therapist: { userId: string } },
    userId: string,
    role: UserRole,
  ) {
    if (role === UserRole.ADMIN || role === UserRole.SUPER_ADMIN) return;
    if (appointment.patient.userId === userId || appointment.therapist.userId === userId) return;
    throw new ForbiddenException('You are not a participant in this appointment');
  }

  private async requireTherapistOwned(userId: string, appointmentId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!therapist) throw new NotFoundException('Therapist profile not found');

    const appointment = await this.prisma.appointment.findFirst({
      where: { id: appointmentId, therapistId: therapist.id },
      include: this.detailInclude(),
    });
    if (!appointment) throw new NotFoundException('Appointment not found');
    return appointment;
  }

  private listInclude() {
    return {
      patient: {
        select: {
          id: true,
          userId: true,
          user: { select: { id: true, fullName: true, avatarUrl: true, phone: true } },
        },
      },
      therapist: {
        select: {
          id: true,
          userId: true,
          specialization: true,
          user: { select: { id: true, fullName: true, avatarUrl: true } },
        },
      },
      payment: { select: { id: true, status: true, method: true, amount: true } },
    } satisfies Prisma.AppointmentInclude;
  }

  private detailInclude() {
    return {
      ...this.listInclude(),
      prescription: true,
      videoSession: { select: { id: true, channelName: true, startedAt: true, endedAt: true } },
      review: { select: { id: true, rating: true, comment: true } },
    } satisfies Prisma.AppointmentInclude;
  }

  /** Adds minutes to an HH:mm string, returning HH:mm. */
  private addMinutes(time: string, minutes: number): string {
    const [h, m] = time.split(':').map(Number);
    const total = h * 60 + m + minutes;
    return `${String(Math.floor(total / 60) % 24).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
  }

  private hoursUntil(date: Date, startTime: string): number {
    const [h, m] = startTime.split(':').map(Number);
    const target = new Date(date);
    target.setHours(h, m, 0, 0);
    return (target.getTime() - Date.now()) / 3_600_000;
  }

  private formatDate(date: Date): string {
    return date.toLocaleDateString('en-IN', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    });
  }

  private readableType(type: AppointmentType): string {
    return type.toLowerCase().replace(/_/g, ' ');
  }
}
