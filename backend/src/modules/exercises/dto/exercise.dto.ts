import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUrl,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { PaginationQueryDto } from '../../../common/utils/pagination.util';

const LEVELS = ['Beginner', 'Intermediate', 'Advanced'];

export class ListExercisesDto extends PaginationQueryDto {
  @ApiPropertyOptional({ example: 'Back Pain' })
  @IsOptional() @IsString()
  category?: string;

  @ApiPropertyOptional({ enum: LEVELS })
  @IsOptional() @IsIn(LEVELS)
  level?: string;
}

export class CreateExerciseDto {
  @ApiProperty({ example: 'Lower Back Stretch' })
  @IsString() @MaxLength(150)
  title: string;

  @ApiProperty({ example: 'Back Pain' })
  @IsString() @MaxLength(60)
  category: string;

  @ApiProperty({ enum: LEVELS })
  @IsIn(LEVELS)
  level: string;

  @ApiProperty({ example: 10 })
  @Type(() => Number) @IsInt() @Min(1) @Max(180)
  durationMinutes: number;

  @ApiProperty({ description: 'URL returned by the video upload endpoint' })
  @IsUrl()
  videoUrl: string;

  @ApiPropertyOptional()
  @IsOptional() @IsUrl()
  thumbnailUrl?: string;

  @ApiPropertyOptional({
    type: [String],
    example: ['Lie down on your back.', 'Bend your knees.', 'Hold for 10 seconds.'],
  })
  @IsOptional() @IsArray() @ArrayMaxSize(20) @IsString({ each: true })
  instructions?: string[];
}

export class UpdateExerciseDto {
  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(150)
  title?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(60)
  category?: string;

  @ApiPropertyOptional({ enum: LEVELS })
  @IsOptional() @IsIn(LEVELS)
  level?: string;

  @ApiPropertyOptional()
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(180)
  durationMinutes?: number;

  @ApiPropertyOptional()
  @IsOptional() @IsUrl()
  videoUrl?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsUrl()
  thumbnailUrl?: string;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional() @IsArray() @ArrayMaxSize(20) @IsString({ each: true })
  instructions?: string[];
}

export class AssignedExerciseDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  exerciseId: string;

  @ApiPropertyOptional({ example: 3, default: 3 })
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(20)
  sets?: number;
}

export class AssignExercisesDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  patientId: string;

  @ApiProperty({ example: 'Back Pain' })
  @IsString() @MaxLength(60)
  condition: string;

  @ApiPropertyOptional({ example: 6, description: 'Current pain level 0-10' })
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) @Max(10)
  painLevel?: number;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(1000)
  notes?: string;

  @ApiProperty({ type: [AssignedExerciseDto] })
  @IsArray() @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => AssignedExerciseDto)
  exercises: AssignedExerciseDto[];
}
