import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  ValidateNested,
} from 'class-validator';

export class MedicineDto {
  @ApiProperty({ example: 'Dolo 650' })
  @IsString() @MaxLength(120)
  name: string;

  @ApiProperty({ example: '1-0-1', description: 'Morning-Afternoon-Night pattern' })
  @IsString() @MaxLength(40)
  dosage: string;

  @ApiPropertyOptional({ example: 'After meals, 5 days' })
  @IsOptional() @IsString() @MaxLength(120)
  frequency?: string;
}

export class CreatePrescriptionDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  appointmentId: string;

  @ApiProperty({ example: 'Lumbar Muscle Strain' })
  @IsString() @MaxLength(300)
  diagnosis: string;

  @ApiPropertyOptional({ example: 'Avoid heavy lifting and long sitting.' })
  @IsOptional() @IsString() @MaxLength(2000)
  advice?: string;

  @ApiProperty({ type: [MedicineDto] })
  @IsArray() @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => MedicineDto)
  medicines: MedicineDto[];
}

export class UpdatePrescriptionDto {
  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(300)
  diagnosis?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(2000)
  advice?: string;

  @ApiPropertyOptional({ type: [MedicineDto] })
  @IsOptional() @IsArray() @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => MedicineDto)
  medicines?: MedicineDto[];
}
