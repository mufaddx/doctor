import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  Timer? _timer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _startCountdown(ref.read(authProvider).otpExpiresIn ?? 30);

    // Autofocus after the first frame so the keyboard animation is smooth
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  /// The resend cooldown is capped at 30 seconds even when the OTP itself is
  /// valid for longer, because users expect a quick retry option.
  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _secondsRemaining = seconds.clamp(0, 30));

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _verify() async {
    final String otp = _pinController.text.trim();

    if (otp.length != 6) {
      AppSnackbar.error(context, 'Enter the complete 6-digit code');
      return;
    }

    FocusScope.of(context).unfocus();

    final bool verified = await ref.read(authProvider.notifier).verifyOtp(otp);

    if (!mounted) return;

    if (verified) {
      // The router redirect takes over from here once the status flips
      context.go(AppRoutes.home);
    } else {
      _pinController.clear();
      _pinFocusNode.requestFocus();

      final String? error = ref.read(authProvider).errorMessage;
      if (error != null) AppSnackbar.error(context, error);
    }
  }

  Future<void> _resend() async {
    final String? phone = ref.read(authProvider).pendingPhone;
    if (phone == null) {
      context.pop();
      return;
    }

    final bool sent = await ref.read(authProvider.notifier).sendOtp(phone);
    if (!mounted) return;

    if (sent) {
      _pinController.clear();
      _startCountdown(ref.read(authProvider).otpExpiresIn ?? 30);
      AppSnackbar.success(context, 'A new code has been sent');
    } else {
      final String? error = ref.read(authProvider).errorMessage;
      if (error != null) AppSnackbar.error(context, error);
    }
  }

  String get _formattedCountdown {
    final int minutes = _secondsRemaining ~/ 60;
    final int seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final PinTheme defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: theme.textTheme.titleLarge,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? AppColors.darkBorder
              : AppColors.lightBorder,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter OTP', style: theme.textTheme.displayLarge),
              const SizedBox(height: AppSpacing.sm),
              Text.rich(
                TextSpan(
                  style: theme.textTheme.bodySmall,
                  children: [
                    const TextSpan(text: 'We have sent a 6 digit code to\n'),
                    TextSpan(
                      text: '+91 ${auth.pendingPhone ?? ''}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              Pinput(
                length: 6,
                controller: _pinController,
                focusNode: _pinFocusNode,
                enabled: !auth.isSubmitting,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(color: scheme.primary, width: 1.6),
                  ),
                ),
                submittedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    color: scheme.primary.withValues(alpha: 0.08),
                    border: Border.all(color: scheme.primary),
                  ),
                ),
                errorPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(color: AppColors.danger),
                  ),
                ),
                onCompleted: (_) => _verify(),
              ),

              const SizedBox(height: AppSpacing.lg),

              Center(
                child: _secondsRemaining > 0
                    ? Text(
                        'Resend OTP in $_formattedCountdown',
                        style: theme.textTheme.bodySmall,
                      )
                    : TextButton(
                        onPressed: auth.isSubmitting ? null : _resend,
                        child: const Text('Resend OTP'),
                      ),
              ),

              const SizedBox(height: AppSpacing.lg),

              AppButton(
                label: 'Verify & Continue',
                isLoading: auth.isSubmitting,
                onPressed: _verify,
              ),

              const SizedBox(height: AppSpacing.md),

              Center(
                child: TextButton(
                  onPressed: auth.isSubmitting ? null : () => context.pop(),
                  child: const Text('Change mobile number'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
