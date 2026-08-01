import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    // Dismiss the keyboard so the user sees the loading state on the button
    FocusScope.of(context).unfocus();

    final bool sent =
        await ref.read(authProvider.notifier).sendOtp(_phoneController.text.trim());

    if (!mounted) return;

    if (sent) {
      context.push(AppRoutes.otp);
    } else {
      final String? error = ref.read(authProvider).errorMessage;
      if (error != null) AppSnackbar.error(context, error);
    }
  }

  Future<void> _signInWithGoogle() async {
    final bool ok = await ref.read(authProvider.notifier).signInWithGoogle();
    if (!mounted || ok) return;

    final String? error = ref.read(authProvider).errorMessage;
    if (error != null) AppSnackbar.error(context, error);
  }

  Future<void> _signInWithApple() async {
    final bool ok = await ref.read(authProvider.notifier).signInWithApple();
    if (!mounted || ok) return;

    final String? error = ref.read(authProvider).errorMessage;
    if (error != null) AppSnackbar.error(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),

                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.brandTeal,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: const Icon(
                    Icons.healing_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                Text('Welcome Back 👋', style: theme.textTheme.displayLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Login to your account',
                  style: theme.textTheme.bodySmall,
                ),

                const SizedBox(height: AppSpacing.xl),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  enabled: !auth.isSubmitting,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: '98765 43210',
                    prefixIcon: Icon(Icons.phone_outlined),
                    prefixText: '+91  ',
                    counterText: '',
                  ),
                  validator: (value) {
                    final String phone = value?.trim() ?? '';
                    if (phone.isEmpty) return 'Enter your mobile number';
                    // Indian mobile numbers always start with 6-9
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _sendOtp(),
                ),

                const SizedBox(height: AppSpacing.lg),

                AppButton(
                  label: 'Login with OTP',
                  isLoading: auth.isSubmitting,
                  onPressed: _sendOtp,
                ),

                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        'or continue with',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                _SocialButton(
                  label: 'Continue with Google',
                  icon: Icons.g_mobiledata_rounded,
                  onPressed: auth.isSubmitting ? null : _signInWithGoogle,
                ),

                // Apple sign-in is an App Store requirement on iOS and has no
                // meaning on Android, so it is platform-gated.
                if (Platform.isIOS) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _SocialButton(
                    label: 'Continue with Apple',
                    icon: Icons.apple,
                    onPressed: auth.isSubmitting ? null : _signInWithApple,
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                Center(
                  child: Text(
                    'By continuing you agree to our Terms of Service\nand Privacy Policy',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      label: Text(label),
    );
  }
}
