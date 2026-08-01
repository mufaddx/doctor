import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../wallet/data/wallet_repository.dart';

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isApplying = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _applyCode() async {
    final String code = _codeController.text.trim();

    if (code.isEmpty) {
      AppSnackbar.error(context, 'Enter a referral code');
      return;
    }

    setState(() => _isApplying = true);

    try {
      final String message =
          await ref.read(walletRepositoryProvider).applyReferralCode(code);

      if (!mounted) return;

      _codeController.clear();
      ref.invalidate(referralInfoProvider);
      ref.invalidate(walletBalanceProvider);
      await ref.read(authProvider.notifier).refreshUser();

      if (!mounted) return;
      AppSnackbar.success(context, message);
    } catch (error) {
      if (!mounted) return;
      AppSnackbar.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final referralAsync = ref.watch(referralInfoProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Refer & Earn'),
      ),
      body: referralAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(referralInfoProvider),
        ),
        data: (referral) {
          final String shareMessage =
              'Get expert physiotherapy at home with Touch of Cure. '
              'Use my code ${referral.referralCode} when you sign up.';

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.card_giftcard,
                      size: 52,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Invite friends and earn ₹${referral.bonusPerReferral.toStringAsFixed(0)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'When a friend signs up with your code, the bonus is credited straight to your wallet.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              Text('Your Referral Code', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    // A dashed look is not available, so a solid accent border
                    // signals this block is copyable
                    width: 1.4,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        referral.referralCode,
                        style: theme.textTheme.titleLarge?.copyWith(
                          letterSpacing: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy code',
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: referral.referralCode),
                        );
                        if (!context.mounted) return;
                        AppSnackbar.success(context, 'Code copied');
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              AppButton(
                label: 'Share with Friends',
                icon: Icons.share_outlined,
                onPressed: () => Share.share(shareMessage),
              ),

              const SizedBox(height: AppSpacing.lg),

              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            Text(
                              '${referral.referredCount}',
                              style: theme.textTheme.displayLarge?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Text(
                              'Friends Referred',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            Text(
                              '₹${referral.totalEarned.toStringAsFixed(0)}',
                              style: theme.textTheme.displayLarge?.copyWith(
                                color: AppColors.success,
                              ),
                            ),
                            Text(
                              'Total Earned',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.md),

              Text('Have a referral code?', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'A code can be applied only once per account.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Enter code',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: 'Apply',
                    expanded: false,
                    isLoading: _isApplying,
                    onPressed: _applyCode,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }
}
