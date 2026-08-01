import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { CouponsService } from './coupons.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PaginationQueryDto } from '../../common/utils/pagination.util';
import { ApplyCouponDto, CreateCouponDto, UpdateCouponDto } from './dto/coupon.dto';

@ApiTags('Coupons')
@ApiBearerAuth('access-token')
@Controller('coupons')
export class CouponsController {
  constructor(private readonly couponsService: CouponsService) {}

  @Roles(UserRole.PATIENT)
  @Get('available')
  @ApiOperation({ summary: 'Coupons the patient can still use' })
  available(@CurrentUser('sub') userId: string) {
    return this.couponsService.listAvailable(userId);
  }

  @Roles(UserRole.PATIENT)
  @Post('apply')
  @ApiOperation({ summary: 'Preview the discount for a coupon and order amount' })
  apply(@CurrentUser('sub') userId: string, @Body() dto: ApplyCouponDto) {
    return this.couponsService.previewForUser(userId, dto.code, dto.amount);
  }

  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @Get()
  @ApiOperation({ summary: 'List all coupons (admin)' })
  findAll(@Query() query: PaginationQueryDto) {
    return this.couponsService.findAll(query);
  }

  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @Post()
  @ApiOperation({ summary: 'Create a coupon (admin)' })
  create(@Body() dto: CreateCouponDto) {
    return this.couponsService.create(dto);
  }

  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @Patch(':id')
  @ApiOperation({ summary: 'Update a coupon (admin)' })
  update(@Param('id') id: string, @Body() dto: UpdateCouponDto) {
    return this.couponsService.update(id, dto);
  }

  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @Delete(':id')
  @ApiOperation({ summary: 'Deactivate a coupon (admin)' })
  remove(@Param('id') id: string) {
    return this.couponsService.remove(id);
  }
}
