import { Logger, UseFilters } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  WsException,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { ChatService } from './chat.service';
import { SendMessageDto, TypingDto } from './dto/chat.dto';

interface AuthenticatedSocket extends Socket {
  userId?: string;
  userRole?: string;
}

@WebSocketGateway({
  namespace: '/chat',
  cors: { origin: true, credentials: true },
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(ChatGateway.name);

  /** Tracks every live socket per user so multi-device works correctly. */
  private readonly onlineUsers = new Map<string, Set<string>>();

  constructor(
    private readonly chatService: ChatService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  /**
   * Sockets authenticate during the handshake using the same access token as
   * the REST API. An unauthenticated socket is disconnected immediately.
   */
  async handleConnection(client: AuthenticatedSocket) {
    try {
      const token =
        (client.handshake.auth?.token as string) ??
        client.handshake.headers.authorization?.replace('Bearer ', '');

      if (!token) throw new Error('Missing token');

      const payload = await this.jwt.verifyAsync<{ sub: string; role: string }>(token, {
        secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
      });

      client.userId = payload.sub;
      client.userRole = payload.role;

      const sockets = this.onlineUsers.get(payload.sub) ?? new Set<string>();
      sockets.add(client.id);
      this.onlineUsers.set(payload.sub, sockets);

      // A personal room lets the server push events without knowing socket ids
      client.join(`user:${payload.sub}`);

      // Tell existing conversation partners this user is now reachable
      const threadIds = await this.chatService.getThreadIdsForUser(payload.sub);
      threadIds.forEach((id) => client.join(`thread:${id}`));

      client.broadcast.emit('user:online', { userId: payload.sub });
      this.logger.log(`Socket connected: ${payload.sub}`);
    } catch (error) {
      this.logger.warn(`Rejected socket connection: ${(error as Error).message}`);
      client.emit('error', { message: 'Authentication failed' });
      client.disconnect(true);
    }
  }

  handleDisconnect(client: AuthenticatedSocket) {
    if (!client.userId) return;

    const sockets = this.onlineUsers.get(client.userId);
    sockets?.delete(client.id);

    // Only mark offline when the user's last device disconnects
    if (sockets && sockets.size === 0) {
      this.onlineUsers.delete(client.userId);
      client.broadcast.emit('user:offline', { userId: client.userId });
    }
  }

  @SubscribeMessage('message:send')
  async handleSendMessage(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() dto: SendMessageDto,
  ) {
    if (!client.userId) throw new WsException('Not authenticated');

    const message = await this.chatService.sendMessage(client.userId, dto);

    // Late-created threads need the sender joined before the broadcast
    client.join(`thread:${message.threadId}`);
    this.server.to(`thread:${message.threadId}`).emit('message:new', message);

    // Push to the recipient's personal room so unread badges update even if
    // they never opened this thread in the current session
    this.server.to(`user:${message.recipientId}`).emit('thread:updated', {
      threadId: message.threadId,
      lastMessage: message.content,
      at: message.createdAt,
    });

    return { status: 'sent', messageId: message.id };
  }

  @SubscribeMessage('thread:join')
  async handleJoinThread(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() body: { threadId: string },
  ) {
    if (!client.userId) throw new WsException('Not authenticated');

    await this.chatService.assertThreadParticipant(client.userId, body.threadId);
    client.join(`thread:${body.threadId}`);

    const readCount = await this.chatService.markThreadRead(client.userId, body.threadId);
    if (readCount > 0) {
      this.server.to(`thread:${body.threadId}`).emit('message:read', {
        threadId: body.threadId,
        readerId: client.userId,
      });
    }

    return { status: 'joined', threadId: body.threadId };
  }

  @SubscribeMessage('thread:leave')
  handleLeaveThread(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() body: { threadId: string },
  ) {
    client.leave(`thread:${body.threadId}`);
    return { status: 'left' };
  }

  @SubscribeMessage('typing')
  async handleTyping(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() dto: TypingDto,
  ) {
    if (!client.userId) throw new WsException('Not authenticated');

    // Only other members of the room receive the indicator
    client.to(`thread:${dto.threadId}`).emit('typing', {
      threadId: dto.threadId,
      userId: client.userId,
      isTyping: dto.isTyping,
    });
  }

  @SubscribeMessage('presence:check')
  handlePresenceCheck(@MessageBody() body: { userIds: string[] }) {
    return body.userIds.map((userId) => ({
      userId,
      online: this.onlineUsers.has(userId),
    }));
  }

  /** Used by other modules to push a message into a live thread. */
  emitToThread(threadId: string, event: string, payload: unknown) {
    this.server?.to(`thread:${threadId}`).emit(event, payload);
  }

  isOnline(userId: string): boolean {
    return this.onlineUsers.has(userId);
  }
}
