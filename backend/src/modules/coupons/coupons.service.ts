import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { CouponType, Prisma } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { buildPagination, paginate, PaginationQueryDto } from '../../common/utils/pagination.util';
import { CreateCouponDto, UpdateCouponDto } from './dto/coupon.dto';

@Injectable()
export class CouponsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Coupons a patient can currently apply, excluding ones already used. */
  async listAvailable(userId: string) {
    const patient = await this.prisma.patient.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!patient) throw new NotFoundException('Patient profile not found');

    const now = new Date();

    return this.prisma.coupon.findMany({
      where: {
        isActive: true,
        validFrom: { lte: now },
        validUntil: { gte: now },
        redemptions: { none: { patientId: patient.id } },
      },
      orderBy: { validUntil: 'asc' },
      select: {
        id: true,
        code: true,
        type: true,
        value: true,
        maxDiscount: true,
        minOrderValue: true,
        validUntil: true,
      },
    });
  }

  /**
   * Validates a coupon against a specific order amount and returns the
   * computed discount. Throws with a precise reason so the app can show it.
   */
  async validateForAmount(
    code: string,
    patientId: string,
    orderAmount: Prisma.Decimal | number,
  ): Promise<{ discountAmount: number; couponId: string }> {
    const coupon = await this.prisma.coupon.findUnique({
      where: { code: code.toUpperCase() },
      include: { redemptions: { where: { patientId }, select: { id: true } } },
    });

    if (!coupon) throw new BadRequestException('Invalid coupon code');
    if (!coupon.isActive) throw new BadRequestException('This coupon is no longer active');

    const now = new Date();
    if (coupon.validFrom > now) throw new BadRequestException('This coupon is not yet valid');
    if (coupon.validUntil < now) throw new BadRequestException('This coupon has expired');

    if (coupon.usageLimit !== null && coupon.usedCount >= coupon.usageLimit) {
      throw new BadRequestException('This coupon has reached its usage limit');
    }
    if (coupon.redemptions.length > 0) {
      throw new BadRequestException('You have already used this coupon');
    }

    const amount = Number(orderAmount);
    const minOrder = coupon.minOrderValue ? Number(coupon.minOrderValue) : 0;
    if (amount < minOrder) {
      throw new BadRequestException(`This coupon requires a minimum order of ₹${minOrder}`);
    }

    let discount =
      coupon.type === CouponType.PERCENTAGE
        ? (amount * Number(coupon.value)) / 100
        : Number(coupon.value);

    // Percentage coupons are capped when maxDiscount is configured
    if (coupon.maxDiscount) discount = Math.min(discount, Number(coupon.maxDiscount));

    // A coupon can never make the order negative
    discount = Math.min(discount, amount);

    return { discountAmount: Math.round(discount * 100) / 100, couponId: coupon.id };
  }

  /** Public preview endpoint used before the booking is created. */
  async previewForUser(userId: string, code: string, amount: number) {
    const patient = await this.prisma.patient.findUnique({
      where: { userId },
      select: { id: true },
    });
    if (!patient) throw new NotFoundException('Patient profile not found');

    const result = await this.validateForAmount(code, patient.id, amount);
    return {
      code: code.toUpperCase(),
      discountAmount: result.discountAmount,
      payableAmount: Math.max(0, amount - result.discountAmount),
    };
  }

  /**
   * Records the redemption inside the caller's transaction so the counter and
   * the appointment are committed together.
   */
  async markRedeemed(tx: Prisma.TransactionClient, couponId: string, patientId: string) {
    await tx.couponRedemption.create({ data: { couponId, patientId } });
    await tx.coupon.update({
      where: { id: couponId },
      data: { usedCount: { increment: 1 } },
    });
  }

  // ---------------- Admin management ----------------

  async create(dto: CreateCouponDto) {
    const validFrom = new Date(dto.validFrom);
    const validUntil = new Date(dto.validUntil);
    if (validUntil <= validFrom) {
      throw new BadRequestException('validUntil must be after validFrom');
    }
    if (dto.type === CouponType.PERCENTAGE && dto.value > 100) {
      throw new BadRequestException('Percentage discount cannot exceed 100');
    }

    return this.prisma.coupon.create({
      data: {
        code: dto.code.toUpperCase(),
        type: dto.type,
        value: dto.value,
        maxDiscount: dto.maxDiscount,
        minOrderValue: dto.minOrderValue,
        usageLimit: dto.usageLimit,
        validFrom,
        validUntil,
        isActive: dto.isActive ?? true,
      },
    });
  }

  async findAll(query: PaginationQueryDto) {
    const { skip, take, page, limit } = buildPagination(query);

    const where: Prisma.CouponWhereInput = query.search
      ? { code: { contains: query.search } }
      : {};

    const [items, total] = await this.prisma.$transaction([
      this.prisma.coupon.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        include: { _count: { select: { redemptions: true } } },
      }),
      this.prisma.coupon.count({ where }),
    ]);

    return paginate(items, total, page, limit);
  }

  async update(id: string, dto: UpdateCouponDto) {
    return this.prisma.coupon.update({
      where: { id },
      data: {
        value: dto.value,
        maxDiscount: dto.maxDiscount,
        minOrderValue: dto.minOrderValue,
        usageLimit: dto.usageLimit,
        validFrom: dto.validFrom ? new Date(dto.validFrom) : undefined,
        validUntil: dto.validUntil ? new Date(dto.validUntil) : undefined,
        isActive: dto.isActive,
      },
    });
  }

  async remove(id: string) {
    // Soft disable keeps historical redemptions intact for accounting
    await this.prisma.coupon.update({ where: { id }, data: { isActive: false } });
    return { message: 'Coupon deactivated' };
  }
}
