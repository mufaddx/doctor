import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AdminService } from './admin.service';
import { PrismaService } from '../../database/prisma.service';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PaginationQueryDto } from '../../common/utils/pagination.util';
import { CreateTicketDto } from './dto/admin.dto';

/**
 * Read-only CMS surface consumed by the mobile apps, plus ticket creation.
 * Kept separate from AdminController so it is not behind the admin role guard.
 */
@ApiTags('Content')
@Controller('content')
export class PublicContentController {
  constructor(
    private readonly adminService: AdminService,
    private readonly prisma: PrismaService,
  ) {}

  @Public()
  @Get('banners')
  @ApiOperation({ summary: 'Active home screen banners' })
  banners() {
    return this.adminService.listBanners(true);
  }

  @Public()
  @Get('blogs')
  @ApiOperation({ summary: 'Published blog posts' })
  blogs(@Query() query: PaginationQueryDto) {
    return this.adminService.listBlogs(query, true);
  }

  @Public()
  @Get('blogs/:slug')
  @ApiOperation({ summary: 'A published blog post by slug' })
  blog(@Param('slug') slug: string) {
    return this.adminService.getBlogBySlug(slug);
  }

  @Public()
  @Get('faqs')
  @ApiOperation({ summary: 'Help centre FAQs' })
  faqs(@Query('category') category?: string) {
    return this.adminService.listFaqs(category);
  }

  @ApiBearerAuth('access-token')
  @Post('tickets')
  @ApiOperation({ summary: 'Raise a support ticket' })
  createTicket(@CurrentUser('sub') userId: string, @Body() dto: CreateTicketDto) {
    return this.prisma.supportTicket.create({
      data: { userId, subject: dto.subject, message: dto.message },
    });
  }

  @ApiBearerAuth('access-token')
  @Get('tickets/mine')
  @ApiOperation({ summary: 'Your own support tickets' })
  myTickets(@CurrentUser('sub') userId: string) {
    return this.prisma.supportTicket.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }
}
