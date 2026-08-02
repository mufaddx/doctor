import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AppointmentStatus, NotificationType } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { TherapistsService } from '../therapists/therapists.service';
import { buildPagination, paginate, PaginationQueryDto } from '../../common/utils/pagination.util';
import { CreateReviewDto, UpdateReviewDto } from './dto/review.dto';

@Injectable()
export class ReviewsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly therapists: TherapistsService,
    private readonly notifications: NotificationsService,
  ) {}

  /**
   * Only a patient who actually completed the appointment may review it, and
   * only once. The therapist's cached rating is recomputed afterwards.
   */
  async create(patientUserId: string, dto: CreateReviewDto) {
    const patient = await this.prisma.patient.findUnique({
      where: { userId: patientUserId },
      select: { id: true, user: { select: { fullName: true } } },
    });
    if (!patient) throw new NotFoundException('Patient profile not found');

    const appointment = await this.prisma.appointment.findFirst({
      where: { id: dto.appointmentId, patientId: patient.id },
      include: {
        review: { select: { id: true } },
        therapist: { select: { id: true, userId: true } },
      },
    });

    if (!appointment) throw new NotFoundException('Appointment not found');
    if (appointment.status !== AppointmentStatus.COMPLETED) {
      throw new BadRequestException('You can only review a completed appointment');
    }
    if (appointment.review) {
      throw new BadRequestException('You have already reviewed this appointment');
    }

    const review = await this.prisma.review.create({
      data: {
        appointmentId: appointment.id,
        patientId: patient.id,
        therapistId: appointment.therapist.id,
        authorId: patientUserId,
        rating: dto.rating,
        comment: dto.comment,
      },
    });

    await this.therapists.recalculateRating(appointment.therapist.id);

    await this.notifications.send({
      userId: appointment.therapist.userId,
      type: NotificationType.SYSTEM,
      title: 'New review received',
      body: `${patient.user.fullName} rated you ${dto.rating} out of 5.`,
      data: { reviewId: review.id },
    });

    return review;
  }

  async update(patientUserId: string, reviewId: string, dto: UpdateReviewDto) {
    const review = await this.prisma.review.findFirst({
      where: { id: reviewId, authorId: patientUserId },
    });
    if (!review) throw new NotFoundException('Review not found');

    const updated = await this.prisma.review.update({
      where: { id: reviewId },
      data: { rating: dto.rating, comment: dto.comment },
    });

    if (dto.rating !== undefined) {
      await this.therapists.recalculateRating(review.therapistId);
    }

    return updated;
  }

  async remove(patientUserId: string, reviewId: string) {
    const review = await this.prisma.review.findFirst({
      where: { id: reviewId, authorId: patientUserId },
    });
    if (!review) throw new NotFoundException('Review not found');

    await this.prisma.review.delete({ where: { id: reviewId } });
    await this.therapists.recalculateRating(review.therapistId);

    return { message: 'Review deleted' };
  }

  /** Public reviews for a therapist profile page, with a rating histogram. */
  async findByTherapist(therapistId: string, query: PaginationQueryDto) {
    const { skip, take, page, limit } = buildPagination(query);

    const [items, total, distribution] = await this.prisma.$transaction([
      this.prisma.review.findMany({
        where: { therapistId },
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          rating: true,
          comment: true,
          createdAt: true,
          author: { select: { fullName: true, avatarUrl: true } },
        },
      }),
      this.prisma.review.count({ where: { therapistId } }),
      this.prisma.review.groupBy({
        by: ['rating'],
        where: { therapistId },
        orderBy: { rating: 'asc' },
        _count: true,
      }),
    ]);

    // Fill in zero counts so the UI can render all five bars
    const histogram = [5, 4, 3, 2, 1].map((star) => ({
      rating: star,
      count: distribution.find((d) => d.rating === star)?._count ?? 0,
    }));

    return { ...paginate(items, total, page, limit), histogram };
  }

  /** Appointments the patient has completed but not yet reviewed. */
  async getPendingReviews(patientUserId: string) {
    const patient = await this.prisma.patient.findUnique({
      where: { userId: patientUserId },
      select: { id: true },
    });
    if (!patient) throw new NotFoundException('Patient profile not found');

    return this.prisma.appointment.findMany({
      where: {
        patientId: patient.id,
        status: AppointmentStatus.COMPLETED,
        review: null,
      },
      orderBy: { scheduledDate: 'desc' },
      take: 20,
      select: {
        id: true,
        scheduledDate: true,
        type: true,
        therapist: {
          select: { id: true, user: { select: { fullName: true, avatarUrl: true } } },
        },
      },
    });
  }

  /** Admin moderation list across all therapists. */
  async findAllForAdmin(query: PaginationQueryDto) {
    const { skip, take, page, limit } = buildPagination(query);

    const where = query.search
      ? { comment: { contains: query.search, mode: 'insensitive' as const } }
      : {};

    const [items, total] = await this.prisma.$transaction([
      this.prisma.review.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        include: {
          author: { select: { fullName: true, avatarUrl: true } },
          therapist: { select: { id: true, user: { select: { fullName: true } } } },
        },
      }),
      this.prisma.review.count({ where }),
    ]);

    return paginate(items, total, page, limit);
  }

  /** Admins can remove abusive reviews; the rating is recalculated. */
  async removeByAdmin(reviewId: string) {
    const review = await this.prisma.review.findUnique({ where: { id: reviewId } });
    if (!review) throw new NotFoundException('Review not found');

    await this.prisma.review.delete({ where: { id: reviewId } });
    await this.therapists.recalculateRating(review.therapistId);

    return { message: 'Review removed' };
  }
}
