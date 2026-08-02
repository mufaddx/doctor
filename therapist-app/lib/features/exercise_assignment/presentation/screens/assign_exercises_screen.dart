import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/exercise_repository.dart';

/// An exercise the therapist has picked, together with its prescribed sets.
class _SelectedExercise {
  const _SelectedExercise({required this.exercise, required this.sets});

  final ExerciseModel exercise;
  final int sets;

  _SelectedExercise withSets(int value) =>
      _SelectedExercise(exercise: exercise, sets: value);
}

class AssignExercisesScreen extends ConsumerStatefulWidget {
  const AssignExercisesScreen({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<AssignExercisesScreen> createState() =>
      _AssignExercisesScreenState();
}

class _AssignExercisesScreenState extends ConsumerState<AssignExercisesScreen> {
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  /// Keyed by exercise id so toggling is O(1) and order stays stable.
  final Map<String, _SelectedExercise> _selected = {};

  double _painLevel = 5;
  bool _isSaving = false;

  @override
  void dispose() {
    _conditionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _toggle(ExerciseModel exercise) {
    setState(() {
      if (_selected.containsKey(exercise.id)) {
        _selected.remove(exercise.id);
      } else {
        _selected[exercise.id] = _SelectedExercise(exercise: exercise, sets: 3);
      }
    });
  }

  Future<void> _save() async {
    final String condition = _conditionController.text.trim();

    if (condition.isEmpty) {
      AppSnackbar.error(context, 'Enter the condition this plan addresses');
      return;
    }
    if (_selected.isEmpty) {
      AppSnackbar.error(context, 'Select at least one exercise');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref
          .read(apiClientProvider)
          .post(
            ApiRoutes.assignExercises,
            body: {
              'patientId': widget.patientId,
              'condition': condition,
              'painLevel': _painLevel.round(),
              if (_notesController.text.trim().isNotEmpty)
                'notes': _notesController.text.trim(),
              'exercises': _selected.values
                  .map(
                    (item) => {
                      'exerciseId': item.exercise.id,
                      'sets': item.sets,
                    },
                  )
                  .toList(),
            },
          );

      if (!mounted) return;
      AppSnackbar.success(context, 'Exercise plan sent to the patient');
      context.pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackbar.error(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exerciseLibraryProvider);
    final categoriesAsync = ref.watch(exerciseCategoriesProvider);
    final String? selectedCategory = ref.watch(selectedCategoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Assign Exercise Plan'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                TextField(
                  controller: _conditionController,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Condition',
                    hintText: 'e.g. Back Pain',
                    counterText: '',
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current pain level',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      '${_painLevel.round()} / 10',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _painLevel,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: _painLevel.round().toString(),
                  onChanged: (value) => setState(() => _painLevel = value),
                ),

                const SizedBox(height: AppSpacing.sm),

                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Notes for the patient (optional)',
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                Text('Select Exercises', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),

                categoriesAsync.maybeWhen(
                  data: (categories) => SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            label: const Text('All'),
                            selected: selectedCategory == null,
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: selectedCategory == null
                                  ? Colors.white
                                  : null,
                            ),
                            onSelected: (_) =>
                                ref
                                        .read(selectedCategoryProvider.notifier)
                                        .state =
                                    null,
                          ),
                        ),
                        ...categories.map((category) {
                          final bool isSelected = selectedCategory == category;

                          return Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.sm,
                            ),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: isSelected,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Colors.white : null,
                              ),
                              onSelected: (_) =>
                                  ref
                                          .read(
                                            selectedCategoryProvider.notifier,
                                          )
                                          .state =
                                      category,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),

                const SizedBox(height: AppSpacing.sm),

                exercisesAsync.when(
                  loading: () => const AppListSkeleton(itemHeight: 72),
                  error: (error, _) => AppErrorView(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(exerciseLibraryProvider),
                  ),
                  data: (exercises) {
                    if (exercises.isEmpty) {
                      return const AppEmptyView(
                        title: 'No exercises in this category',
                        icon: Icons.fitness_center_outlined,
                      );
                    }

                    return Column(
                      children: exercises.map((exercise) {
                        final _SelectedExercise? picked =
                            _selected[exercise.id];
                        final bool isPicked = picked != null;

                        return Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.all(
                                  AppSpacing.sm,
                                ),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm,
                                  ),
                                  child: SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: exercise.thumbnailUrl == null
                                        ? Container(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.08),
                                            child: Icon(
                                              Icons.fitness_center,
                                              color: theme.colorScheme.primary,
                                              size: 20,
                                            ),
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: exercise.thumbnailUrl!,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                                  color: theme.dividerColor,
                                                ),
                                          ),
                                  ),
                                ),
                                title: Text(
                                  exercise.title,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${exercise.durationMinutes} min · ${exercise.level}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                trailing: Checkbox(
                                  value: isPicked,
                                  onChanged: (_) => _toggle(exercise),
                                ),
                                onTap: () => _toggle(exercise),
                              ),

                              // The sets stepper only appears once picked, so
                              // unselected rows stay compact
                              if (isPicked)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.md,
                                    0,
                                    AppSpacing.md,
                                    AppSpacing.sm,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Sets',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          size: 20,
                                        ),
                                        onPressed: picked.sets <= 1
                                            ? null
                                            : () => setState(() {
                                                _selected[exercise.id] = picked
                                                    .withSets(picked.sets - 1);
                                              }),
                                      ),
                                      Text(
                                        '${picked.sets}',
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          size: 20,
                                        ),
                                        onPressed: picked.sets >= 20
                                            ? null
                                            : () => setState(() {
                                                _selected[exercise.id] = picked
                                                    .withSets(picked.sets + 1);
                                              }),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppButton(
                label: _selected.isEmpty
                    ? 'Send Plan'
                    : 'Send Plan (${_selected.length} exercises)',
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
