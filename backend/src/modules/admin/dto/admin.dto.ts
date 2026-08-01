import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { KycStatus, TicketStatus, UserRole } from '@prisma/client';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUrl,
  IsUUID,
  Min,
  MaxLength,
} from 'class-validator';
import { PaginationQueryDto } from '../../../common/utils/pagination.util';

export class ListUsersDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: UserRole })
  @IsOptional() @IsEnum(UserRole)
  role?: UserRole;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  isActive?: boolean;
}

export class ListKycDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: KycStatus, default: KycStatus.PENDING })
  @IsOptional() @IsEnum(KycStatus)
  status?: KycStatus;
}

export class KycDecisionDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  approve: boolean;

  @ApiPropertyOptional({ example: 'Certificate is not legible' })
  @IsOptional() @IsString() @MaxLength(300)
  reason?: string;
}

export class SetUserActiveDto {
  @ApiProperty()
  @IsBoolean()
  isActive: boolean;
}

export class ProcessPayoutDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  therapistId: string;

  @ApiProperty({ example: 2800 })
  @Type(() => Number) @IsNumber() @Min(1)
  amount: number;
}

export class BroadcastNotificationDto {
  @ApiProperty({ enum: ['ALL', 'PATIENT', 'THERAPIST'] })
  @IsIn(['ALL', 'PATIENT', 'THERAPIST'])
  audience: 'ALL' | 'PATIENT' | 'THERAPIST';

  @ApiProperty({ example: 'Monsoon offer' })
  @IsString() @MaxLength(120)
  title: string;

  @ApiProperty({ example: 'Flat 30% off on all consultations this week.' })
  @IsString() @MaxLength(500)
  body: string;
}

export class CreateBannerDto {
  @ApiProperty()
  @IsUrl()
  imageUrl: string;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(120)
  title?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsUrl()
  linkUrl?: string;

  @ApiPropertyOptional({ default: true })
  @IsOptional() @IsBoolean()
  isActive?: boolean;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional() @Type(() => Number) @IsInt()
  sortOrder?: number;
}

export class CreateBlogDto {
  @ApiProperty()
  @IsString() @MaxLength(200)
  title: string;

  @ApiPropertyOptional({ description: 'Auto-generated from the title when omitted' })
  @IsOptional() @IsString() @MaxLength(200)
  slug?: string;

  @ApiProperty()
  @IsString()
  content: string;

  @ApiPropertyOptional()
  @IsOptional() @IsUrl()
  coverUrl?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional() @IsBoolean()
  published?: boolean;
}

export class CreateFaqDto {
  @ApiProperty()
  @IsString() @MaxLength(300)
  question: string;

  @ApiProperty()
  @IsString() @MaxLength(2000)
  answer: string;

  @ApiPropertyOptional({ example: 'Booking' })
  @IsOptional() @IsString() @MaxLength(60)
  category?: string;

  @ApiPropertyOptional({ default: 0 })
  @IsOptional() @Type(() => Number) @IsInt()
  sortOrder?: number;
}

export class CreateTicketDto {
  @ApiProperty()
  @IsString() @MaxLength(200)
  subject: string;

  @ApiProperty()
  @IsString() @MaxLength(2000)
  message: string;
}

export class UpdateTicketDto {
  @ApiProperty({ enum: TicketStatus })
  @IsEnum(TicketStatus)
  status: TicketStatus;
}

export class ListTicketsDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: TicketStatus })
  @IsOptional() @IsEnum(TicketStatus)
  status?: TicketStatus;
}

export class AnalyticsRangeDto {
  @ApiProperty({ example: '2026-01-01' })
  @IsDateString()
  fromDate: string;

  @ApiProperty({ example: '2026-08-01' })
  @IsDateString()
  toDate: string;
}
