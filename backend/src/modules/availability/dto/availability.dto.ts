import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';

const TIME_PATTERN = /^([01]\d|2[0-3]):(00|30)$/;

export class CreateSlotDto {
  @ApiProperty({ example: 1, description: '0 = Sunday ... 6 = Saturday' })
  @Type(() => Number) @IsInt() @Min(0) @Max(6)
  dayOfWeek: number;

  @ApiProperty({ example: '09:00' })
  @IsString()
  @Matches(TIME_PATTERN, { message: 'startTime must be HH:mm on a 30-minute boundary' })
  startTime: string;

  @ApiProperty({ example: '13:00' })
  @IsString()
  @Matches(TIME_PATTERN, { message: 'endTime must be HH:mm on a 30-minute boundary' })
  endTime: string;
}

export class UpdateSlotDto {
  @ApiPropertyOptional({ example: '10:00' })
  @IsOptional() @IsString() @Matches(TIME_PATTERN)
  startTime?: string;

  @ApiPropertyOptional({ example: '14:00' })
  @IsOptional() @IsString() @Matches(TIME_PATTERN)
  endTime?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsBoolean()
  isActive?: boolean;
}

export class ReplaceScheduleDto {
  @ApiProperty({ type: [CreateSlotDto] })
  @IsArray() @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => CreateSlotDto)
  slots: CreateSlotDto[];
}
