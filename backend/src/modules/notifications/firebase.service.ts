import { Injectable, Logger, OnModuleInit, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

/**
 * Thin wrapper around the Firebase Admin SDK. Handles app initialisation once
 * per process and exposes the two capabilities the platform needs:
 * ID-token verification (social login) and FCM push delivery.
 */
@Injectable()
export class FirebaseService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseService.name);
  private app: admin.app.App;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    if (admin.apps.length > 0) {
      this.app = admin.app();
      return;
    }

    this.app = admin.initializeApp({
      credential: admin.credential.cert({
        projectId: this.config.getOrThrow<string>('FIREBASE_PROJECT_ID'),
        clientEmail: this.config.getOrThrow<string>('FIREBASE_CLIENT_EMAIL'),
        // Private keys are stored with escaped newlines in .env
        privateKey: this.config
          .getOrThrow<string>('FIREBASE_PRIVATE_KEY')
          .replace(/\\n/g, '\n'),
      }),
      storageBucket: this.config.get<string>('FIREBASE_STORAGE_BUCKET'),
    });

    this.logger.log('Firebase Admin initialised');
  }

  async verifyIdToken(idToken: string): Promise<admin.auth.DecodedIdToken> {
    try {
      return await this.app.auth().verifyIdToken(idToken, true);
    } catch (error) {
      this.logger.warn(`ID token verification failed: ${(error as Error).message}`);
      throw new UnauthorizedException('Invalid or expired social login token');
    }
  }

  /**
   * Sends a data+notification push to multiple device tokens and returns the
   * tokens that are no longer valid so the caller can prune them.
   */
  async sendMulticast(
    tokens: string[],
    payload: { title: string; body: string; data?: Record<string, string> },
  ): Promise<{ successCount: number; invalidTokens: string[] }> {
    if (tokens.length === 0) return { successCount: 0, invalidTokens: [] };

    const response = await this.app.messaging().sendEachForMulticast({
      tokens,
      notification: { title: payload.title, body: payload.body },
      data: payload.data ?? {},
      android: { priority: 'high', notification: { channelId: 'touch_of_cure_default' } },
      apns: { payload: { aps: { sound: 'default', contentAvailable: true } } },
    });

    const invalidTokens: string[] = [];
    response.responses.forEach((res, index) => {
      const code = res.error?.code;
      if (
        code === 'messaging/invalid-registration-token' ||
        code === 'messaging/registration-token-not-registered'
      ) {
        invalidTokens.push(tokens[index]);
      }
    });

    return { successCount: response.successCount, invalidTokens };
  }

  getStorageBucket() {
    return this.app.storage().bucket();
  }
}
