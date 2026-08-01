import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../appointments/data/appointment_model.dart';
import '../../../appointments/presentation/providers/appointments_provider.dart';
import '../../../appointments/presentation/widgets/schedule_tile.dart';
import '../../../auth/data/auth_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String get _greeting {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentTherapistProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final scheduleAsync = ref.watch(todayScheduleProvider);
    final theme = Theme.of(context);

    // Surface availability toggle failures without blocking the screen
    ref.listen(authProvider, (previous, next) {
      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        AppSnackbar.error(context, next.errorMessage!);
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardStatsProvider);
            ref.invalidate(todayScheduleProvider);
            await ref.read(authProvider.notifier).refreshUser();
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Row(
                children: [
                  AppAvatar(
                    imageUrl: user?.avatarUrl,
                    name: user?.fullName ?? 'Therapist',
                    size: 48,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting, style: theme.textTheme.bodySmall),
                        Text(
                          user?.fullName ?? 'Therapist',
                          style: theme.textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: (user?.isAvailable ?? false)
                                    ? AppColors.success
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              (user?.isAvailable ?? false)
                                  ? 'Online'
                                  : 'Not accepting bookings',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/notifications'),
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Verification gates discoverability, so an unverified therapist
              // is told explicitly why they receive no bookings.
              if (user != null && !user.isVerified)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.kycStatus == 'PENDING'
                                  ? 'Verification in review'
                                  : 'Verification required',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              user.kycStatus == 'PENDING'
                                  ? 'Your documents are being reviewed. You will start receiving bookings once approved.'
                                  : 'Upload your qualification certificates to start receiving bookings.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              Card(
                child: SwitchListTile(
                  value: user?.isAvailable ?? false,
                  onChanged: user == null || !user.isVerified
                      ? null
                      : (value) =>
                          ref.read(authProvider.notifier).setAvailability(value),
                  title: Text(
                    'Accepting new bookings',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Turn this off when you are on leave',
                    style: theme.textTheme.bodySmall,
                  ),
                  secondary: Icon(
                    Icons.toggle_on_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              statsAsync.when(
                loading: () => const AppListSkeleton(itemCount: 2, itemHeight: 78),
                error: (error, _) => AppErrorView(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(dashboardStatsProvider),
                ),
                data: (stats) => Column(
                  children: [
                    Row(
                      children: [
                        _StatCard(
                          label: "Today's Appointments",
                          value: stats.todayAppointments,
                          icon: Icons.event_available_outlined,
                          tint: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _StatCard(
                          label: 'Pending Requests',
                          value: stats.pendingRequests,
                          icon: Icons.pending_actions_outlined,
                          tint: AppColors.warning,
                          onTap: () => context.go('/appointments?tab=pending'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        _StatCard(
                          label: 'Video Consults',
                          value: stats.videoConsultations,
                          icon: Icons.videocam_outlined,
                          tint: AppColors.info,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _StatCard(
                          label: 'Home Visits',
                          value: stats.homeVisits,
                          icon: Icons.home_outlined,
                          tint: AppColors.brandTealLight,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Today's Schedule", style: theme.textTheme.titleMedium),
                  TextButton(
                    onPressed: () => context.go('/appointments'),
                    child: const Text('View All'),
                  ),
                ],
              ),

              scheduleAsync.when(
                loading: () => const AppListSkeleton(itemCount: 3, itemHeight: 76),
                error: (error, _) => AppErrorView(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(todayScheduleProvider),
                ),
                data: (appointments) {
                  if (appointments.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: AppEmptyView(
                        title: 'Nothing scheduled today',
                        message: 'Enjoy the break, or open up more slots.',
                        icon: Icons.event_busy_outlined,
                      ),
                    );
                  }

                  return Column(
                    children: appointments
                        .map(
                          (appointment) => ScheduleTile(
                            appointment: appointment,
                            onTap: () => context.go(
                              '/appointments/detail/${appointment.id}',
                            ),
                            onJoinCall: appointment.canJoinCall
                                ? () => context.push('/call/${appointment.id}')
                                : null,
                          ),
                        )
                        .toList(),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(icon, size: 16, color: tint),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$value'.padLeft(2, '0'),
                  style: theme.textTheme.displayLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
