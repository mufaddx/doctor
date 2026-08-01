import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsString, MaxLength } from 'class-validator';

export class ApplyReferralDto {
  @ApiProperty({ example: 'TOC100' })
  @IsString() @MaxLength(40)
  referralCode: string;
}

export class EarningsPeriodDto {
  @ApiProperty({ enum: ['daily', 'weekly', 'monthly', 'yearly'], default: 'daily' })
  @IsIn(['daily', 'weekly', 'monthly', 'yearly'])
  period: 'daily' | 'weekly' | 'monthly' | 'yearly';
}
