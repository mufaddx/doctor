import {
  Body,
  Controller,
  Delete,
  Get,
  Patch,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { UsersService } from './users.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ChangePasswordDto, FcmTokenDto, UpdateProfileDto } from './dto/user.dto';

@ApiTags('Users')
@ApiBearerAuth('access-token')
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get the authenticated user full profile' })
  getMe(@CurrentUser('sub') userId: string) {
    return this.usersService.getMe(userId);
  }

  @Patch('me')
  @ApiOperation({ summary: 'Update profile details' })
  updateProfile(@CurrentUser('sub') userId: string, @Body() dto: UpdateProfileDto) {
    return this.usersService.updateProfile(userId, dto);
  }

  @Post('me/avatar')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 5 * 1024 * 1024 } }))
  @ApiOperation({ summary: 'Upload or replace the profile photo (max 5 MB)' })
  updateAvatar(
    @CurrentUser('sub') userId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.usersService.updateAvatar(userId, file);
  }

  @Patch('me/password')
  @ApiOperation({ summary: 'Change password (revokes all sessions)' })
  changePassword(@CurrentUser('sub') userId: string, @Body() dto: ChangePasswordDto) {
    return this.usersService.changePassword(userId, dto);
  }

  @Post('me/fcm-token')
  @ApiOperation({ summary: 'Register a device token for push notifications' })
  registerFcm(@CurrentUser('sub') userId: string, @Body() dto: FcmTokenDto) {
    return this.usersService.registerFcmToken(userId, dto.token);
  }

  @Delete('me/fcm-token')
  @ApiOperation({ summary: 'Unregister a device token' })
  removeFcm(@CurrentUser('sub') userId: string, @Body() dto: FcmTokenDto) {
    return this.usersService.removeFcmToken(userId, dto.token);
  }

  @Delete('me')
  @ApiOperation({ summary: 'Deactivate the account' })
  deactivate(@CurrentUser('sub') userId: string) {
    return this.usersService.deactivateAccount(userId);
  }
}
