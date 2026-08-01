import { Body, Controller, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { AppointmentsService } from './appointments.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser, JwtPayload } from '../../common/decorators/current-user.decorator';
import {
  CancelAppointmentDto,
  CreateAppointmentDto,
  ListAppointmentsDto,
  RejectAppointmentDto,
  RescheduleAppointmentDto,
} from './dto/appointment.dto';

@ApiTags('Appointments')
@ApiBearerAuth('access-token')
@Controller('appointments')
export class AppointmentsController {
  constructor(private readonly appointmentsService: AppointmentsService) {}

  @Roles(UserRole.PATIENT)
  @Post()
  @ApiOperation({ summary: 'Book an appointment (clinic, home visit or video)' })
  create(@CurrentUser('sub') userId: string, @Body() dto: CreateAppointmentDto) {
    return this.appointmentsService.create(userId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List appointments for the caller with filters and pagination' })
  findAll(@CurrentUser() user: JwtPayload, @Query() query: ListAppointmentsDto) {
    return this.appointmentsService.findAll(user.sub, user.role, query);
  }

  @Roles(UserRole.THERAPIST)
  @Get('today')
  @ApiOperation({ summary: "Therapist's schedule for today" })
  today(@CurrentUser('sub') userId: string) {
    return this.appointmentsService.findTodaySchedule(userId);
  }

  @Roles(UserRole.THERAPIST)
  @Get('stats')
  @ApiOperation({ summary: 'Dashboard counters for the therapist app' })
  stats(@CurrentUser('sub') userId: string) {
    return this.appointmentsService.getTherapistStats(userId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Appointment detail' })
  findOne(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.appointmentsService.findOne(user.sub, user.role, id);
  }

  @Roles(UserRole.THERAPIST)
  @Patch(':id/accept')
  @ApiOperation({ summary: 'Accept a pending booking request' })
  accept(@CurrentUser('sub') userId: string, @Param('id') id: string) {
    return this.appointmentsService.accept(userId, id);
  }

  @Roles(UserRole.THERAPIST)
  @Patch(':id/reject')
  @ApiOperation({ summary: 'Reject a pending booking request' })
  reject(
    @CurrentUser('sub') userId: string,
    @Param('id') id: string,
    @Body() dto: RejectAppointmentDto,
  ) {
    return this.appointmentsService.reject(userId, id, dto);
  }

  @Patch(':id/cancel')
  @ApiOperation({ summary: 'Cancel an appointment (patient or therapist)' })
  cancel(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() dto: CancelAppointmentDto,
  ) {
    return this.appointmentsService.cancel(user.sub, user.role, id, dto);
  }

  @Roles(UserRole.PATIENT)
  @Patch(':id/reschedule')
  @ApiOperation({ summary: 'Move a booking to another available slot' })
  reschedule(
    @CurrentUser('sub') userId: string,
    @Param('id') id: string,
    @Body() dto: RescheduleAppointmentDto,
  ) {
    return this.appointmentsService.reschedule(userId, id, dto);
  }

  @Roles(UserRole.THERAPIST)
  @Patch(':id/start')
  @ApiOperation({ summary: 'Mark the session as started' })
  start(@CurrentUser('sub') userId: string, @Param('id') id: string) {
    return this.appointmentsService.start(userId, id);
  }

  @Roles(UserRole.THERAPIST)
  @Patch(':id/complete')
  @ApiOperation({ summary: 'Mark the session as completed' })
  complete(@CurrentUser('sub') userId: string, @Param('id') id: string) {
    return this.appointmentsService.complete(userId, id);
  }
}
