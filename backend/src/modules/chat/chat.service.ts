import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { NotificationType, UserRole } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { UploadsService } from '../uploads/uploads.service';
import { buildPagination, paginate, PaginationQueryDto } from '../../common/utils/pagination.util';
import { SendMessageDto } from './dto/chat.dto';

@Injectable()
export class ChatService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly uploads: UploadsService,
  ) {}

  /**
   * Opens (or reuses) the single thread between a patient and a therapist.
   * Threads are keyed on the pair so history survives across appointments.
   */
  async getOrCreateThread(userId: string, otherUserId: string) {
    const [me, other] = await Promise.all([
      this.resolveParticipant(userId),
      this.resolveParticipant(otherUserId),
    ]);

    // Exactly one side must be the patient and the other the therapist
    const patientSide = me.role === UserRole.PATIENT ? me : other;
    const therapistSide = me.role === UserRole.THERAPIST ? me : other;

    if (patientSide.role !== UserRole.PATIENT || therapistSide.role !== UserRole.THERAPIST) {
      throw new ForbiddenException('Chat is only available between a patient and a therapist');
    }

    return this.prisma.chatThread.upsert({
      where: {
        patientId_therapistId: {
          patientId: patientSide.profileId,
          therapistId: therapistSide.profileId,
        },
      },
      create: {
        patientId: patientSide.profileId,
        therapistId: therapistSide.profileId,
      },
      update: {},
    });
  }

  async sendMessage(senderUserId: string, dto: SendMessageDto) {
    const thread = dto.threadId
      ? await this.prisma.chatThread.findUnique({ where: { id: dto.threadId } })
      : await this.getOrCreateThread(senderUserId, dto.recipientUserId!);

    if (!thread) throw new NotFoundException('Conversation not found');

    const participants = await this.threadParticipantUserIds(thread.id);
    if (!participants.includes(senderUserId)) {
      throw new ForbiddenException('You are not part of this conversation');
    }

    const recipientId = participants.find((id) => id !== senderUserId)!;

    const message = await this.prisma.chatMessage.create({
      data: {
        threadId: thread.id,
        senderId: senderUserId,
        content: dto.content,
        attachmentUrl: dto.attachmentUrl,
      },
      include: {
        sender: { select: { id: true, fullName: true, avatarUrl: true } },
      },
    });

    // Bump the thread so conversation lists sort by recent activity
    await this.prisma.chatThread.update({
      where: { id: thread.id },
      data: { updatedAt: new Date() },
    });

    // Push notification is fire-and-forget; a delivery failure must not
    // prevent the message itself from being persisted and broadcast
    void this.notifications
      .send({
        userId: recipientId,
        type: NotificationType.CHAT,
        title: message.sender.fullName,
        body: dto.attachmentUrl && !dto.content ? 'Sent an attachment' : dto.content.slice(0, 120),
        data: { threadId: thread.id, messageId: message.id },
      })
      .catch(() => undefined);

    return { ...message, recipientId };
  }

  async getThreads(userId: string) {
    const participant = await this.resolveParticipant(userId);

    const threads = await this.prisma.chatThread.findMany({
      where:
        participant.role === UserRole.PATIENT
          ? { patientId: participant.profileId }
          : { therapistId: participant.profileId },
      orderBy: { updatedAt: 'desc' },
      include: {
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: { content: true, createdAt: true, senderId: true, attachmentUrl: true },
        },
      },
    });

    // Resolve the other party's display data for each thread
    return Promise.all(
      threads.map(async (thread) => {
        const other =
          participant.role === UserRole.PATIENT
            ? await this.prisma.therapist.findUnique({
                where: { id: thread.therapistId },
                select: {
                  id: true,
                  specialization: true,
                  user: { select: { id: true, fullName: true, avatarUrl: true } },
                },
              })
            : await this.prisma.patient.findUnique({
                where: { id: thread.patientId },
                select: {
                  id: true,
                  user: { select: { id: true, fullName: true, avatarUrl: true } },
                },
              });

        const unreadCount = await this.prisma.chatMessage.count({
          where: { threadId: thread.id, senderId: { not: userId }, isRead: false },
        });

        return {
          id: thread.id,
          participant: other?.user ?? null,
          specialization: (other as any)?.specialization ?? null,
          lastMessage: thread.messages[0] ?? null,
          unreadCount,
          updatedAt: thread.updatedAt,
        };
      }),
    );
  }

  async getMessages(userId: string, threadId: string, query: PaginationQueryDto) {
    await this.assertThreadParticipant(userId, threadId);
    const { skip, take, page, limit } = buildPagination(query);

    const [items, total] = await this.prisma.$transaction([
      this.prisma.chatMessage.findMany({
        where: { threadId },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
        include: { sender: { select: { id: true, fullName: true, avatarUrl: true } } },
      }),
      this.prisma.chatMessage.count({ where: { threadId } }),
    ]);

    // Oldest-first is what the chat UI renders, but paging works newest-first
    return paginate(items.reverse(), total, page, limit);
  }

  async markThreadRead(userId: string, threadId: string): Promise<number> {
    await this.assertThreadParticipant(userId, threadId);

    const { count } = await this.prisma.chatMessage.updateMany({
      where: { threadId, senderId: { not: userId }, isRead: false },
      data: { isRead: true },
    });

    return count;
  }

  async getUnreadTotal(userId: string) {
    const threadIds = await this.getThreadIdsForUser(userId);
    const count = await this.prisma.chatMessage.count({
      where: { threadId: { in: threadIds }, senderId: { not: userId }, isRead: false },
    });
    return { count };
  }

  async uploadAttachment(userId: string, threadId: string, file: Express.Multer.File) {
    await this.assertThreadParticipant(userId, threadId);
    const url = await this.uploads.uploadDocument(file, `chat/${threadId}`);
    return { attachmentUrl: url };
  }

  /** Thread ids the user belongs to, used to pre-join socket rooms. */
  async getThreadIdsForUser(userId: string): Promise<string[]> {
    const participant = await this.resolveParticipant(userId).catch(() => null);
    if (!participant) return [];

    const threads = await this.prisma.chatThread.findMany({
      where:
        participant.role === UserRole.PATIENT
          ? { patientId: participant.profileId }
          : { therapistId: participant.profileId },
      select: { id: true },
    });

    return threads.map((t) => t.id);
  }

  async assertThreadParticipant(userId: string, threadId: string) {
    const participants = await this.threadParticipantUserIds(threadId);
    if (!participants.includes(userId)) {
      throw new ForbiddenException('You are not part of this conversation');
    }
  }

  // -------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------

  private async threadParticipantUserIds(threadId: string): Promise<string[]> {
    const thread = await this.prisma.chatThread.findUnique({ where: { id: threadId } });
    if (!thread) throw new NotFoundException('Conversation not found');

    const [patient, therapist] = await Promise.all([
      this.prisma.patient.findUnique({
        where: { id: thread.patientId },
        select: { userId: true },
      }),
      this.prisma.therapist.findUnique({
        where: { id: thread.therapistId },
        select: { userId: true },
      }),
    ]);

    return [patient?.userId, therapist?.userId].filter(Boolean) as string[];
  }

  /** Maps a user id to their role plus the matching profile row id. */
  private async resolveParticipant(
    userId: string,
  ): Promise<{ role: UserRole; profileId: string }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        role: true,
        patient: { select: { id: true } },
        therapist: { select: { id: true } },
      },
    });

    if (!user) throw new NotFoundException('User not found');

    if (user.role === UserRole.PATIENT && user.patient) {
      return { role: UserRole.PATIENT, profileId: user.patient.id };
    }
    if (user.role === UserRole.THERAPIST && user.therapist) {
      return { role: UserRole.THERAPIST, profileId: user.therapist.id };
    }

    throw new ForbiddenException('Only patients and therapists can use chat');
  }
}
