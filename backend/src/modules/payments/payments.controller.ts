import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { UserRole } from '@prisma/client';
import { Request } from 'express';
import { PaymentsService } from './payments.service';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import {
  CreateOrderDto,
  ListPaymentsDto,
  RefundRequestDto,
  VerifyPaymentDto,
} from './dto/payment.dto';

@ApiTags('Payments')
@Controller('payments')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @ApiBearerAuth('access-token')
  @Roles(UserRole.PATIENT)
  @Post('order')
  @ApiOperation({ summary: 'Create a Razorpay order (or settle instantly from wallet)' })
  createOrder(@CurrentUser('sub') userId: string, @Body() dto: CreateOrderDto) {
    return this.paymentsService.createOrder(userId, dto);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.PATIENT)
  @Post('verify')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify the checkout signature and mark the payment paid' })
  verify(@CurrentUser('sub') userId: string, @Body() dto: VerifyPaymentDto) {
    return this.paymentsService.verifyPayment(userId, dto);
  }

  @Public()
  @Post('webhook')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Razorpay server-to-server webhook' })
  webhook(
    @Req() req: Request & { rawBody?: Buffer },
    @Headers('x-razorpay-signature') signature: string,
  ) {
    // rawBody is preserved by the bodyParser verify hook in main.ts
    return this.paymentsService.handleWebhook(req.rawBody ?? Buffer.from(''), signature);
  }

  @ApiBearerAuth('access-token')
  @Get(':id')
  @ApiOperation({ summary: 'Payment detail for a participant of the appointment' })
  findOne(@CurrentUser('sub') userId: string, @Param('id') id: string) {
    return this.paymentsService.findOneForUser(userId, id);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @Get()
  @ApiOperation({ summary: 'All payments with filters (admin)' })
  findAll(@Query() query: ListPaymentsDto) {
    return this.paymentsService.findAllForAdmin(query);
  }

  @ApiBearerAuth('access-token')
  @Roles(UserRole.ADMIN, UserRole.SUPER_ADMIN)
  @Post(':id/refund')
  @ApiOperation({ summary: 'Issue a full or partial refund (admin)' })
  refund(@Param('id') id: string, @Body() dto: RefundRequestDto) {
    return this.paymentsService.refund(id, dto);
  }
}
