import { Controller, Get, Param, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { VideoCallService } from './video-call.service';
import { CurrentUser, JwtPayload } from '../../common/decorators/current-user.decorator';

@ApiTags('Video Call')
@ApiBearerAuth('access-token')
@Controller('video-call')
export class VideoCallController {
  constructor(private readonly videoCallService: VideoCallService) {}

  @Post(':appointmentId/join')
  @ApiOperation({ summary: 'Get an Agora token and join the consultation room' })
  join(@CurrentUser() user: JwtPayload, @Param('appointmentId') appointmentId: string) {
    return this.videoCallService.joinSession(user.sub, user.role, appointmentId);
  }

  @Post(':appointmentId/renew-token')
  @ApiOperation({ summary: 'Renew an expiring Agora token' })
  renew(@CurrentUser('sub') userId: string, @Param('appointmentId') appointmentId: string) {
    return this.videoCallService.renewToken(userId, appointmentId);
  }

  @Post(':appointmentId/end')
  @ApiOperation({ summary: 'End the consultation and record its duration' })
  end(@CurrentUser('sub') userId: string, @Param('appointmentId') appointmentId: string) {
    return this.videoCallService.endSession(userId, appointmentId);
  }

  @Get(':appointmentId')
  @ApiOperation({ summary: 'Video session metadata for an appointment' })
  getSession(@CurrentUser('sub') userId: string, @Param('appointmentId') appointmentId: string) {
    return this.videoCallService.getSession(userId, appointmentId);
  }
}
