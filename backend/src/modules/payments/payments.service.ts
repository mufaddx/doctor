import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  AppointmentStatus,
  NotificationType,
  PaymentMethod,
  PaymentStatus,
  Prisma,
  TransactionSource,
  TransactionType,
} from '@prisma/client';
import * as crypto from 'crypto';
import Razorpay from 'razorpay';
import { PrismaService } from '../../database/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { WalletService } from '../wallet/wallet.service';
import { buildPagination, paginate, PaginationQueryDto } from '../../common/utils/pagination.util';
import { CreateOrderDto, RefundRequestDto, VerifyPaymentDto } from './dto/payment.dto';

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);
  private readonly razorpay: Razorpay;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly wallet: WalletService,
    private readonly notifications: NotificationsService,
  ) {
    this.razorpay = new Razorpay({
      key_id: this.config.getOrThrow<string>('RAZORPAY_KEY_ID'),
      key_secret: this.config.getOrThrow<string>('RAZORPAY_KEY_SECRET'),
    });
  }

  // -------------------------------------------------------
  // ORDER CREATION
  // -------------------------------------------------------

  /**
   * Creates a Razorpay order for an appointment. Amounts always come from the
   * database, never from the client, so a tampered request cannot underpay.
   */
  async createOrder(userId: string, dto: CreateOrderDto) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id: dto.appointmentId },
      include: { patient: { select: { userId: true } }, payment: true },
    });

    if (!appointment) throw new NotFoundException('Appointment not found');
    if (appointment.patient.userId !== userId) {
      throw new BadRequestException('This appointment does not belong to you');
    }
    if (appointment.payment?.status === PaymentStatus.PAID) {
      throw new BadRequestException('This appointment is already paid');
    }
    if (
      appointment.status === AppointmentStatus.CANCELLED ||
      appointment.status === AppointmentStatus.REJECTED
    ) {
      throw new BadRequestException('Cannot pay for a cancelled appointment');
    }

    const amount = Number(appointment.totalAmount);

    // Wallet payments settle instantly without going through Razorpay
    if (dto.method === PaymentMethod.WALLET) {
      return this.payFromWallet(userId, appointment.id, amount);
    }

    // Razorpay expects the amount in paise
    const order = await this.razorpay.orders.create({
      amount: Math.round(amount * 100),
      currency: 'INR',
      receipt: `appt_${appointment.id.slice(0, 30)}`,
      notes: { appointmentId: appointment.id, patientUserId: userId },
    });

    const payment = await this.prisma.payment.upsert({
      where: { appointmentId: appointment.id },
      create: {
        appointmentId: appointment.id,
        razorpayOrderId: order.id,
        method: dto.method,
        status: PaymentStatus.PENDING,
        amount,
      },
      update: {
        razorpayOrderId: order.id,
        method: dto.method,
        status: PaymentStatus.PENDING,
        amount,
      },
    });

    return {
      paymentId: payment.id,
      razorpayOrderId: order.id,
      razorpayKeyId: this.config.get<string>('RAZORPAY_KEY_ID'),
      amount,
      currency: 'INR',
      appointmentId: appointment.id,
    };
  }

  /** Debits the in-app wallet and confirms the booking in one transaction. */
  private async payFromWallet(userId: string, appointmentId: string, amount: number) {
    const wallet = await this.prisma.wallet.findUnique({ where: { userId } });
    if (!wallet) throw new NotFoundException('Wallet not found');
    if (Number(wallet.balance) < amount) {
      throw new BadRequestException('Insufficient wallet balance');
    }

    const result = await this.prisma.$transaction(async (tx) => {
      await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance: { decrement: amount } },
      });

      await tx.transaction.create({
        data: {
          walletId: wallet.id,
          type: TransactionType.DEBIT,
          source: TransactionSource.APPOINTMENT_PAYMENT,
          amount,
          description: 'Payment for appointment',
          referenceId: appointmentId,
        },
      });

      const payment = await tx.payment.upsert({
        where: { appointmentId },
        create: {
          appointmentId,
          method: PaymentMethod.WALLET,
          status: PaymentStatus.PAID,
          amount,
        },
        update: { method: PaymentMethod.WALLET, status: PaymentStatus.PAID, amount },
      });

      return payment;
    });

    await this.onPaymentSuccess(appointmentId);
    return { paymentId: result.id, status: PaymentStatus.PAID, method: PaymentMethod.WALLET, amount };
  }

  // -------------------------------------------------------
  // VERIFICATION
  // -------------------------------------------------------

  /**
   * Verifies the HMAC signature returned by the Razorpay checkout. Without
   * this check a client could claim a successful payment that never happened.
   */
  async verifyPayment(userId: string, dto: VerifyPaymentDto) {
    const payment = await this.prisma.payment.findFirst({
      where: { razorpayOrderId: dto.razorpayOrderId },
      include: { appointment: { include: { patient: { select: { userId: true } } } } },
    });

    if (!payment) throw new NotFoundException('Payment record not found');
    if (payment.appointment.patient.userId !== userId) {
      throw new BadRequestException('This payment does not belong to you');
    }

    const expectedSignature = crypto
      .createHmac('sha256', this.config.getOrThrow<string>('RAZORPAY_KEY_SECRET'))
      .update(`${dto.razorpayOrderId}|${dto.razorpayPaymentId}`)
      .digest('hex');

    // timingSafeEqual avoids leaking information through comparison timing
    const signatureValid =
      expectedSignature.length === dto.razorpaySignature.length &&
      crypto.timingSafeEqual(
        Buffer.from(expectedSignature),
        Buffer.from(dto.razorpaySignature),
      );

    if (!signatureValid) {
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: { status: PaymentStatus.FAILED },
      });
      throw new BadRequestException('Payment signature verification failed');
    }

    const updated = await this.prisma.payment.update({
      where: { id: payment.id },
      data: {
        razorpayPaymentId: dto.razorpayPaymentId,
        razorpaySignature: dto.razorpaySignature,
        status: PaymentStatus.PAID,
      },
    });

    await this.onPaymentSuccess(payment.appointmentId);
    return { paymentId: updated.id, status: updated.status, amount: updated.amount };
  }

  /**
   * Razorpay webhook. This is the source of truth for payment state because
   * the client callback can be lost if the app is killed mid-checkout.
   */
  async handleWebhook(rawBody: Buffer, signature: string) {
    const secret = this.config.get<string>('RAZORPAY_WEBHOOK_SECRET');
    if (!secret) {
      this.logger.warn('Webhook received but RAZORPAY_WEBHOOK_SECRET is not configured');
      return { received: false };
    }

    const expected = crypto.createHmac('sha256', secret).update(rawBody).digest('hex');
    if (expected !== signature) {
      throw new BadRequestException('Invalid webhook signature');
    }

    const event = JSON.parse(rawBody.toString());
    const entity = event.payload?.payment?.entity;
    if (!entity?.order_id) return { received: true };

    const payment = await this.prisma.payment.findFirst({
      where: { razorpayOrderId: entity.order_id },
    });
    if (!payment) return { received: true };

    if (event.event === 'payment.captured' && payment.status !== PaymentStatus.PAID) {
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: { status: PaymentStatus.PAID, razorpayPaymentId: entity.id },
      });
      await this.onPaymentSuccess(payment.appointmentId);
    } else if (event.event === 'payment.failed') {
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: { status: PaymentStatus.FAILED, razorpayPaymentId: entity.id },
      });
    }

    return { received: true };
  }

  /** Shared post-payment side effects: confirm booking, notify both parties. */
  private async onPaymentSuccess(appointmentId: string) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id: appointmentId },
      include: {
        patient: { select: { userId: true } },
        therapist: { select: { userId: true, user: { select: { fullName: true } } } },
      },
    });
    if (!appointment) return;

    await this.notifications.send({
      userId: appointment.patient.userId,
      type: NotificationType.PAYMENT,
      title: 'Payment successful',
      body: `Your payment of ₹${appointment.totalAmount} was received. Booking is being confirmed.`,
      data: { appointmentId },
    });

    await this.notifications.send({
      userId: appointment.therapist.userId,
      type: NotificationType.PAYMENT,
      title: 'Payment received',
      body: `Payment for an upcoming appointment has been received.`,
      data: { appointmentId },
    });
  }

  // -------------------------------------------------------
  // REFUNDS
  // -------------------------------------------------------

  /**
   * Issues a refund. Razorpay payments are refunded to the source; wallet
   * payments are credited straight back to the wallet.
   */
  async refund(paymentId: string, dto: RefundRequestDto) {
    const payment = await this.prisma.payment.findUnique({
      where: { id: paymentId },
      include: {
        refund: true,
        appointment: { include: { patient: { select: { userId: true } } } },
      },
    });

    if (!payment) throw new NotFoundException('Payment not found');
    if (payment.status !== PaymentStatus.PAID) {
      throw new BadRequestException('Only captured payments can be refunded');
    }
    if (payment.refund) throw new BadRequestException('A refund already exists for this payment');

    const amount = dto.amount ?? Number(payment.amount);
    if (amount <= 0 || amount > Number(payment.amount)) {
      throw new BadRequestException('Refund amount exceeds the captured amount');
    }

    let razorpayRefundId: string | null = null;

    if (payment.method === PaymentMethod.WALLET) {
      await this.wallet.credit(
        payment.appointment.patient.userId,
        amount,
        TransactionSource.REFUND,
        'Refund for cancelled appointment',
        payment.appointmentId,
      );
    } else if (payment.razorpayPaymentId) {
      const rzpRefund = await this.razorpay.payments.refund(payment.razorpayPaymentId, {
        amount: Math.round(amount * 100),
        speed: 'normal',
        notes: { reason: dto.reason ?? 'Appointment cancelled' },
      });
      razorpayRefundId = rzpRefund.id;
    }

    const isPartial = amount < Number(payment.amount);

    const refund = await this.prisma.$transaction(async (tx) => {
      const created = await tx.refund.create({
        data: {
          paymentId: payment.id,
          amount,
          reason: dto.reason,
          razorpayRefundId,
          status: PaymentStatus.REFUNDED,
          processedAt: new Date(),
        },
      });

      await tx.payment.update({
        where: { id: payment.id },
        data: {
          status: isPartial ? PaymentStatus.PARTIALLY_REFUNDED : PaymentStatus.REFUNDED,
        },
      });

      return created;
    });

    await this.notifications.send({
      userId: payment.appointment.patient.userId,
      type: NotificationType.PAYMENT,
      title: 'Refund initiated',
      body: `A refund of ₹${amount} has been initiated and will reflect in 5-7 working days.`,
      data: { appointmentId: payment.appointmentId, refundId: refund.id },
    });

    return refund;
  }

  // -------------------------------------------------------
  // QUERIES
  // -------------------------------------------------------

  async findOneForUser(userId: string, paymentId: string) {
    const payment = await this.prisma.payment.findUnique({
      where: { id: paymentId },
      include: {
        refund: true,
        appointment: {
          select: {
            id: true,
            scheduledDate: true,
            startTime: true,
            type: true,
            patient: { select: { userId: true } },
            therapist: { select: { userId: true, user: { select: { fullName: true } } } },
          },
        },
      },
    });

    if (!payment) throw new NotFoundException('Payment not found');

    const isParticipant =
      payment.appointment.patient.userId === userId ||
      payment.appointment.therapist.userId === userId;
    if (!isParticipant) throw new NotFoundException('Payment not found');

    return payment;
  }

  /** Admin payments table with search across order and payment ids. */
  async findAllForAdmin(query: PaginationQueryDto & { status?: PaymentStatus }) {
    const { skip, take, page, limit } = buildPagination(query);

    const where: Prisma.PaymentWhereInput = {
      ...(query.status ? { status: query.status } : {}),
      ...(query.search
        ? {
            OR: [
              { razorpayOrderId: { contains: query.search } },
              { razorpayPaymentId: { contains: query.search } },
            ],
          }
        : {}),
    };

    const [items, total] = await this.prisma.$transaction([
      this.prisma.payment.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        include: {
          refund: true,
          appointment: {
            select: {
              id: true,
              type: true,
              scheduledDate: true,
              patient: { select: { user: { select: { fullName: true } } } },
              therapist: { select: { user: { select: { fullName: true } } } },
            },
          },
        },
      }),
      this.prisma.payment.count({ where }),
    ]);

    return paginate(items, total, page, limit);
  }
}
