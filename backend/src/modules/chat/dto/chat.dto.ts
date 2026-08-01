import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsString, IsUrl, IsUUID, MaxLength } from 'class-validator';

export class SendMessageDto {
  @ApiPropertyOptional({ format: 'uuid', description: 'Existing thread id' })
  @IsOptional() @IsUUID()
  threadId?: string;

  @ApiPropertyOptional({
    format: 'uuid',
    description: 'Required when threadId is omitted; opens a new conversation',
  })
  @IsOptional() @IsUUID()
  recipientUserId?: string;

  @ApiProperty({ example: 'I have pain in my lower back since 2 days.' })
  @IsString() @MaxLength(4000)
  content: string;

  @ApiPropertyOptional()
  @IsOptional() @IsUrl()
  attachmentUrl?: string;
}

export class TypingDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  threadId: string;

  @ApiProperty()
  @IsBoolean()
  isTyping: boolean;
}

export class OpenThreadDto {
  @ApiProperty({ format: 'uuid', description: 'The other participant user id' })
  @IsUUID()
  recipientUserId: string;
}
