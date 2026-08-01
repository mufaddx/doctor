import { Global, Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { FirebaseService } from './firebase.service';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';

@Global()
@Module({
  imports: [ConfigModule],
  controllers: [NotificationsController],
  providers: [FirebaseService, NotificationsService],
  exports: [FirebaseService, NotificationsService],
})
export class NotificationsModule {}
