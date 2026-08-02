import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../data/video_call_repository.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  const VideoCallScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  RtcEngine? _engine;

  bool _isInitialising = true;
  bool _isJoined = false;
  int? _remoteUid;

  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;

  String? _errorMessage;

  Timer? _durationTimer;
  Duration _callDuration = Duration.zero;

  @override
  void initState() {
    super.initState();

    // The call must stay visible, so the screen is kept awake and full-bleed
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startCall();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _releaseEngine();
    super.dispose();
  }

  Future<void> _startCall() async {
    try {
      // Camera and microphone must be granted before the engine initialises
      final statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      if (statuses[Permission.camera] != PermissionStatus.granted ||
          statuses[Permission.microphone] != PermissionStatus.granted) {
        setState(() {
          _isInitialising = false;
          _errorMessage =
              'Camera and microphone access are required for a video consultation.';
        });
        return;
      }

      final AgoraCredentials credentials = await ref
          .read(videoCallRepositoryProvider)
          .join(widget.appointmentId);

      final RtcEngine engine = createAgoraRtcEngine();
      await engine.initialize(
        RtcEngineContext(
          appId: credentials.appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (!mounted) return;
            setState(() {
              _isJoined = true;
              _isInitialising = false;
            });
            _startDurationTimer();
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!mounted) return;
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!mounted) return;
            setState(() => _remoteUid = null);
            AppSnackbar.info(context, 'The other participant left the call');
          },
          onError: (code, message) {
            if (!mounted) return;
            setState(() {
              _isInitialising = false;
              _errorMessage = 'Call error: $message';
            });
          },
          // Expiry is handled proactively so the call never drops mid-session
          onTokenPrivilegeWillExpire: (connection, token) => _renewToken(),
        ),
      );

      await engine.enableVideo();
      await engine.startPreview();
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await engine.setEnableSpeakerphone(true);

      await engine.joinChannel(
        token: credentials.token,
        channelId: credentials.channelName,
        uid: credentials.uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      _engine = engine;
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isInitialising = false;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isInitialising = false;
        _errorMessage = 'Could not start the video call. Please try again.';
      });
    }
  }

  Future<void> _renewToken() async {
    try {
      final credentials = await ref
          .read(videoCallRepositoryProvider)
          .renewToken(widget.appointmentId);
      await _engine?.renewToken(credentials.token);
    } catch (_) {
      // The call continues on the existing token until it actually expires
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _callDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _releaseEngine() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
  }

  Future<void> _toggleMute() async {
    await _engine?.muteLocalAudioStream(!_isMuted);
    setState(() => _isMuted = !_isMuted);
  }

  Future<void> _toggleCamera() async {
    await _engine?.muteLocalVideoStream(!_isCameraOff);
    setState(() => _isCameraOff = !_isCameraOff);
  }

  Future<void> _switchCamera() async => _engine?.switchCamera();

  Future<void> _toggleSpeaker() async {
    await _engine?.setEnableSpeakerphone(!_isSpeakerOn);
    setState(() => _isSpeakerOn = !_isSpeakerOn);
  }

  Future<void> _endCall() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End consultation?'),
        content: const Text('This will end the video call for both of you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End Call'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _releaseEngine();

    try {
      await ref.read(videoCallRepositoryProvider).end(widget.appointmentId);
    } catch (_) {
      // The local call is already over; a failed report is non-blocking
    }

    if (!mounted) return;
    context.pop();
  }

  String get _formattedDuration {
    final int minutes = _callDuration.inMinutes;
    final int seconds = _callDuration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Leaving via the system back gesture would strand the call, so it is
    // routed through the same confirmation as the end button.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _endCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _errorMessage != null ? _buildError() : _buildCall(),
      ),
    );
  }

  Widget _buildError() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              size: 56,
              color: Colors.white54,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: 'Go Back', onPressed: () => context.pop()),
            if (_errorMessage!.contains('access are required')) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Open Settings',
                variant: AppButtonVariant.outlined,
                onPressed: openAppSettings,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCall() {
    return Stack(
      children: [
        Positioned.fill(child: _buildRemoteVideo()),

        // Local preview floats above the remote feed
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          right: 12,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: SizedBox(
              width: 110,
              height: 150,
              child: _isCameraOff || _engine == null
                  ? Container(
                      color: Colors.grey.shade900,
                      child: const Icon(
                        Icons.videocam_off,
                        color: Colors.white54,
                      ),
                    )
                  : AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine!,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
            ),
          ),
        ),

        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isJoined ? _formattedDuration : 'Connecting...',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: 'Mute',
                    active: _isMuted,
                    onTap: _toggleMute,
                  ),
                  _ControlButton(
                    icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                    label: 'Camera',
                    active: _isCameraOff,
                    onTap: _toggleCamera,
                  ),
                  _ControlButton(
                    icon: Icons.call_end,
                    label: 'End',
                    background: AppColors.danger,
                    onTap: _endCall,
                  ),
                  _ControlButton(
                    icon: Icons.cameraswitch_outlined,
                    label: 'Switch',
                    onTap: _switchCamera,
                  ),
                  _ControlButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.hearing,
                    label: 'Speaker',
                    active: !_isSpeakerOn,
                    onTap: _toggleSpeaker,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemoteVideo() {
    if (_isInitialising) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: AppSpacing.md),
            Text(
              'Joining consultation...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_remoteUid == null || _engine == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline, size: 64, color: Colors.white38),
            SizedBox(height: AppSpacing.md),
            Text(
              'Waiting for the therapist to join...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine!,
        canvas: VideoCanvas(uid: _remoteUid),
        connection: const RtcConnection(),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.background,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: background ?? (active ? Colors.white : Colors.white24),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: background != null
                  ? Colors.white
                  : (active ? Colors.black87 : Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
