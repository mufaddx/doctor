import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../auth/data/auth_repository.dart';

class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.authorName,
    required this.createdAt,
    this.comment,
    this.authorAvatarUrl,
  });

  final String id;
  final int rating;
  final String authorName;
  final String? authorAvatarUrl;
  final String? comment;
  final DateTime createdAt;

  factory Review.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;

    return Review(
      id: json['id'] as String,
      rating: json['rating'] as int? ?? 0,
      authorName: author?['fullName'] as String? ?? 'Patient',
      authorAvatarUrl: author?['avatarUrl'] as String?,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

final reviewsProvider = FutureProvider.autoDispose<List<Review>>((ref) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>(ApiRoutes.myReviews, query: {'limit': 50});

  return (data['items'] as List<dynamic>)
      .map((e) => Review.fromJson(e as Map<String, dynamic>))
      .toList();
});

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(reviewsProvider);
    final user = ref.watch(currentTherapistProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Reviews'),
      ),
      body: reviewsAsync.when(
        loading: () => const AppListSkeleton(itemHeight: 96),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(reviewsProvider),
        ),
        data: (reviews) {
          if (reviews.isEmpty) {
            return const AppEmptyView(
              title: 'No reviews yet',
              message: 'Patients can rate you after a completed session.',
              icon: Icons.star_outline,
            );
          }

          // The histogram is computed locally from the loaded page rather than
          // fetched separately, since the list is capped at 50 entries.
          final Map<int, int> histogram = {
            for (int star = 5; star >= 1; star--)
              star: reviews.where((review) => review.rating == star).length,
          };

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(reviewsProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            Text(
                              (user?.ratingAvg ?? 0).toStringAsFixed(1),
                              style: theme.textTheme.displayLarge?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < (user?.ratingAvg ?? 0).round()
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 14,
                                  color: AppColors.warning,
                                );
                              }),
                            ),
                            Text(
                              '${user?.ratingCount ?? 0} reviews',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            children: histogram.entries.map((entry) {
                              final double ratio = reviews.isEmpty
                                  ? 0
                                  : entry.value / reviews.length;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Text(
                                      '${entry.key}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: ratio,
                                          minHeight: 6,
                                          backgroundColor: theme.dividerColor,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      width: 20,
                                      child: Text(
                                        '${entry.value}',
                                        style: theme.textTheme.bodySmall,
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                ...reviews.map((review) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppAvatar(
                            imageUrl: review.authorAvatarUrl,
                            name: review.authorName,
                            size: 38,
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
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('d MMM yyyy')
                                          .format(review.createdAt),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                Row(
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < review.rating
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 13,
                                      color: AppColors.warning,
                                    );
                                  }),
                                ),
                                if (review.comment != null &&
                                    review.comment!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    review.comment!,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
