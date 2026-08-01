import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { ExercisesService } from './exercises.service';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser, JwtPayload } from '../../common/decorators/current-user.decorator';
import {
  AssignExercisesDto,
  CreateExerciseDto,
  ListExercisesDto,
  UpdateExerciseDto,
} from './dto/exercise.dto';

@ApiTags('Exercises')
@Controller('exercises')
export class ExercisesController {
  constructor(private readonly exercisesService: ExercisesService) {}

  @Public()
  @Get()
  @ApiOperation({ summary: 'Browse the exercise library with filters' })
  findAll(@Query() query: ListExercisesDto) {
    return this.exercisesService.findAll(query);
  }

  @Public()
  @Get('categories')
  @ApiOperation({ summary: 'Available exercise categories' })
  categories() {
    return this.exercisesService.getCategories();
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.PATIENT)
  @Get('my-plan')
  @ApiOperation({ summary: 'The patient assigned exercise plan with progress summary' })
  myPlan(@CurrentUser('sub') userId: string) {
    return this.exercisesService.getMyPlan(userId);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.PATIENT)
  @Patch('assignments/:assignmentId/complete')
  @ApiOperation({ summary: 'Mark an assigned exercise as completed' })
  complete(@CurrentUser('sub') userId: string, @Param('assignmentId') assignmentId: string) {
    return this.exercisesService.markCompleted(userId, assignmentId);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.THERAPIST)
  @Post('assign')
  @ApiOperation({ summary: 'Assign an exercise plan to a patient' })
  assign(@CurrentUser('sub') userId: string, @Body() dto: AssignExercisesDto) {
    return this.exercisesService.assignToPatient(userId, dto);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.THERAPIST, UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @Post('upload/video')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 100 * 1024 * 1024 } }))
  @ApiOperation({ summary: 'Upload an exercise video (max 100 MB)' })
  uploadVideo(@UploadedFile() file: Express.Multer.File) {
    return this.exercisesService.uploadVideo(file);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.THERAPIST, UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @Post('upload/thumbnail')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  @ApiOperation({ summary: 'Upload an exercise thumbnail' })
  uploadThumbnail(@UploadedFile() file: Express.Multer.File) {
    return this.exercisesService.uploadThumbnail(file);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.THERAPIST, UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @Post()
  @ApiOperation({ summary: 'Create an exercise (global when created by an admin)' })
  create(@CurrentUser() user: JwtPayload, @Body() dto: CreateExerciseDto) {
    const therapistUserId = user.role === UserRole.THERAPIST ? user.sub : undefined;
    return this.exercisesService.create(dto, therapistUserId);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @Patch(':id')
  @ApiOperation({ summary: 'Update an exercise (admin)' })
  update(@Param('id') id: string, @Body() dto: UpdateExerciseDto) {
    return this.exercisesService.update(id, dto);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @Delete(':id')
  @ApiOperation({ summary: 'Delete an unassigned exercise (admin)' })
  remove(@Param('id') id: string) {
    return this.exercisesService.remove(id);
  }

  @Public()
  @Get(':id')
  @ApiOperation({ summary: 'Exercise detail with instructions' })
  findOne(@Param('id') id: string) {
    return this.exercisesService.findOne(id);
  }
}
