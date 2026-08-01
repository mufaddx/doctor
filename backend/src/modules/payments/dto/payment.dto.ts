import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { PaymentMethod, PaymentStatus } from '@prisma/client';
import { Type } from 'class-transformer';
import { IsEnum, IsNumber, IsOptional, IsString, IsUUID, MaxLength, Min } from 'class-validator';
import { PaginationQueryDto } from '../../../common/utils/pagination.util';

export class CreateOrderDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  appointmentId: string;

  @ApiProperty({ enum: PaymentMethod, example: PaymentMethod.UPI })
  @IsEnum(PaymentMethod)
  method: PaymentMethod;
}

export class VerifyPaymentDto {
  @ApiProperty({ example: 'order_MkL9xyz123' })
  @IsString()
  razorpayOrderId: string;

  @ApiProperty({ example: 'pay_MkL9abc456' })
  @IsString()
  razorpayPaymentId: string;

  @ApiProperty()
  @IsString()
  razorpaySignature: string;
}

export class RefundRequestDto {
  @ApiPropertyOptional({ description: 'Defaults to the full captured amount' })
  @IsOptional() @Type(() => Number) @IsNumber() @Min(1)
  amount?: number;

  @ApiPropertyOptional({ example: 'Appointment cancelled by therapist' })
  @IsOptional() @IsString() @MaxLength(300)
  reason?: string;
}

export class ListPaymentsDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: PaymentStatus })
  @IsOptional() @IsEnum(PaymentStatus)
  status?: PaymentStatus;
}
