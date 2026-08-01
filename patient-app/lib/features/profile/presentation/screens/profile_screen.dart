import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to book sessions.'),
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

    // The router redirect handles navigation once the status flips
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(authProvider.notifier).refreshUser(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    AppAvatar(
                      imageUrl: user?.avatarUrl,
                      name: user?.fullName ?? 'User',
                      size: 62,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'User',
                            style: theme.textTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+91 ${user?.phone ?? ''}',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (user?.email != null)
                            Text(
                              user!.email!,
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => context.go(
                        '${AppRoutes.profile}/${AppRoutes.editProfile}',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Wallet balance is surfaced here because it affects checkout
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                title: Text('Wallet Balance', style: theme.textTheme.bodyMedium),
                subtitle: Text(
                  '₹${(user?.walletBalance ?? 0).toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.go('${AppRoutes.profile}/${AppRoutes.wallet}'),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            _MenuGroup(
              items: [
                _MenuItem(
                  icon: Icons.person_outline,
                  label: 'Personal Information',
                  onTap: () => context.go(
                    '${AppRoutes.profile}/${AppRoutes.editProfile}',
                  ),
                ),
                _MenuItem(
                  icon: Icons.location_on_outlined,
                  label: 'My Addresses',
                  onTap: () => context.go(
                    '${AppRoutes.profile}/${AppRoutes.addresses}',
                  ),
                ),
                _MenuItem(
                  icon: Icons.description_outlined,
                  label: 'My Prescriptions',
                  onTap: () => context.go(AppRoutes.appointments),
                ),
                _MenuItem(
                  icon: Icons.card_giftcard_outlined,
                  label: 'Refer & Earn',
                  onTap: () =>
                      context.go('${AppRoutes.profile}/${AppRoutes.referral}'),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            _MenuGroup(
              items: [
                _MenuItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () =>
                      context.go('${AppRoutes.profile}/${AppRoutes.settings}'),
                ),
                _MenuItem(
                  icon: Icons.help_outline,
                  label: 'Help & Support',
                  onTap: () => context.go(
                    '${AppRoutes.profile}/${AppRoutes.helpSupport}',
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: Text(
                  'Logout',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.danger),
                ),
                onTap: () => _confirmLogout(context, ref),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Center(
              child: Text(
                'Touch of Cure v1.0.0',
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

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (int index = 0; index < items.length; index++) ...[
            ListTile(
              leading: Icon(items[index].icon),
              title: Text(
                items[index].label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: items[index].onTap,
            ),
            // No divider after the final row
            if (index < items.length - 1)
              const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}
