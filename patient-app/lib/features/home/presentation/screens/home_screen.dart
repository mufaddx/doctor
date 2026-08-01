import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../search/presentation/providers/therapist_provider.dart';
import '../../../appointments/presentation/providers/appointments_provider.dart';
import '../providers/home_provider.dart';
import '../widgets/therapist_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          // Invalidating the providers forces every section to refetch
          onRefresh: () async {
            ref.invalidate(topRatedTherapistsProvider);
            ref.invalidate(bannersProvider);
            ref.invalidate(upcomingAppointmentProvider);
            await ref.read(authProvider.notifier).refreshUser();
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, ${user?.fullName.split(' ').first ?? 'there'} 👋',
                              style: theme.textTheme.titleLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'How are you feeling today?',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const _NotificationBell(),
                      const SizedBox(width: AppSpacing.sm),
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.profile),
                        child: AppAvatar(
                          imageUrl: user?.avatarUrl,
                          name: user?.fullName ?? 'User',
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

              // Tapping the field routes to the real search screen rather than
              // typing inline, so the results screen owns the query state.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: GestureDetector(
                    onTap: () => context.go('${AppRoutes.home}/${AppRoutes.search}'),
                    child: AbsorbPointer(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search for pain, treatment...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: Icon(
                            Icons.tune,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

              const SliverToBoxAdapter(child: _QuickActions()),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

              const SliverToBoxAdapter(child: _UpcomingAppointmentCard()),

              const SliverToBoxAdapter(child: _BannerCarousel()),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Top Therapists', style: theme.textTheme.titleMedium),
                      TextButton(
                        onPressed: () =>
                            context.go('${AppRoutes.home}/${AppRoutes.search}'),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ),
              ),

              const _TopTherapistsList(),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int unread = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return IconButton(
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = <({IconData icon, String label, String route})>[
      (
        icon: Icons.local_hospital_outlined,
        label: 'Clinic Visit',
        route: '${AppRoutes.home}/${AppRoutes.search}?q=clinic',
      ),
      (
        icon: Icons.home_outlined,
        label: 'Home Visit',
        route: '${AppRoutes.home}/${AppRoutes.search}?q=home',
      ),
      (
        icon: Icons.videocam_outlined,
        label: 'Video Call',
        route: '${AppRoutes.home}/${AppRoutes.search}?q=video',
      ),
      (
        icon: Icons.fitness_center_outlined,
        label: 'Exercises',
        route: AppRoutes.exercises,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: actions.map((action) {
          return Expanded(
            child: GestureDetector(
              onTap: () => context.go(action.route),
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Icon(
                      action.icon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    action.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Surfaces the next confirmed appointment so the most time-sensitive action
/// is always one tap away from the home screen.
class _UpcomingAppointmentCard extends ConsumerWidget {
  const _UpcomingAppointmentCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentAsync = ref.watch(upcomingAppointmentProvider);

    return appointmentAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (appointment) {
        if (appointment == null) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final bool isVideo = appointment.type == 'VIDEO_CONSULTATION';

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brandTeal, AppColors.brandTealDark],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppAvatar(
                      imageUrl: appointment.therapistAvatarUrl,
                      name: appointment.therapistName,
                      size: 44,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appointment.therapistName,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            appointment.readableType,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${DateFormat('d MMM').format(appointment.scheduledDate)}, ${appointment.startTime}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const Spacer(),
                    if (isVideo)
                      FilledButton.tonal(
                        onPressed: () =>
                            context.push('/call/${appointment.id}'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.brandTeal,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Join Call'),
                      )
                    else
                      TextButton(
                        onPressed: () => context.go(
                          '${AppRoutes.appointments}/${AppRoutes.appointmentDetail}/${appointment.id}',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('View'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BannerCarousel extends ConsumerStatefulWidget {
  const _BannerCarousel();

  @override
  ConsumerState<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends ConsumerState<_BannerCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.92);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(bannersProvider);

    return bannersAsync.when(
      loading: () => const SizedBox(height: 120),
      error: (_, __) => const SizedBox.shrink(),
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            padEnds: false,
            itemBuilder: (context, index) {
              final banner = banners[index];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: CachedNetworkImage(
                    imageUrl: banner.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, __) => Container(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.06),
                    ),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TopTherapistsList extends ConsumerWidget {
  const _TopTherapistsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final therapistsAsync = ref.watch(topRatedTherapistsProvider);

    return therapistsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: AppListSkeleton(itemCount: 3),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: AppErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(topRatedTherapistsProvider),
        ),
      ),
      data: (therapists) {
        if (therapists.isEmpty) {
          return const SliverToBoxAdapter(
            child: AppEmptyView(
              title: 'No therapists available yet',
              message: 'Please check back shortly.',
              icon: Icons.person_search_outlined,
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: SliverList.separated(
            itemCount: therapists.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) => TherapistCard(
              therapist: therapists[index],
              onTap: () => context.go(
                '${AppRoutes.home}/${AppRoutes.therapistProfile}/${therapists[index].id}',
              ),
            ),
          ),
        );
      },
    );
  }
}
