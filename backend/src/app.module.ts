import { Module } from '@nestjs/common';
import { APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { CacheModule } from '@nestjs/cache-manager';
import { redisStore } from 'cache-manager-ioredis-yet';

import { validateEnv } from './config/env.validation';
import { PrismaModule } from './database/prisma.module';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { AuditLogInterceptor } from './common/interceptors/audit-log.interceptor';

import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { PatientsModule } from './modules/patients/patients.module';
import { TherapistsModule } from './modules/therapists/therapists.module';
import { AvailabilityModule } from './modules/availability/availability.module';
import { AppointmentsModule } from './modules/appointments/appointments.module';
import { CouponsModule } from './modules/coupons/coupons.module';
import { WalletModule } from './modules/wallet/wallet.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { ChatModule } from './modules/chat/chat.module';
import { VideoCallModule } from './modules/video-call/video-call.module';
import { PrescriptionsModule } from './modules/prescriptions/prescriptions.module';
import { ExercisesModule } from './modules/exercises/exercises.module';
import { ProgressModule } from './modules/progress/progress.module';
import { ReviewsModule } from './modules/reviews/reviews.module';
import { AdminModule } from './modules/admin/admin.module';
import { HealthModule } from './modules/health/health.module';
import { UploadsModule } from './modules/uploads/uploads.module';
import { NotificationsModule } from './modules/notifications/notifications.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: validateEnv,
      envFilePath: ['.env.local', '.env'],
    }),

    ScheduleModule.forRoot(),

    // Redis-backed cache used for therapist search results and slot lookups
    CacheModule.registerAsync({
      isGlobal: true,
      inject: [ConfigService],
      useFactory: async (config: ConfigService) => ({
        store: await redisStore({
          host: config.get<string>('REDIS_HOST', 'localhost'),
          port: config.get<number>('REDIS_PORT', 6379),
          password: config.get<string>('REDIS_PASSWORD') || undefined,
          ttl: 60_000,
        }),
      }),
    }),

    // Global baseline rate limiting; individual routes tighten this with @Throttle
    ThrottlerModule.forRoot([{ name: 'default', ttl: 60_000, limit: 100 }]),

    PrismaModule,
    NotificationsModule,
    UploadsModule,
    AuthModule,
    UsersModule,
    PatientsModule,
    TherapistsModule,
    AvailabilityModule,
    CouponsModule,
    AppointmentsModule,
    WalletModule,
    PaymentsModule,
    ChatModule,
    VideoCallModule,
    PrescriptionsModule,
    ExercisesModule,
    ProgressModule,
    ReviewsModule,
    AdminModule,
    HealthModule,
  ],
  providers: [
    // Order matters: authenticate, then authorise, then throttle
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_INTERCEPTOR, useClass: AuditLogInterceptor },
  ],
})
export class AppModule {}
