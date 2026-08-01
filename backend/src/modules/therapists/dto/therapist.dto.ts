import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsLatitude,
  IsLongitude,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { PaginationQueryDto } from '../../../common/utils/pagination.util';

export class SearchTherapistsDto extends PaginationQueryDto {
  @ApiPropertyOptional({ type: [String], example: ['Back Pain', 'Sports Injury'] })
  @IsOptional()
  @Transform(({ value }) => (Array.isArray(value) ? value : [value]))
  @IsArray()
  @IsString({ each: true })
  specialization?: string[];

  @ApiPropertyOptional({ example: 4 })
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) @Max(5)
  minRating?: number;

  @ApiPropertyOptional({ example: 3, description: 'Minimum years of experience' })
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0)
  minExperience?: number;

  @ApiPropertyOptional({ example: 800, description: 'Maximum consultation fee' })
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0)
  maxFee?: number;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  isAvailable?: boolean;

  @ApiPropertyOptional({ example: 28.6139 })
  @IsOptional() @Type(() => Number) @IsLatitude()
  latitude?: number;

  @ApiPropertyOptional({ example: 77.209 })
  @IsOptional() @Type(() => Number) @IsLongitude()
  longitude?: number;

  @ApiPropertyOptional({ example: 10, description: 'Search radius in km' })
  @IsOptional() @Type(() => Number) @IsNumber() @Min(1) @Max(200)
  radiusKm?: number;
}

export class UpdateTherapistProfileDto {
  @ApiPropertyOptional({ type: [String] })
  @IsOptional() @IsArray() @ArrayMaxSize(10) @IsString({ each: true })
  specialization?: string[];

  @ApiPropertyOptional({ example: 5 })
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) @Max(60)
  experienceYears?: number;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(1500)
  bio?: string;

  @ApiPropertyOptional({ example: 500 })
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0)
  clinicFee?: number;

  @ApiPropertyOptional({ example: 700 })
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0)
  homeVisitFee?: number;

  @ApiPropertyOptional({ example: 500 })
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0)
  videoFee?: number;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(300)
  clinicAddress?: string;

  @ApiPropertyOptional()
  @IsOptional() @Type(() => Number) @IsLatitude()
  latitude?: number;

  @ApiPropertyOptional()
  @IsOptional() @Type(() => Number) @IsLongitude()
  longitude?: number;
}

export class ToggleAvailabilityDto {
  @ApiProperty()
  @IsBoolean()
  isAvailable: boolean;
}

export class UpdateBankDetailDto {
  @ApiProperty({ example: 'Rahul Mehta' })
  @IsString() @MaxLength(100)
  accountHolder: string;

  @ApiProperty({ example: '123456789012' })
  @IsString()
  @Matches(/^\d{9,18}$/, { message: 'Account number must be 9-18 digits' })
  accountNumber: string;

  @ApiProperty({ example: 'HDFC0001234' })
  @IsString()
  @Matches(/^[A-Z]{4}0[A-Z0-9]{6}$/, { message: 'Enter a valid IFSC code' })
  ifscCode: string;

  @ApiProperty({ example: 'HDFC Bank' })
  @IsString() @MaxLength(100)
  bankName: string;

  @ApiPropertyOptional({ example: 'rahul@okhdfcbank' })
  @IsOptional() @IsString()
  upiId?: string;
}

export class UploadCertificateDto {
  @ApiProperty({ example: 'BPT Degree - Delhi University' })
  @IsString() @MaxLength(150)
  title: string;
}
