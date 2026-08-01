import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { CouponType } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Min,
} from 'class-validator';

export class CreateCouponDto {
  @ApiProperty({ example: 'TOC30' })
  @IsString()
  @Matches(/^[A-Z0-9]{4,20}$/i, { message: 'Code must be 4-20 alphanumeric characters' })
  code: string;

  @ApiProperty({ enum: CouponType })
  @IsEnum(CouponType)
  type: CouponType;

  @ApiProperty({ example: 30, description: 'Percentage value or flat rupee amount' })
  @Type(() => Number) @IsNumber() @Min(1)
  value: number;

  @ApiPropertyOptional({ example: 150 })
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0)
  maxDiscount?: number;

  @ApiPropertyOptional({ example: 300 })
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0)
  minOrderValue?: number;

  @ApiPropertyOptional({ example: 1000 })
  @IsOptional() @Type(() => Number) @IsInt() @Min(1)
  usageLimit?: number;

  @ApiProperty({ example: '2026-08-01T00:00:00.000Z' })
  @IsDateString()
  validFrom: string;

  @ApiProperty({ example: '2026-12-31T23:59:59.000Z' })
  @IsDateString()
  validUntil: string;

  @ApiPropertyOptional({ default: true })
  @IsOptional() @IsBoolean()
  isActive?: boolean;
}

export class UpdateCouponDto {
  @ApiPropertyOptional()
  @IsOptional() @Type(() => Number) @IsNumber() @Min(1)
  value?: number;

  @ApiPropertyOptional()
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0)
  maxDiscount?: number;

  @ApiPropertyOptional()
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0)
  minOrderValue?: number;

  @ApiPropertyOptional()
  @IsOptional() @Type(() => Number) @IsInt() @Min(1)
  usageLimit?: number;

  @ApiPropertyOptional()
  @IsOptional() @IsDateString()
  validFrom?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsDateString()
  validUntil?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsBoolean()
  isActive?: boolean;
}

export class ApplyCouponDto {
  @ApiProperty({ example: 'TOC30' })
  @IsString()
  code: string;

  @ApiProperty({ example: 520, description: 'Order amount before discount' })
  @Type(() => Number) @IsNumber() @Min(0)
  amount: number;
}
