import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';

export class CreateAddressDto {
  @ApiProperty({ example: 'Home' })
  @IsString() @MaxLength(30)
  label: string;

  @ApiProperty({ example: '221B Baker Street' })
  @IsString() @MaxLength(150)
  line1: string;

  @ApiPropertyOptional({ example: 'Near Central Park' })
  @IsOptional() @IsString() @MaxLength(150)
  line2?: string;

  @ApiProperty({ example: 'Delhi' })
  @IsString() @MaxLength(60)
  city: string;

  @ApiProperty({ example: 'Delhi' })
  @IsString() @MaxLength(60)
  state: string;

  @ApiProperty({ example: '110001' })
  @IsString() @Matches(/^\d{6}$/, { message: 'Pincode must be 6 digits' })
  pincode: string;

  @ApiPropertyOptional({ example: 28.6139 })
  @IsOptional() @Type(() => Number) @IsLatitude()
  latitude?: number;

  @ApiPropertyOptional({ example: 77.209 })
  @IsOptional() @Type(() => Number) @IsLongitude()
  longitude?: number;

  @ApiPropertyOptional({ default: false })
  @IsOptional() @IsBoolean()
  isDefault?: boolean;
}

export class UpdateAddressDto {
  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(30)
  label?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(150)
  line1?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(150)
  line2?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(60)
  city?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(60)
  state?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @Matches(/^\d{6}$/)
  pincode?: string;

  @ApiPropertyOptional()
  @IsOptional() @Type(() => Number) @IsLatitude()
  latitude?: number;

  @ApiPropertyOptional()
  @IsOptional() @Type(() => Number) @IsLongitude()
  longitude?: number;

  @ApiPropertyOptional()
  @IsOptional() @IsBoolean()
  isDefault?: boolean;
}
