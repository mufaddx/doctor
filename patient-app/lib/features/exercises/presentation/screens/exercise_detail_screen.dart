import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/exercise_repository.dart';

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _loadedVideoUrl;

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _ensureVideo(String videoUrl) async {
    if (_loadedVideoUrl == videoUrl) return;
    _loadedVideoUrl = videoUrl;

    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await controller.initialize();

    if (!mounted) return;

    setState(() {
      _videoController = controller;
      _chewieController = ChewieController(
        videoPlayerController: controller,
        aspectRatio: controller.value.aspectRatio,
        autoPlay: false,
        looping: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.brandTeal,
          handleColor: AppColors.brandTeal,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final exerciseAsync = ref.watch(exerciseDetailProvider(widget.exerciseId));

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise')),
      body: exerciseAsync.when(
        loading: () => const AppListSkeleton(itemCount: 3, itemHeight: 100),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(exerciseDetailProvider(widget.exerciseId)),
        ),
        data: (exercise) {
          if (exercise.videoUrl.isNotEmpty) {
            _ensureVideo(exercise.videoUrl);
          }

          final theme = Theme.of(context);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (exercise.videoUrl.isEmpty)
                Container(
                  height: 200,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: Icon(
                    Icons.fitness_center,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                )
              else if (_chewieController == null)
                const AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: Chewie(controller: _chewieController!),
                  ),
                ),

              const SizedBox(height: AppSpacing.lg),

              Text(exercise.title, style: theme.textTheme.displayLarge),
              const SizedBox(height: AppSpacing.sm),

              Row(
                children: [
                  _Pill(label: exercise.level),
                  const SizedBox(width: AppSpacing.sm),
                  _Pill(label: '${exercise.durationMinutes} min'),
                  if (exercise.category.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    _Pill(label: exercise.category),
                  ],
                ],
              ),

              if (exercise.instructions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Instructions', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                for (int i = 0; i < exercise.instructions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            exercise.instructions[i],
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}
