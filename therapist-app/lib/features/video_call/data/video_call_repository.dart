import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';

/// Short-lived Agora credentials scoped to one appointment's channel.
class AgoraCredentials {
  const AgoraCredentials({
    required this.appId,
    required this.channelName,
    required this.token,
    required this.uid,
    required this.expiresAt,
  });

  final String appId;
  final String channelName;
  final String token;
  final int uid;
  final int expiresAt;

  factory AgoraCredentials.fromJson(Map<String, dynamic> json) =>
      AgoraCredentials(
        appId: json['appId'] as String,
        channelName: json['channelName'] as String,
        token: json['token'] as String,
        uid: json['uid'] as int,
        expiresAt: json['expiresAt'] as int? ?? 0,
      );
}

class VideoCallRepository {
  VideoCallRepository(this._api);

  final ApiClient _api;

  Future<AgoraCredentials> join(String appointmentId) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiRoutes.joinCall(appointmentId),
    );

    return AgoraCredentials.fromJson(data);
  }

  Future<AgoraCredentials> renewToken(String appointmentId) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/video-call/$appointmentId/renew-token',
    );

    return AgoraCredentials.fromJson({
      // The renew endpoint omits appId since the engine already has it
      'appId': AppConfig.agoraAppId,
      ...data,
    });
  }

  Future<void> end(String appointmentId) =>
      _api.post(ApiRoutes.endCall(appointmentId));
}

final videoCallRepositoryProvider = Provider<VideoCallRepository>((ref) {
  return VideoCallRepository(ref.watch(apiClientProvider));
});
