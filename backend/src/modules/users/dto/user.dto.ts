import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsDateString,
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

export class UpdateProfileDto {
  @ApiPropertyOptional({ example: 'Ankit Kumar' })
  @IsOptional() @IsString() @MinLength(2) @MaxLength(80)
  fullName?: string;

  @ApiPropertyOptional({ example: 'ankit@gmail.com' })
  @IsOptional() @IsEmail()
  email?: string;

  @ApiPropertyOptional({ example: '1995-05-12' })
  @IsOptional() @IsDateString()
  dateOfBirth?: string;

  @ApiPropertyOptional({ enum: ['Male', 'Female', 'Other'] })
  @IsOptional() @IsIn(['Male', 'Female', 'Other'])
  gender?: string;

  @ApiPropertyOptional({ example: 'Chronic lower back pain since 2022' })
  @IsOptional() @IsString() @MaxLength(2000)
  medicalHistory?: string;
}

export class ChangePasswordDto {
  @ApiProperty()
  @IsString()
  currentPassword: string;

  @ApiProperty({ example: 'StrongPass@123' })
  @IsString() @MinLength(8)
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$/, {
    message: 'Password must contain uppercase, lowercase and a number',
  })
  newPassword: string;
}

export class FcmTokenDto {
  @ApiProperty()
  @IsString()
  token: string;
}
