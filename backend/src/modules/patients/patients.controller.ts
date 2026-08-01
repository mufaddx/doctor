import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { PatientsService } from './patients.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateAddressDto, UpdateAddressDto } from './dto/patient.dto';

@ApiTags('Patients')
@ApiBearerAuth('access-token')
@Controller('patients')
export class PatientsController {
  constructor(private readonly patientsService: PatientsService) {}

  @Roles(UserRole.PATIENT)
  @Get('me/addresses')
  @ApiOperation({ summary: 'List saved addresses' })
  listAddresses(@CurrentUser('sub') userId: string) {
    return this.patientsService.listAddresses(userId);
  }

  @Roles(UserRole.PATIENT)
  @Post('me/addresses')
  @ApiOperation({ summary: 'Add a new address' })
  createAddress(@CurrentUser('sub') userId: string, @Body() dto: CreateAddressDto) {
    return this.patientsService.createAddress(userId, dto);
  }

  @Roles(UserRole.PATIENT)
  @Patch('me/addresses/:addressId')
  @ApiOperation({ summary: 'Update an address' })
  updateAddress(
    @CurrentUser('sub') userId: string,
    @Param('addressId') addressId: string,
    @Body() dto: UpdateAddressDto,
  ) {
    return this.patientsService.updateAddress(userId, addressId, dto);
  }

  @Roles(UserRole.PATIENT)
  @Delete('me/addresses/:addressId')
  @ApiOperation({ summary: 'Delete an address' })
  deleteAddress(@CurrentUser('sub') userId: string, @Param('addressId') addressId: string) {
    return this.patientsService.deleteAddress(userId, addressId);
  }

  @Roles(UserRole.PATIENT)
  @Get('me/referral')
  @ApiOperation({ summary: 'Referral code and earnings summary' })
  referral(@CurrentUser('sub') userId: string) {
    return this.patientsService.getReferralInfo(userId);
  }

  @Roles(UserRole.THERAPIST)
  @Get('my-patients')
  @ApiOperation({ summary: 'Patients treated by the calling therapist' })
  myPatients(@CurrentUser('sub') userId: string, @Query('search') search?: string) {
    return this.patientsService.listTherapistPatients(userId, search);
  }

  @Roles(UserRole.THERAPIST)
  @Get(':patientId/history')
  @ApiOperation({ summary: 'Clinical history of one of your patients' })
  history(@CurrentUser('sub') userId: string, @Param('patientId') patientId: string) {
    return this.patientsService.getPatientHistoryForTherapist(userId, patientId);
  }
}
