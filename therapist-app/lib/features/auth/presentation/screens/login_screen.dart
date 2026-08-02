import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final bool ok = await ref
        .read(authProvider.notifier)
        .login(_phoneController.text.trim(), _passwordController.text);

    if (!mounted || ok) return;

    final String? error = ref.read(authProvider).errorMessage;
    if (error != null) AppSnackbar.error(context, error);
  }

  Future<void> _forgotPassword() async {
    final String phone = _phoneController.text.trim();

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      AppSnackbar.error(context, 'Enter your mobile number first');
      return;
    }

    try {
      await ref.read(authRepositoryProvider).forgotPassword(phone);

      if (!mounted) return;
      AppSnackbar.success(
        context,
        'If the number is registered, a reset code has been sent',
      );
    } catch (error) {
      if (!mounted) return;
      AppSnackbar.error(context, error.toString());
    }
  }

  Future<void> _signInWithGoogle() async {
    final bool ok = await ref.read(authProvider.notifier).signInWithGoogle();
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
                    Icons.medical_services_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                Text('Welcome Back 👋', style: theme.textTheme.displayLarge),
                const SizedBox(height: AppSpacing.xs),
                Text('Login to your account', style: theme.textTheme.bodySmall),

                const SizedBox(height: AppSpacing.xl),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  enabled: !auth.isSubmitting,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    prefixText: '+91  ',
                    counterText: '',
                  ),
                  validator: (value) {
                    final String phone = value?.trim() ?? '';
                    if (phone.isEmpty) return 'Enter your mobile number';
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enabled: !auth.isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if ((value?.length ?? 0) < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _login(),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: auth.isSubmitting ? null : _forgotPassword,
                    child: const Text('Forgot Password?'),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                AppButton(
                  label: 'Login',
                  isLoading: auth.isSubmitting,
                  onPressed: _login,
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

                OutlinedButton.icon(
                  onPressed: auth.isSubmitting ? null : _signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                  label: const Text('Continue with Google'),
                ),

                const SizedBox(height: AppSpacing.xl),

                Center(
                  child: Text(
                    'Not registered as a therapist yet?\nContact our team to get onboarded.',
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
