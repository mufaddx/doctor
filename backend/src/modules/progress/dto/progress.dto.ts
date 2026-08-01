import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class CreateProgressLogDto {
  @ApiProperty({ example: 'Back Pain' })
  @IsString() @MaxLength(60)
  condition: string;

  @ApiProperty({ example: 6, description: 'Pain level from 0 (none) to 10 (severe)' })
  @Type(() => Number) @IsInt() @Min(0) @Max(10)
  painLevel: number;

  @ApiPropertyOptional({ example: 'Pain reduces after morning stretches' })
  @IsOptional() @IsString() @MaxLength(500)
  notes?: string;
}

export class ProgressChartQueryDto {
  @ApiPropertyOptional({ example: 'Back Pain' })
  @IsOptional() @IsString()
  condition?: string;

  @ApiPropertyOptional({ example: 30, default: 30, description: 'Look-back window in days' })
  @IsOptional() @Type(() => Number) @IsInt() @Min(7) @Max(365)
  days?: number;
}
