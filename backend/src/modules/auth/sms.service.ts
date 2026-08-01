import { HttpException, HttpStatus, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * SMS delivery via MSG91 (widely used for Indian transactional OTP traffic).
 * In non-production environments the code is logged instead of sent so that
 * developers can test the flow without burning SMS credits.
 */
@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);

  constructor(private readonly config: ConfigService) {}

  async sendOtp(phoneWithCode: string, code: string): Promise<void> {
    await this.dispatch(
      phoneWithCode,
      code,
      this.config.get<string>('MSG91_OTP_TEMPLATE_ID', ''),
    );
  }

  async sendPasswordResetOtp(phoneWithCode: string, code: string): Promise<void> {
    await this.dispatch(
      phoneWithCode,
      code,
      this.config.get<string>('MSG91_RESET_TEMPLATE_ID', ''),
    );
  }

  private async dispatch(phone: string, code: string, templateId: string): Promise<void> {
    const authKey = this.config.get<string>('MSG91_AUTH_KEY');

    if (!authKey || this.config.get('NODE_ENV') !== 'production') {
      this.logger.warn(`[DEV SMS] OTP for ${phone} is ${code}`);
      return;
    }

    const response = await fetch('https://control.msg91.com/api/v5/otp', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', authkey: authKey },
      body: JSON.stringify({
        template_id: templateId,
        mobile: phone.replace('+', ''),
        otp: code,
        otp_expiry: 5,
      }),
    });

    if (!response.ok) {
      this.logger.error(`SMS dispatch failed: ${response.status} ${await response.text()}`);
      throw new HttpException(
        'Unable to send OTP right now. Please try again.',
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }
  }
}
