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
import { TherapistsService } from './therapists.service';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import {
  SearchTherapistsDto,
  ToggleAvailabilityDto,
  UpdateBankDetailDto,
  UpdateTherapistProfileDto,
  UploadCertificateDto,
} from './dto/therapist.dto';

@ApiTags('Therapists')
@Controller('therapists')
export class TherapistsController {
  constructor(private readonly therapistsService: TherapistsService) {}

  // ---------- Public discovery ----------

  @Public()
  @Get()
  @ApiOperation({ summary: 'Search therapists with filters, sorting and pagination' })
  search(@Query() dto: SearchTherapistsDto) {
    return this.therapistsService.search(dto);
  }

  @Public()
  @Get('top-rated')
  @ApiOperation({ summary: 'Top rated therapists for the home screen' })
  topRated() {
    return this.therapistsService.findTopRated();
  }

  // ---------- Therapist self-service (must precede :id route) ----------

  @ApiBearerAuth('access-token')
  @Roles(UserRole.THERAPIST)
  @Patch('me')
  @ApiOperation({ summary: 'Update own therapist profile' })
  updateMe(@CurrentUser('sub') userId: string, @Body() dto: UpdateTherapistProfileDto) {
    return this.therapistsService.updateOwnProfile(userId, dto);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.THERAPIST)
  @Patch('me/availability-toggle')
  @ApiOperation({ summary: 'Turn accepting-new-bookings on or off' })
  toggleAvailability(
    @CurrentUser('sub') userId: string,
    @Body() dto: ToggleAvailabilityDto,
  ) {
    return this.therapistsService.toggleAvailability(userId, dto.isAvailable);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.THERAPIST)
  @Post('me/certificates')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } }))
  @ApiOperation({ summary: 'Upload a qualification certificate for KYC review' })
  uploadCertificate(
    @CurrentUser('sub') userId: string,
    @Body() dto: UploadCertificateDto,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.therapistsService.uploadCertificate(userId, dto.title, file);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.THERAPIST)
  @Delete('me/certificates/:certificateId')
  @ApiOperation({ summary: 'Delete one of your certificates' })
  deleteCertificate(
    @CurrentUser('sub') userId: string,
    @Param('certificateId') certificateId: string,
  ) {
    return this.therapistsService.deleteCertificate(userId, certificateId);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.THERAPIST)
  @Get('me/bank-details')
  @ApiOperation({ summary: 'Get saved payout bank details (account number masked)' })
  getBank(@CurrentUser('sub') userId: string) {
    return this.therapistsService.getBankDetail(userId);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.THERAPIST)
  @Post('me/bank-details')
  @ApiOperation({ summary: 'Create or update payout bank details' })
  upsertBank(@CurrentUser('sub') userId: string, @Body() dto: UpdateBankDetailDto) {
    return this.therapistsService.upsertBankDetail(userId, dto);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.THERAPIST)
  @Get('me/reviews')
  @ApiOperation({ summary: 'Paginated list of reviews received' })
  myReviews(
    @CurrentUser('sub') userId: string,
    @Query('page') page = 1,
    @Query('limit') limit = 20,
  ) {
    return this.therapistsService.getOwnReviews(userId, Number(page), Number(limit));
  }

  // ---------- Public detail (declared last so /me is not swallowed) ----------

  @Public()
  @Get(':id')
  @ApiOperation({ summary: 'Full public profile of a therapist' })
  findOne(@Param('id') id: string) {
    return this.therapistsService.findOne(id);
  }
}
