import { Body, Controller, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { PrescriptionsService } from './prescriptions.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser, JwtPayload } from '../../common/decorators/current-user.decorator';
import { PaginationQueryDto } from '../../common/utils/pagination.util';
import { CreatePrescriptionDto, UpdatePrescriptionDto } from './dto/prescription.dto';

@ApiTags('Prescriptions')
@ApiBearerAuth('access-token')
@Controller('prescriptions')
export class PrescriptionsController {
  constructor(private readonly prescriptionsService: PrescriptionsService) {}

  @Roles(UserRole.THERAPIST)
  @Post()
  @ApiOperation({ summary: 'Issue a prescription and generate its PDF' })
  create(@CurrentUser('sub') userId: string, @Body() dto: CreatePrescriptionDto) {
    return this.prescriptionsService.create(userId, dto);
  }

  @Roles(UserRole.THERAPIST)
  @Patch(':id')
  @ApiOperation({ summary: 'Edit a prescription and regenerate its PDF' })
  update(
    @CurrentUser('sub') userId: string,
    @Param('id') id: string,
    @Body() dto: UpdatePrescriptionDto,
  ) {
    return this.prescriptionsService.update(userId, id, dto);
  }

  @Get()
  @ApiOperation({ summary: 'Prescriptions visible to the caller' })
  findAll(@CurrentUser() user: JwtPayload, @Query() query: PaginationQueryDto) {
    return this.prescriptionsService.findAllForUser(user.sub, user.role, query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Prescription detail including the PDF link' })
  findOne(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.prescriptionsService.findOne(user.sub, user.role, id);
  }
}
