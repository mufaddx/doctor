import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { KycStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { UploadsService } from '../uploads/uploads.service';
import {
  buildOrderBy,
  buildPagination,
  paginate,
} from '../../common/utils/pagination.util';
import {
  SearchTherapistsDto,
  UpdateBankDetailDto,
  UpdateTherapistProfileDto,
} from './dto/therapist.dto';

const SORTABLE_FIELDS = ['ratingAvg', 'experienceYears', 'clinicFee', 'createdAt'];

@Injectable()
export class TherapistsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly uploads: UploadsService,
  ) {}

  /**
   * Public therapist discovery used by the patient app search screen.
   * Supports free-text search, specialization filter, fee range, rating floor,
   * minimum experience and radius-based filtering around the patient location.
   */
  async search(dto: SearchTherapistsDto) {
    const { skip, take, page, limit } = buildPagination(dto);

    // Each OR-producing filter is pushed as its own AND entry rather than
    // spread into one object literal — spreading more than one "OR" key into
    // the same object silently drops all but the last (object keys can't
    // repeat), which would have quietly broken combined filters.
    const andConditions: Prisma.TherapistWhereInput[] = [];

    if (dto.specialization?.length) {
      // specialization is stored as a JSON array (MySQL has no native array
      // type), so "any of these values" needs an OR of array_contains checks
      // instead of Postgres's hasSome.
      andConditions.push({
        OR: dto.specialization.map((s) => ({ specialization: { array_contains: s } })),
      });
    }
    if (dto.maxFee !== undefined) {
      andConditions.push({
        OR: [
          { clinicFee: { lte: dto.maxFee } },
          { videoFee: { lte: dto.maxFee } },
          { homeVisitFee: { lte: dto.maxFee } },
        ],
      });
    }
    if (dto.search) {
      andConditions.push({
        OR: [
          { user: { fullName: { contains: dto.search } } },
          { specialization: { array_contains: dto.search } },
          { bio: { contains: dto.search } },
        ],
      });
    }

    const where: Prisma.TherapistWhereInput = {
      // Only verified, active therapists are ever discoverable
      kycStatus: KycStatus.APPROVED,
      user: { isActive: true },
      ...(dto.isAvailable !== undefined ? { isAvailable: dto.isAvailable } : {}),
      ...(dto.minRating !== undefined ? { ratingAvg: { gte: dto.minRating } } : {}),
      ...(dto.minExperience !== undefined
        ? { experienceYears: { gte: dto.minExperience } }
        : {}),
      ...(andConditions.length ? { AND: andConditions } : {}),
    };

    const [rows, total] = await this.prisma.$transaction([
      this.prisma.therapist.findMany({
        where,
        skip,
        take,
        orderBy: buildOrderBy(dto, SORTABLE_FIELDS, 'ratingAvg'),
        select: this.listSelect(),
      }),
      this.prisma.therapist.count({ where }),
    ]);

    // Attach straight-line distance when the client sent its coordinates
    const items = rows.map((t) => ({
      ...t,
      distanceKm:
        dto.latitude !== undefined && dto.longitude !== undefined && t.latitude && t.longitude
          ? Number(
              this.haversineKm(dto.latitude, dto.longitude, t.latitude, t.longitude).toFixed(1),
            )
          : null,
    }));

    // Radius filtering happens post-query because Postgres earth-distance is
    // not enabled by default; the page size cap keeps this cheap.
    const filtered =
      dto.radiusKm !== undefined
        ? items.filter((t) => t.distanceKm !== null && t.distanceKm <= dto.radiusKm!)
        : items;

    return paginate(filtered, total, page, limit);
  }

  /** Top-rated therapists for the patient home screen carousel. */
  async findTopRated(limit = 10) {
    return this.prisma.therapist.findMany({
      where: { kycStatus: KycStatus.APPROVED, isAvailable: true, user: { isActive: true } },
      orderBy: [{ ratingAvg: 'desc' }, { ratingCount: 'desc' }],
      take: limit,
      select: this.listSelect(),
    });
  }

  /** Full public profile shown on the therapist detail screen. */
  async findOne(therapistId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { id: therapistId },
      select: {
        ...this.listSelect(),
        bio: true,
        clinicAddress: true,
        homeVisitFee: true,
        videoFee: true,
        latitude: true,
        longitude: true,
        availabilitySlots: {
          where: { isActive: true },
          orderBy: [{ dayOfWeek: 'asc' }, { startTime: 'asc' }],
          select: { id: true, dayOfWeek: true, startTime: true, endTime: true },
        },
        certificates: {
          where: { verified: true },
          select: { id: true, title: true, fileUrl: true },
        },
        reviews: {
          take: 10,
          orderBy: { createdAt: 'desc' },
          select: {
            id: true,
            rating: true,
            comment: true,
            createdAt: true,
            author: { select: { fullName: true, avatarUrl: true } },
          },
        },
        _count: { select: { appointments: { where: { status: 'COMPLETED' } } } },
      },
    });

    if (!therapist) throw new NotFoundException('Therapist not found');

    return {
      ...therapist,
      completedAppointments: therapist._count.appointments,
      _count: undefined,
    };
  }

  // -------------------------------------------------------
  // THERAPIST SELF-SERVICE
  // -------------------------------------------------------

  async updateOwnProfile(userId: string, dto: UpdateTherapistProfileDto) {
    const therapist = await this.requireTherapist(userId);

    return this.prisma.therapist.update({
      where: { id: therapist.id },
      data: {
        specialization: dto.specialization,
        experienceYears: dto.experienceYears,
        bio: dto.bio,
        clinicFee: dto.clinicFee,
        homeVisitFee: dto.homeVisitFee,
        videoFee: dto.videoFee,
        clinicAddress: dto.clinicAddress,
        latitude: dto.latitude,
        longitude: dto.longitude,
      },
    });
  }

  async toggleAvailability(userId: string, isAvailable: boolean) {
    const therapist = await this.requireTherapist(userId);
    return this.prisma.therapist.update({
      where: { id: therapist.id },
      data: { isAvailable },
      select: { id: true, isAvailable: true },
    });
  }

  async uploadCertificate(userId: string, title: string, file: Express.Multer.File) {
    const therapist = await this.requireTherapist(userId);
    const fileUrl = await this.uploads.uploadDocument(file, `certificates/${therapist.id}`);

    const certificate = await this.prisma.certificate.create({
      data: { therapistId: therapist.id, title, fileUrl },
    });

    // Uploading fresh documents puts the therapist back into the review queue
    await this.prisma.therapist.update({
      where: { id: therapist.id },
      data: { kycStatus: KycStatus.PENDING },
    });

    return certificate;
  }

  async deleteCertificate(userId: string, certificateId: string) {
    const therapist = await this.requireTherapist(userId);
    const certificate = await this.prisma.certificate.findFirst({
      where: { id: certificateId, therapistId: therapist.id },
    });
    if (!certificate) throw new NotFoundException('Certificate not found');

    await this.uploads.deleteByUrl(certificate.fileUrl);
    await this.prisma.certificate.delete({ where: { id: certificateId } });
    return { message: 'Certificate removed' };
  }

  async upsertBankDetail(userId: string, dto: UpdateBankDetailDto) {
    const therapist = await this.requireTherapist(userId);

    const record = await this.prisma.bankDetail.upsert({
      where: { therapistId: therapist.id },
      create: { therapistId: therapist.id, ...dto, verified: false },
      // Any change resets verification so finance re-checks before payouts
      update: { ...dto, verified: false },
    });

    return { ...record, accountNumber: this.maskAccount(record.accountNumber) };
  }

  async getBankDetail(userId: string) {
    const therapist = await this.requireTherapist(userId);
    const record = await this.prisma.bankDetail.findUnique({
      where: { therapistId: therapist.id },
    });
    if (!record) return null;
    return { ...record, accountNumber: this.maskAccount(record.accountNumber) };
  }

  async getOwnReviews(userId: string, page = 1, limit = 20) {
    const therapist = await this.requireTherapist(userId);

    const [items, total] = await this.prisma.$transaction([
      this.prisma.review.findMany({
        where: { therapistId: therapist.id },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          rating: true,
          comment: true,
          createdAt: true,
          author: { select: { fullName: true, avatarUrl: true } },
        },
      }),
      this.prisma.review.count({ where: { therapistId: therapist.id } }),
    ]);

    return paginate(items, total, page, limit);
  }

  /** Recomputes the cached rating aggregate after a review is added or removed. */
  async recalculateRating(therapistId: string) {
    const stats = await this.prisma.review.aggregate({
      where: { therapistId },
      _avg: { rating: true },
      _count: { rating: true },
    });

    await this.prisma.therapist.update({
      where: { id: therapistId },
      data: {
        ratingAvg: Number((stats._avg.rating ?? 0).toFixed(2)),
        ratingCount: stats._count.rating,
      },
    });
  }

  // -------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------

  private async requireTherapist(userId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!therapist) throw new NotFoundException('Therapist profile not found');
    return therapist;
  }

  private listSelect() {
    return {
      id: true,
      specialization: true,
      experienceYears: true,
      clinicFee: true,
      homeVisitFee: true,
      videoFee: true,
      ratingAvg: true,
      ratingCount: true,
      isAvailable: true,
      latitude: true,
      longitude: true,
      user: { select: { id: true, fullName: true, avatarUrl: true } },
    } satisfies Prisma.TherapistSelect;
  }

  /** Great-circle distance in kilometres between two coordinates. */
  private haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const toRad = (deg: number) => (deg * Math.PI) / 180;
    const earthRadiusKm = 6371;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
    return earthRadiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  /** Bank account numbers are never returned in full to the client. */
  private maskAccount(accountNumber: string): string {
    return accountNumber.length <= 4
      ? '****'
      : `${'*'.repeat(accountNumber.length - 4)}${accountNumber.slice(-4)}`;
  }
}
