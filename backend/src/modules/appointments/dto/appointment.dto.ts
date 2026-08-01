import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { AppointmentStatus, AppointmentType } from '@prisma/client';
import {
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';
import { PaginationQueryDto } from '../../../common/utils/pagination.util';

const TIME_PATTERN = /^([01]\d|2[0-3]):(00|30)$/;

export class CreateAppointmentDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  therapistId: string;

  @ApiProperty({ enum: AppointmentType })
  @IsEnum(AppointmentType)
  type: AppointmentType;

  @ApiProperty({ example: '2026-08-15' })
  @IsDateString()
  scheduledDate: string;

  @ApiProperty({ example: '09:00' })
  @IsString() @Matches(TIME_PATTERN, { message: 'startTime must be HH:mm on a 30-minute boundary' })
  startTime: string;

  @ApiPropertyOptional({ example: 30, default: 30 })
  @IsOptional() @Type(() => Number) @IsInt() @Min(30)
  durationMinutes?: number;

  @ApiPropertyOptional({ format: 'uuid', description: 'Required for home visits' })
  @IsOptional() @IsUUID()
  addressId?: string;

  @ApiPropertyOptional({ example: 'Lower back pain' })
  @IsOptional() @IsString() @MaxLength(200)
  problem?: string;

  @ApiPropertyOptional({ example: 'Pain increases while sitting for long hours' })
  @IsOptional() @IsString() @MaxLength(1000)
  notes?: string;

  @ApiPropertyOptional({ example: 'TOC30' })
  @IsOptional() @IsString() @MaxLength(30)
  couponCode?: string;
}

export class ListAppointmentsDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: AppointmentStatus })
  @IsOptional() @IsEnum(AppointmentStatus)
  status?: AppointmentStatus;

  @ApiPropertyOptional({ enum: AppointmentType })
  @IsOptional() @IsEnum(AppointmentType)
  type?: AppointmentType;

  @ApiPropertyOptional({ example: '2026-08-01' })
  @IsOptional() @IsDateString()
  fromDate?: string;

  @ApiPropertyOptional({ example: '2026-08-31' })
  @IsOptional() @IsDateString()
  toDate?: string;
}

export class RejectAppointmentDto {
  @ApiProperty({ example: 'Not available at this time' })
  @IsString() @MaxLength(300)
  reason: string;
}

export class CancelAppointmentDto {
  @ApiProperty({ example: 'Personal emergency' })
  @IsString() @MaxLength(300)
  reason: string;
}

export class RescheduleAppointmentDto {
  @ApiProperty({ example: '2026-08-20' })
  @IsDateString()
  scheduledDate: string;

  @ApiProperty({ example: '11:00' })
  @IsString() @Matches(TIME_PATTERN)
  startTime: string;
}
