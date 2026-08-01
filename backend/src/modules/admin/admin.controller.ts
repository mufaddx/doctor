import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { AdminService } from './admin.service';
import { AnalyticsService } from './analytics.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { PaginationQueryDto } from '../../common/utils/pagination.util';
import {
  AnalyticsRangeDto,
  BroadcastNotificationDto,
  CreateBannerDto,
  CreateBlogDto,
  CreateFaqDto,
  KycDecisionDto,
  ListKycDto,
  ListTicketsDto,
  ListUsersDto,
  ProcessPayoutDto,
  SetUserActiveDto,
  UpdateTicketDto,
} from './dto/admin.dto';

@ApiTags('Admin')
@ApiBearerAuth('access-token')
@Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
@Controller('admin')
export class AdminController {
  constructor(
    private readonly adminService: AdminService,
    private readonly analyticsService: AnalyticsService,
  ) {}

  // ---------------- Dashboard ----------------

  @Get('dashboard/stats')
  @ApiOperation({ summary: 'Top KPI cards with month-over-month change' })
  stats() {
    return this.analyticsService.getDashboardStats();
  }

  @Get('dashboard/secondary-stats')
  @ApiOperation({ summary: 'Pending payments, unpaid bookings, leave, active offers' })
  secondaryStats() {
    return this.analyticsService.getSecondaryStats();
  }

  @Get('dashboard/appointments-overview')
  @ApiOperation({ summary: 'Monthly appointments split by outcome' })
  appointmentsOverview(@Query('months') months = 6) {
    return this.analyticsService.getAppointmentsOverview(Number(months));
  }

  @Get('dashboard/revenue-overview')
  @ApiOperation({ summary: 'Monthly captured revenue' })
  revenueOverview(@Query('months') months = 6) {
    return this.analyticsService.getRevenueOverview(Number(months));
  }

  @Get('dashboard/appointments-by-type')
  @ApiOperation({ summary: 'Share of bookings by appointment type' })
  byType() {
    return this.analyticsService.getAppointmentsByType();
  }

  @Get('dashboard/top-therapists')
  @ApiOperation({ summary: 'Top therapists leaderboard' })
  topTherapists(@Query('limit') limit = 5) {
    return this.analyticsService.getTopTherapists(Number(limit));
  }

  @Get('dashboard/latest-appointments')
  @ApiOperation({ summary: 'Most recent bookings' })
  latestAppointments(@Query('limit') limit = 5) {
    return this.analyticsService.getLatestAppointments(Number(limit));
  }

  @Get('dashboard/recent-reviews')
  @ApiOperation({ summary: 'Most recent reviews' })
  recentReviews(@Query('limit') limit = 5) {
    return this.analyticsService.getRecentReviews(Number(limit));
  }

  @Get('dashboard/pending-counts')
  @ApiOperation({ summary: 'Sidebar badge counts' })
  pendingCounts() {
    return this.analyticsService.getPendingCounts();
  }

  // ---------------- Reports ----------------

  @Get('reports/revenue')
  @ApiOperation({ summary: 'Revenue report for a date range, net of refunds' })
  revenueReport(@Query() dto: AnalyticsRangeDto) {
    return this.analyticsService.getRevenueReport(dto);
  }

  @Get('reports/growth')
  @ApiOperation({ summary: 'Monthly signup and booking growth' })
  growthReport(@Query('months') months = 12) {
    return this.analyticsService.getGrowthReport(Number(months));
  }

  // ---------------- Users ----------------

  @Get('users')
  @ApiOperation({ summary: 'List users with role and status filters' })
  listUsers(@Query() query: ListUsersDto) {
    return this.adminService.listUsers(query);
  }

  @Get('users/:id')
  @ApiOperation({ summary: 'Full user detail with role profile' })
  userDetail(@Param('id') id: string) {
    return this.adminService.getUserDetail(id);
  }

  @Patch('users/:id/status')
  @ApiOperation({ summary: 'Activate or deactivate a user account' })
  setUserActive(@Param('id') id: string, @Body() dto: SetUserActiveDto) {
    return this.adminService.setUserActive(id, dto.isActive);
  }

  // ---------------- KYC ----------------

  @Get('kyc')
  @ApiOperation({ summary: 'Therapist verification queue' })
  kycQueue(@Query() query: ListKycDto) {
    return this.adminService.listKycQueue(query);
  }

  @Patch('kyc/:therapistId')
  @ApiOperation({ summary: 'Approve or reject a therapist verification' })
  decideKyc(@Param('therapistId') therapistId: string, @Body() dto: KycDecisionDto) {
    return this.adminService.decideKyc(therapistId, dto);
  }

  // ---------------- Payouts ----------------

  @Get('payouts/pending')
  @ApiOperation({ summary: 'Amount owed to each therapist' })
  pendingPayouts() {
    return this.adminService.getPendingPayouts();
  }

  @Get('payouts')
  @ApiOperation({ summary: 'Payout history' })
  listPayouts(@Query() query: PaginationQueryDto) {
    return this.adminService.listPayouts(query);
  }

  @Post('payouts')
  @ApiOperation({ summary: 'Record a payout to a therapist' })
  createPayout(@Body() dto: ProcessPayoutDto) {
    return this.adminService.createPayout(dto);
  }

  // ---------------- Notifications ----------------

  @Post('notifications/broadcast')
  @ApiOperation({ summary: 'Push a notification to an audience segment' })
  broadcast(@Body() dto: BroadcastNotificationDto) {
    return this.adminService.broadcast(dto);
  }

  // ---------------- CMS ----------------

  @Get('banners')
  @ApiOperation({ summary: 'List banners' })
  listBanners() {
    return this.adminService.listBanners();
  }

  @Post('banners')
  @ApiOperation({ summary: 'Create a banner' })
  createBanner(@Body() dto: CreateBannerDto) {
    return this.adminService.createBanner(dto);
  }

  @Patch('banners/:id')
  @ApiOperation({ summary: 'Update a banner' })
  updateBanner(@Param('id') id: string, @Body() dto: CreateBannerDto) {
    return this.adminService.updateBanner(id, dto);
  }

  @Delete('banners/:id')
  @ApiOperation({ summary: 'Delete a banner' })
  deleteBanner(@Param('id') id: string) {
    return this.adminService.deleteBanner(id);
  }

  @Get('blogs')
  @ApiOperation({ summary: 'List blogs' })
  listBlogs(@Query() query: PaginationQueryDto) {
    return this.adminService.listBlogs(query);
  }

  @Post('blogs')
  @ApiOperation({ summary: 'Create a blog post' })
  createBlog(@Body() dto: CreateBlogDto) {
    return this.adminService.createBlog(dto);
  }

  @Patch('blogs/:id')
  @ApiOperation({ summary: 'Update a blog post' })
  updateBlog(@Param('id') id: string, @Body() dto: CreateBlogDto) {
    return this.adminService.updateBlog(id, dto);
  }

  @Delete('blogs/:id')
  @ApiOperation({ summary: 'Delete a blog post' })
  deleteBlog(@Param('id') id: string) {
    return this.adminService.deleteBlog(id);
  }

  @Get('faqs')
  @ApiOperation({ summary: 'List FAQs' })
  listFaqs(@Query('category') category?: string) {
    return this.adminService.listFaqs(category);
  }

  @Post('faqs')
  @ApiOperation({ summary: 'Create an FAQ' })
  createFaq(@Body() dto: CreateFaqDto) {
    return this.adminService.createFaq(dto);
  }

  @Patch('faqs/:id')
  @ApiOperation({ summary: 'Update an FAQ' })
  updateFaq(@Param('id') id: string, @Body() dto: CreateFaqDto) {
    return this.adminService.updateFaq(id, dto);
  }

  @Delete('faqs/:id')
  @ApiOperation({ summary: 'Delete an FAQ' })
  deleteFaq(@Param('id') id: string) {
    return this.adminService.deleteFaq(id);
  }

  // ---------------- Support ----------------

  @Get('tickets')
  @ApiOperation({ summary: 'Support ticket queue' })
  listTickets(@Query() query: ListTicketsDto) {
    return this.adminService.listTickets(query);
  }

  @Patch('tickets/:id')
  @ApiOperation({ summary: 'Change a ticket status' })
  updateTicket(@Param('id') id: string, @Body() dto: UpdateTicketDto) {
    return this.adminService.updateTicket(id, dto);
  }

  // ---------------- Audit ----------------

  @Get('audit-logs')
  @ApiOperation({ summary: 'Audit trail of state-changing requests' })
  auditLogs(@Query() query: PaginationQueryDto) {
    return this.adminService.listAuditLogs(query);
  }
}
