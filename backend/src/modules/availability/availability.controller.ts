import { Body, Controller, Delete, Get, Param, Patch, Post, Put, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { AvailabilityService } from './availability.service';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateSlotDto, ReplaceScheduleDto, UpdateSlotDto } from './dto/availability.dto';

@ApiTags('Availability')
@Controller('availability')
export class AvailabilityController {
  constructor(private readonly availabilityService: AvailabilityService) {}

  @Public()
  @Get('therapist/:therapistId/slots')
  @ApiQuery({ name: 'date', example: '2026-08-15' })
  @ApiOperation({ summary: 'Free 30-minute slots for a therapist on a given date' })
  getFreeSlots(@Param('therapistId') therapistId: string, @Query('date') date: string) {
    return this.availabilityService.getFreeSlots(therapistId, date);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.THERAPIST)
  @Get('me')
  @ApiOperation({ summary: 'Get own weekly working windows' })
  listMine(@CurrentUser('sub') userId: string) {
    return this.availabilityService.listOwnSlots(userId);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.THERAPIST)
  @Post('me')
  @ApiOperation({ summary: 'Add a working window' })
  create(@CurrentUser('sub') userId: string, @Body() dto: CreateSlotDto) {
    return this.availabilityService.createSlot(userId, dto);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.THERAPIST)
  @Put('me')
  @ApiOperation({ summary: 'Replace the entire weekly schedule in one call' })
  replace(@CurrentUser('sub') userId: string, @Body() dto: ReplaceScheduleDto) {
    return this.availabilityService.replaceWeeklySchedule(userId, dto.slots);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.THERAPIST)
  @Patch('me/:slotId')
  @ApiOperation({ summary: 'Edit a working window' })
  update(
    @CurrentUser('sub') userId: string,
    @Param('slotId') slotId: string,
    @Body() dto: UpdateSlotDto,
  ) {
    return this.availabilityService.updateSlot(userId, slotId, dto);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.THERAPIST)
  @Delete('me/:slotId')
  @ApiOperation({ summary: 'Delete a working window' })
  remove(@CurrentUser('sub') userId: string, @Param('slotId') slotId: string) {
    return this.availabilityService.deleteSlot(userId, slotId);
  }
}
