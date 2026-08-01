import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ChatService } from './chat.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PaginationQueryDto } from '../../common/utils/pagination.util';
import { OpenThreadDto, SendMessageDto } from './dto/chat.dto';

@ApiTags('Chat')
@ApiBearerAuth('access-token')
@Controller('chat')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get('threads')
  @ApiOperation({ summary: 'Conversation list with unread counts' })
  threads(@CurrentUser('sub') userId: string) {
    return this.chatService.getThreads(userId);
  }

  @Post('threads')
  @ApiOperation({ summary: 'Open (or reuse) a conversation with another user' })
  openThread(@CurrentUser('sub') userId: string, @Body() dto: OpenThreadDto) {
    return this.chatService.getOrCreateThread(userId, dto.recipientUserId);
  }

  @Get('unread-count')
  @ApiOperation({ summary: 'Total unread messages across all conversations' })
  unread(@CurrentUser('sub') userId: string) {
    return this.chatService.getUnreadTotal(userId);
  }

  @Get('threads/:threadId/messages')
  @ApiOperation({ summary: 'Paginated message history, oldest first' })
  messages(
    @CurrentUser('sub') userId: string,
    @Param('threadId') threadId: string,
    @Query() query: PaginationQueryDto,
  ) {
    return this.chatService.getMessages(userId, threadId, query);
  }

  @Post('messages')
  @ApiOperation({ summary: 'Send a message over REST (socket is preferred)' })
  send(@CurrentUser('sub') userId: string, @Body() dto: SendMessageDto) {
    return this.chatService.sendMessage(userId, dto);
  }

  @Patch('threads/:threadId/read')
  @ApiOperation({ summary: 'Mark every incoming message in a thread as read' })
  async markRead(@CurrentUser('sub') userId: string, @Param('threadId') threadId: string) {
    const count = await this.chatService.markThreadRead(userId, threadId);
    return { message: `${count} messages marked as read` };
  }

  @Post('threads/:threadId/attachment')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } }))
  @ApiOperation({ summary: 'Upload an attachment and get its URL to send' })
  attachment(
    @CurrentUser('sub') userId: string,
    @Param('threadId') threadId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.chatService.uploadAttachment(userId, threadId, file);
  }
}
