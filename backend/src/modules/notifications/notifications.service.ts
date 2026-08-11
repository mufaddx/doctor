import { Injectable } from '@nestjs/common';
import { NotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';
import { FirebaseService } from './firebase.service';
import {
  PaginationQueryDto,
  buildPagination,
  paginate,
} from '../../common/utils/pagination.util';

@Injectable()
export class NotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly firebase: FirebaseService,
  ) {}

  /**
   * Persists an in-app notification and pushes it to all of the user's
   * registered devices. Dead FCM tokens are pruned automatically.
   */
  async send(params: {
    userId: string;
    type: NotificationType;
    title: string;
    body: string;
    data?: Record<string, string>;
  }) {
    const notification = await this.prisma.notification.create({
      data: {
        userId: params.userId,
        type: params.type,
        title: params.title,
        body: params.body,
        data: (params.data ?? {}) as Prisma.InputJsonValue,
      },
    });

    const user = await this.prisma.user.findUnique({
      where: { id: params.userId },
      select: { fcmTokens: true },
    });

    const fcmTokens = (user?.fcmTokens as string[] | undefined) ?? [];
    if (fcmTokens.length) {
      const { invalidTokens } = await this.firebase.sendMulticast(fcmTokens, {
        title: params.title,
        body: params.body,
        data: { ...(params.data ?? {}), type: params.type, notificationId: notification.id },
      });

      if (invalidTokens.length) {
        await this.prisma.user.update({
          where: { id: params.userId },
          data: { fcmTokens: fcmTokens.filter((t) => !invalidTokens.includes(t)) },
        });
      }
    }

    return notification;
  }

  /** Broadcast used by admin "Send Notification" campaigns. */
  async sendBulk(userIds: string[], payload: { type: NotificationType; title: string; body: string }) {
    const results = await Promise.allSettled(
      userIds.map((userId) => this.send({ userId, ...payload })),
    );
    return {
      sent: results.filter((r) => r.status === 'fulfilled').length,
      failed: results.filter((r) => r.status === 'rejected').length,
    };
  }

  async findAllForUser(userId: string, query: PaginationQueryDto) {
    const { skip, take, page, limit } = buildPagination(query);

    const [items, total] = await this.prisma.$transaction([
      this.prisma.notification.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.notification.count({ where: { userId } }),
    ]);

    return paginate(items, total, page, limit);
  }

  async unreadCount(userId: string) {
    const count = await this.prisma.notification.count({ where: { userId, isRead: false } });
    return { count };
  }

  async markAsRead(userId: string, notificationId: string) {
    await this.prisma.notification.updateMany({
      where: { id: notificationId, userId },
      data: { isRead: true },
    });
    return { message: 'Notification marked as read' };
  }

  async markAllAsRead(userId: string) {
    const { count } = await this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });
    return { message: `${count} notifications marked as read` };
  }

  async remove(userId: string, notificationId: string) {
    await this.prisma.notification.deleteMany({ where: { id: notificationId, userId } });
    return { message: 'Notification deleted' };
  }
}
