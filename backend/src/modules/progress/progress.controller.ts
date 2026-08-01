import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { ProgressService } from './progress.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreateProgressLogDto, ProgressChartQueryDto } from './dto/progress.dto';

@ApiTags('Progress')
@ApiBearerAuth('access-token')
@Controller('progress')
export class ProgressController {
  constructor(private readonly progressService: ProgressService) {}

  @Roles(UserRole.PATIENT)
  @Post()
  @ApiOperation({ summary: 'Log today pain level for a condition' })
  log(@CurrentUser('sub') userId: string, @Body() dto: CreateProgressLogDto) {
    return this.progressService.log(userId, dto);
  }

  @Roles(UserRole.PATIENT)
  @Get('chart')
  @ApiOperation({ summary: 'Pain-level time series with trend summary' })
  chart(@CurrentUser('sub') userId: string, @Query() query: ProgressChartQueryDto) {
    return this.progressService.getChart(userId, query);
  }

  @Roles(UserRole.PATIENT)
  @Get('conditions')
  @ApiOperation({ summary: 'Conditions the patient has logged' })
  conditions(@CurrentUser('sub') userId: string) {
    return this.progressService.getConditions(userId);
  }

  @Roles(UserRole.THERAPIST)
  @Get('patient/:patientId')
  @ApiOperation({ summary: 'Progress chart for one of your patients' })
  patientChart(
    @CurrentUser('sub') userId: string,
    @Param('patientId') patientId: string,
    @Query() query: ProgressChartQueryDto,
  ) {
    return this.progressService.getChartForTherapist(userId, patientId, query);
  }
}
