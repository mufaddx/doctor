import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { ReviewsService } from './reviews.service';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PaginationQueryDto } from '../../common/utils/pagination.util';
import { CreateReviewDto, UpdateReviewDto } from './dto/review.dto';

@ApiTags('Reviews')
@Controller('reviews')
export class ReviewsController {
  constructor(private readonly reviewsService: ReviewsService) {}

  @Public()
  @Get('therapist/:therapistId')
  @ApiOperation({ summary: 'Reviews for a therapist with a rating histogram' })
  byTherapist(
    @Param('therapistId') therapistId: string,
    @Query() query: PaginationQueryDto,
  ) {
    return this.reviewsService.findByTherapist(therapistId, query);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.PATIENT)
  @Get('pending')
  @ApiOperation({ summary: 'Completed appointments still awaiting a review' })
  pending(@CurrentUser('sub') userId: string) {
    return this.reviewsService.getPendingReviews(userId);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.PATIENT)
  @Post()
  @ApiOperation({ summary: 'Rate a completed appointment' })
  create(@CurrentUser('sub') userId: string, @Body() dto: CreateReviewDto) {
    return this.reviewsService.create(userId, dto);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.PATIENT)
  @Patch(':id')
  @ApiOperation({ summary: 'Edit your own review' })
  update(
    @CurrentUser('sub') userId: string,
    @Param('id') id: string,
    @Body() dto: UpdateReviewDto,
  ) {
    return this.reviewsService.update(userId, id, dto);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.PATIENT)
  @Delete(':id')
  @ApiOperation({ summary: 'Delete your own review' })
  remove(@CurrentUser('sub') userId: string, @Param('id') id: string) {
    return this.reviewsService.remove(userId, id);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @Get()
  @ApiOperation({ summary: 'All reviews for moderation (admin)' })
  findAll(@Query() query: PaginationQueryDto) {
    return this.reviewsService.findAllForAdmin(query);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @Delete(':id/moderate')
  @ApiOperation({ summary: 'Remove an abusive review (admin)' })
  moderate(@Param('id') id: string) {
    return this.reviewsService.removeByAdmin(id);
  }
}
