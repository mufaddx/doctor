import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { WalletService } from './wallet.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PaginationQueryDto } from '../../common/utils/pagination.util';
import { ApplyReferralDto } from './dto/wallet.dto';

@ApiTags('Wallet')
@ApiBearerAuth('access-token')
@Controller('wallet')
export class WalletController {
  constructor(private readonly walletService: WalletService) {}

  @Get('balance')
  @ApiOperation({ summary: 'Current wallet balance' })
  balance(@CurrentUser('sub') userId: string) {
    return this.walletService.getBalance(userId);
  }

  @Get('transactions')
  @ApiOperation({ summary: 'Paginated wallet transaction history' })
  transactions(@CurrentUser('sub') userId: string, @Query() query: PaginationQueryDto) {
    return this.walletService.getTransactions(userId, query);
  }

  @Roles(UserRole.PATIENT)
  @Post('referral/apply')
  @ApiOperation({ summary: "Apply someone else's referral code to your account" })
  async applyReferral(@CurrentUser('sub') userId: string, @Body() dto: ApplyReferralDto) {
    return this.walletService.applyReferralBonusForUser(userId, dto.referralCode);
  }

  @Roles(UserRole.THERAPIST)
  @Get('earnings')
  @ApiQuery({ name: 'period', enum: ['daily', 'weekly', 'monthly', 'yearly'] })
  @ApiOperation({ summary: 'Therapist earnings summary for a period' })
  earnings(
    @CurrentUser('sub') userId: string,
    @Query('period') period: 'daily' | 'weekly' | 'monthly' | 'yearly' = 'daily',
  ) {
    return this.walletService.getTherapistEarnings(userId, period);
  }

  @Roles(UserRole.THERAPIST)
  @Get('payouts')
  @ApiOperation({ summary: 'Therapist payout history' })
  payouts(@CurrentUser('sub') userId: string, @Query() query: PaginationQueryDto) {
    return this.walletService.getPayouts(userId, query);
  }
}
