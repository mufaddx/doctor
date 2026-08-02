import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../auth/data/auth_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will stop receiving booking notifications until you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // The router redirect takes over once the status flips
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentTherapistProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(authProvider.notifier).refreshUser(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    AppAvatar(
                      imageUrl: user?.avatarUrl,
                      name: user?.fullName ?? 'Therapist',
                      size: 76,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      user?.fullName ?? 'Therapist',
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      user?.specialization.isNotEmpty ?? false
                          ? user!.specialization.join(' · ')
                          : 'Physiotherapist',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(user?.ratingAvg ?? 0).toStringAsFixed(1)} (${user?.ratingCount ?? 0} reviews)',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),

                    // Verification state governs whether the profile is
                    // discoverable at all, so it is shown prominently.
                    if (user != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (user.isVerified
                                      ? AppColors.success
                                      : AppColors.warning)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              user.isVerified
                                  ? Icons.verified
                                  : Icons.pending_outlined,
                              size: 14,
                              color: user.isVerified
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.isVerified
                                  ? 'Verified'
                                  : (user.kycStatus == 'PENDING'
                                        ? 'Verification in review'
                                        : 'Not verified'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: user.isVerified
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Row(
              children: [
                _MiniStat(
                  label: 'Experience',
                  value: '${user?.experienceYears ?? 0} Yrs',
                ),
                const SizedBox(width: AppSpacing.sm),
                _MiniStat(
                  label: 'Clinic Fee',
                  value: '₹${(user?.clinicFee ?? 0).toStringAsFixed(0)}',
                ),
                const SizedBox(width: AppSpacing.sm),
                _MiniStat(
                  label: 'Video Fee',
                  value: '₹${(user?.videoFee ?? 0).toStringAsFixed(0)}',
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            Card(
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.schedule_outlined,
                    label: 'My Availability',
                    onTap: () => context.go('/profile/availability'),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuTile(
                    icon: Icons.star_outline,
                    label: 'Reviews',
                    onTap: () => context.go('/profile/reviews'),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuTile(
                    icon: Icons.account_balance_outlined,
                    label: 'Bank Details',
                    onTap: () => context.go('/profile/bank-details'),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuTile(
                    icon: Icons.chat_bubble_outline,
                    label: 'Messages',
                    onTap: () => context.push('/chat'),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuTile(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => context.go('/profile/settings'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: Text(
                  'Logout',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.danger,
                  ),
                ),
                onTap: () => _confirmLogout(context, ref),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Center(
              child: Text(
                'Touch of Cure Doctor v1.0.0',
                style: theme.textTheme.bodySmall,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            children: [
              Text(value, style: theme.textTheme.titleMedium),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
