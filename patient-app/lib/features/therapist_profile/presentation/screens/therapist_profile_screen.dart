import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../search/data/therapist_repository.dart';
import '../../../search/presentation/providers/therapist_provider.dart';

class TherapistProfileScreen extends ConsumerWidget {
  const TherapistProfileScreen({super.key, required this.therapistId});

  final String therapistId;

  Future<void> _openChat(BuildContext context, WidgetRef ref, String? userId) async {
    if (userId == null) return;

    try {
      final String threadId =
          await ref.read(chatRepositoryProvider).openThread(userId);

      if (!context.mounted) return;
      context.go('${AppRoutes.chatList}/${AppRoutes.chatThread}/$threadId');
    } catch (error) {
      if (!context.mounted) return;
      AppSnackbar.error(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(therapistDetailProvider(therapistId));
    final theme = Theme.of(context);

    return Scaffold(
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(therapistDetailProvider(therapistId)),
        ),
        data: (therapist) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                leading: IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: Colors.black26,
                    child: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.black26,
                      child: Icon(Icons.chat_bubble_outline, color: Colors.white),
                    ),
                    onPressed: () => _openChat(context, ref, therapist.userId),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.brandTeal, AppColors.brandTealDark],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppAvatar(
                            imageUrl: therapist.avatarUrl,
                            name: therapist.fullName,
                            size: 96,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            therapist.fullName,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                          Text(
                            therapist.specialization.isEmpty
                                ? 'Physiotherapist'
                                : therapist.specialization.first,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Three headline metrics patients care about most
                      Row(
                        children: [
                          _StatTile(
                            icon: Icons.workspace_premium_outlined,
                            value: '${therapist.experienceYears}+',
                            label: 'Years Exp.',
                          ),
                          _StatTile(
                            icon: Icons.star_rounded,
                            value: therapist.ratingAvg.toStringAsFixed(1),
                            label: '${therapist.ratingCount} reviews',
                            iconColor: AppColors.warning,
                          ),
                          _StatTile(
                            icon: Icons.people_outline,
                            value: '${therapist.completedAppointments}',
                            label: 'Sessions',
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      if (therapist.specialization.isNotEmpty) ...[
                        Text('Specializations',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: therapist.specialization
                              .map((item) => Chip(label: Text(item)))
                              .toList(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      if (therapist.bio != null && therapist.bio!.isNotEmpty) ...[
                        Text('About', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          therapist.bio!,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      Text('Consultation Fees',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      _FeeRow(
                        icon: Icons.local_hospital_outlined,
                        label: 'Clinic Visit',
                        fee: therapist.clinicFee,
                      ),
                      _FeeRow(
                        icon: Icons.home_outlined,
                        label: 'Home Visit',
                        fee: therapist.homeVisitFee,
                      ),
                      _FeeRow(
                        icon: Icons.videocam_outlined,
                        label: 'Video Consultation',
                        fee: therapist.videoFee,
                      ),

                      if (therapist.certificates.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text('Qualifications',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        ...therapist.certificates.map(
                          (title) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified_outlined,
                                  size: 16,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      if (therapist.clinicAddress != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text('Clinic Address',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                therapist.clinicAddress!,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Reviews', style: theme.textTheme.titleMedium),
                          Text(
                            '${therapist.ratingCount} total',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      if (therapist.reviews.isEmpty)
                        Text(
                          'No reviews yet.',
                          style: theme.textTheme.bodySmall,
                        )
                      else
                        ...therapist.reviews.map(
                          (review) => _ReviewTile(review: review),
                        ),

                      // Leaves room for the pinned bottom booking bar
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),

      bottomNavigationBar: detailAsync.maybeWhen(
        data: (therapist) => SafeArea(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Starting from', style: theme.textTheme.bodySmall),
                    Text(
                      '₹${therapist.startingFee.toStringAsFixed(0)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: therapist.isAvailable
                        ? 'Book Appointment'
                        : 'Not Accepting Bookings',
                    onPressed: therapist.isAvailable
                        ? () => context.go(
                              '${AppRoutes.home}/${AppRoutes.therapistProfile}/$therapistId/${AppRoutes.selectSlot}',
                            )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor ?? theme.colorScheme.primary, size: 22),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleMedium),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  const _FeeRow({required this.icon, required this.label, required this.fee});

  final IconData icon;
  final String label;
  final double fee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            // A zero fee means the therapist does not offer that mode
            fee > 0 ? '₹${fee.toStringAsFixed(0)}' : 'Not offered',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: fee > 0 ? null : theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final TherapistReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(
            imageUrl: review.authorAvatarUrl,
            name: review.authorName,
            size: 36,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.authorName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      DateFormat('d MMM yyyy').format(review.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < review.rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 14,
                      color: AppColors.warning,
                    );
                  }),
                ),
                if (review.comment != null && review.comment!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(review.comment!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
