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
  UserRole,
} from '@prisma/client';
import { RtcRole, RtcTokenBuilder } from 'agora-token';
import * as crypto from 'crypto';
import { PrismaService } from '../../database/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

/** Agora tokens are short-lived; the client refreshes before expiry. */
const TOKEN_TTL_SECONDS = 3600;
/** How early before the scheduled start the room may be joined. */
const JOIN_WINDOW_MINUTES = 15;

@Injectable()
export class VideoCallService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly notifications: NotificationsService,
  ) {}

  /**
   * Issues an Agora RTC token scoped to one appointment's channel. Only the
   * two participants can obtain a token, and only inside the join window.
   */
  async joinSession(userId: string, role: UserRole, appointmentId: string) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id: appointmentId },
      include: {
        videoSession: true,
        patient: { select: { userId: true } },
        therapist: { select: { userId: true } },
      },
    });

    if (!appointment) throw new NotFoundException('Appointment not found');

    if (appointment.type !== AppointmentType.VIDEO_CONSULTATION) {
      throw new BadRequestException('This appointment is not a video consultation');
    }

    const isPatient = appointment.patient.userId === userId;
    const isTherapist = appointment.therapist.userId === userId;
    if (!isPatient && !isTherapist) {
      throw new ForbiddenException('You are not a participant in this consultation');
    }

    const allowedStatuses: AppointmentStatus[] = [
      AppointmentStatus.CONFIRMED,
      AppointmentStatus.IN_PROGRESS,
    ];
    if (!allowedStatuses.includes(appointment.status)) {
      throw new BadRequestException(
        `The consultation room is not open (status: ${appointment.status})`,
      );
    }

    this.assertWithinJoinWindow(appointment.scheduledDate, appointment.startTime, appointment.endTime);

    // Reuse the channel across rejoins so both parties land in the same room
    const session =
      appointment.videoSession ??
      (await this.prisma.videoSession.create({
        data: {
          appointmentId: appointment.id,
          channelName: `toc_${crypto.createHash('sha1').update(appointment.id).digest('hex').slice(0, 24)}`,
        },
      }));

    // Deterministic numeric uid per user keeps reconnects stable
    const uid = this.numericUidFor(userId);
    const expiresAt = Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS;

    const token = RtcTokenBuilder.buildTokenWithUid(
      this.config.getOrThrow<string>('AGORA_APP_ID'),
      this.config.getOrThrow<string>('AGORA_APP_CERTIFICATE'),
      session.channelName,
      uid,
      RtcRole.PUBLISHER,
      TOKEN_TTL_SECONDS,
      TOKEN_TTL_SECONDS,
    );

    // The first join starts the clock and flips the appointment to in-progress
    if (!session.startedAt) {
      await this.prisma.$transaction([
        this.prisma.videoSession.update({
          where: { id: session.id },
          data: { startedAt: new Date() },
        }),
        this.prisma.appointment.update({
          where: { id: appointment.id },
          data: { status: AppointmentStatus.IN_PROGRESS },
        }),
      ]);

      // Ring the other participant
      const otherUserId = isPatient ? appointment.therapist.userId : appointment.patient.userId;
      await this.notifications.send({
        userId: otherUserId,
        type: NotificationType.APPOINTMENT,
        title: 'Consultation started',
        body: 'The other participant has joined the video consultation.',
        data: { appointmentId: appointment.id, channelName: session.channelName },
      });
    }

    return {
      appId: this.config.get<string>('AGORA_APP_ID'),
      channelName: session.channelName,
      token,
      uid,
      expiresAt,
      role: isTherapist ? 'THERAPIST' : 'PATIENT',
    };
  }

  /** Refreshes an expiring token without touching session state. */
  async renewToken(userId: string, appointmentId: string) {
    const session = await this.prisma.videoSession.findUnique({
      where: { appointmentId },
      include: {
        appointment: {
          select: {
            patient: { select: { userId: true } },
            therapist: { select: { userId: true } },
          },
        },
      },
    });

    if (!session) throw new NotFoundException('No active video session');

    const { patient, therapist } = session.appointment;
    if (patient.userId !== userId && therapist.userId !== userId) {
      throw new ForbiddenException('You are not a participant in this consultation');
    }
    if (session.endedAt) throw new BadRequestException('This consultation has already ended');

    const uid = this.numericUidFor(userId);
    const token = RtcTokenBuilder.buildTokenWithUid(
      this.config.getOrThrow<string>('AGORA_APP_ID'),
      this.config.getOrThrow<string>('AGORA_APP_CERTIFICATE'),
      session.channelName,
      uid,
      RtcRole.PUBLISHER,
      TOKEN_TTL_SECONDS,
      TOKEN_TTL_SECONDS,
    );

    return {
      token,
      uid,
      channelName: session.channelName,
      expiresAt: Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS,
    };
  }

  /** Ends the call, stores the duration and completes the appointment. */
  async endSession(userId: string, appointmentId: string) {
    const session = await this.prisma.videoSession.findUnique({
      where: { appointmentId },
      include: {
        appointment: {
          select: {
            id: true,
            status: true,
            patient: { select: { userId: true } },
            therapist: { select: { userId: true } },
          },
        },
      },
    });

    if (!session) throw new NotFoundException('No active video session');

    const { patient, therapist } = session.appointment;
    if (patient.userId !== userId && therapist.userId !== userId) {
      throw new ForbiddenException('You are not a participant in this consultation');
    }

    if (session.endedAt) {
      return { message: 'Session already ended', durationSecs: session.durationSecs };
    }

    const endedAt = new Date();
    const durationSecs = session.startedAt
      ? Math.floor((endedAt.getTime() - session.startedAt.getTime()) / 1000)
      : 0;

    await this.prisma.$transaction([
      this.prisma.videoSession.update({
        where: { id: session.id },
        data: { endedAt, durationSecs },
      }),
      this.prisma.appointment.update({
        where: { id: session.appointment.id },
        data: { status: AppointmentStatus.COMPLETED },
      }),
    ]);

    await this.notifications.send({
      userId: patient.userId,
      type: NotificationType.APPOINTMENT,
      title: 'Consultation ended',
      body: 'Your video consultation has ended. Please rate your experience.',
      data: { appointmentId },
    });

    return { message: 'Session ended', durationSecs };
  }

  async getSession(userId: string, appointmentId: string) {
    const session = await this.prisma.videoSession.findUnique({
      where: { appointmentId },
      include: {
        appointment: {
          select: {
            patient: { select: { userId: true } },
            therapist: { select: { userId: true } },
          },
        },
      },
    });
    if (!session) return null;

    const { patient, therapist } = session.appointment;
    if (patient.userId !== userId && therapist.userId !== userId) {
      throw new ForbiddenException('You are not a participant in this consultation');
    }

    return {
      id: session.id,
      channelName: session.channelName,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      durationSecs: session.durationSecs,
    };
  }

  // -------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------

  private assertWithinJoinWindow(scheduledDate: Date, startTime: string, endTime: string) {
    const [startH, startM] = startTime.split(':').map(Number);
    const [endH, endM] = endTime.split(':').map(Number);

    const opensAt = new Date(scheduledDate);
    opensAt.setHours(startH, startM - JOIN_WINDOW_MINUTES, 0, 0);

    // A grace period after the scheduled end lets overrunning sessions finish
    const closesAt = new Date(scheduledDate);
    closesAt.setHours(endH, endM + JOIN_WINDOW_MINUTES, 0, 0);

    const now = new Date();
    if (now < opensAt) {
      throw new BadRequestException(
        `The room opens ${JOIN_WINDOW_MINUTES} minutes before the scheduled time`,
      );
    }
    if (now > closesAt) {
      throw new BadRequestException('The consultation window for this appointment has closed');
    }
  }

  /**
   * Agora uids must be 32-bit unsigned integers, so the UUID is hashed down
   * to a stable number rather than using a random uid on every join.
   */
  private numericUidFor(userId: string): number {
    const hash = crypto.createHash('md5').update(userId).digest();
    // Keep it below 2^31 to stay clear of Agora's reserved range
    return hash.readUInt32BE(0) % 2_147_483_647;
  }
}
