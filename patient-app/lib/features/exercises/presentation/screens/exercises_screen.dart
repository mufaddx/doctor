import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/exercise_repository.dart';

class ExercisesScreen extends ConsumerStatefulWidget {
  const ExercisesScreen({super.key});

  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercises'),
        actions: [
          IconButton(
            tooltip: 'My Progress',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () =>
                context.go('${AppRoutes.exercises}/${AppRoutes.progress}'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Plan'),
            Tab(text: 'Library'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_MyPlanTab(), _LibraryTab()],
      ),
    );
  }
}

class _MyPlanTab extends ConsumerWidget {
  const _MyPlanTab();

  Future<void> _markComplete(
    BuildContext context,
    WidgetRef ref,
    String assignmentId,
  ) async {
    try {
      await ref.read(exerciseRepositoryProvider).markCompleted(assignmentId);
      ref.invalidate(myExercisePlanProvider);

      if (!context.mounted) return;
      AppSnackbar.success(context, 'Exercise marked as completed');
    } catch (error) {
      if (!context.mounted) return;
      AppSnackbar.error(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(myExercisePlanProvider);
    final theme = Theme.of(context);

    return planAsync.when(
      loading: () => const AppListSkeleton(itemHeight: 88),
      error: (error, _) => AppErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(myExercisePlanProvider),
      ),
      data: (plan) {
        if (plan.assignments.isEmpty) {
          return const AppEmptyView(
            title: 'No exercises assigned yet',
            message:
                'Your therapist will assign a plan after your consultation.',
            icon: Icons.fitness_center_outlined,
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myExercisePlanProvider),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 62,
                        height: 62,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: plan.completionRatio,
                              strokeWidth: 6,
                              backgroundColor: theme.dividerColor,
                            ),
                            Text(
                              '${(plan.completionRatio * 100).round()}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Progress',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${plan.completed} of ${plan.total} exercises completed',
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              '${plan.sessionsLogged} sessions logged',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              ...plan.assignments.map((assignment) {
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(AppSpacing.sm),
                    leading: _Thumbnail(url: assignment.exercise.thumbnailUrl),
                    title: Text(
                      assignment.exercise.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        // Completed items are struck through so the remaining
                        // work is obvious at a glance
                        decoration: assignment.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      '${assignment.exercise.durationMinutes} min · ${assignment.sets} sets · ${assignment.exercise.level}',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: assignment.completed
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                          )
                        : IconButton(
                            tooltip: 'Mark as done',
                            icon: const Icon(Icons.radio_button_unchecked),
                            onPressed: () => _markComplete(
                              context,
                              ref,
                              assignment.assignmentId,
                            ),
                          ),
                    onTap: () => context.go(
                      '${AppRoutes.exercises}/${AppRoutes.exerciseDetail}/${assignment.exercise.id}',
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _LibraryTab extends ConsumerWidget {
  const _LibraryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(exerciseCategoriesProvider);
    final exercisesAsync = ref.watch(exerciseLibraryProvider);
    final String? selected = ref.watch(selectedExerciseCategoryProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: categoriesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (categories) => ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: const Text('For You'),
                    selected: selected == null,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: selected == null ? Colors.white : null,
                    ),
                    onSelected: (_) => ref
                        .read(selectedExerciseCategoryProvider.notifier)
                        .state = null,
                  ),
                ),
                ...categories.map((category) {
                  final bool isSelected = selected == category;

                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color: isSelected ? Colors.white : null,
                      ),
                      onSelected: (_) => ref
                          .read(selectedExerciseCategoryProvider.notifier)
                          .state = category,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        Expanded(
          child: exercisesAsync.when(
            loading: () => const AppListSkeleton(itemHeight: 80),
            error: (error, _) => AppErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(exerciseLibraryProvider),
            ),
            data: (exercises) {
              if (exercises.isEmpty) {
                return const AppEmptyView(
                  title: 'No exercises here',
                  message: 'Try a different category.',
                  icon: Icons.fitness_center_outlined,
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: exercises.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final exercise = exercises[index];

                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(AppSpacing.sm),
                      leading: _Thumbnail(url: exercise.thumbnailUrl),
                      title: Text(
                        exercise.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${exercise.durationMinutes} min · ${exercise.level}',
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: const Icon(Icons.play_circle_outline),
                      onTap: () => context.go(
                        '${AppRoutes.exercises}/${AppRoutes.exerciseDetail}/${exercise.id}',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: SizedBox(
        width: 58,
        height: 58,
        child: url == null || url!.isEmpty
            ? Container(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
                child: Icon(
                  Icons.fitness_center,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              )
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Theme.of(context).dividerColor,
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                  child: Icon(
                    Icons.fitness_center,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                ),
              ),
      ),
    );
  }
}
