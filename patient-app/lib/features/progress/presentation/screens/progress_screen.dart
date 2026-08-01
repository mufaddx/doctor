import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/progress_repository.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  Future<void> _openLogSheet(BuildContext context, WidgetRef ref) async {
    final bool? logged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _LogPainSheet(),
    );

    if (logged == true) {
      ref.invalidate(progressChartProvider);
      ref.invalidate(progressConditionsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartAsync = ref.watch(progressChartProvider);
    final conditionsAsync = ref.watch(progressConditionsProvider);
    final String? selectedCondition =
        ref.watch(selectedProgressConditionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Progress'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openLogSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Log Pain'),
      ),
      body: chartAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(progressChartProvider),
        ),
        data: (chart) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(progressChartProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                conditionsAsync.maybeWhen(
                  data: (conditions) {
                    if (conditions.isEmpty) return const SizedBox.shrink();

                    return DropdownButtonFormField<String?>(
                      value: selectedCondition,
                      decoration: const InputDecoration(
                        labelText: 'Condition',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All conditions'),
                        ),
                        ...conditions.map(
                          (condition) => DropdownMenuItem<String?>(
                            value: condition,
                            child: Text(condition),
                          ),
                        ),
                      ],
                      onChanged: (value) => ref
                          .read(selectedProgressConditionProvider.notifier)
                          .state = value,
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),

                const SizedBox(height: AppSpacing.md),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pain Level', style: theme.textTheme.titleMedium),
                            _TrendBadge(
                              trend: chart.trend,
                              label: chart.trendLabel,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        SizedBox(
                          height: 200,
                          child: chart.points.length < 2
                              ? Center(
                                  child: Text(
                                    'Log your pain level for a few days to see the trend.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                )
                              : _PainChart(points: chart.points),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                Row(
                  children: [
                    _StatCard(
                      value: '${chart.completedExercises}',
                      label: 'Exercises\nCompleted',
                      icon: Icons.check_circle_outline,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatCard(
                      value: '${chart.sessionsCompleted}',
                      label: 'Sessions\nCompleted',
                      icon: Icons.event_available_outlined,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatCard(
                      value: chart.currentPain?.toString() ?? '-',
                      label: 'Current\nPain Level',
                      icon: Icons.monitor_heart_outlined,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                if (chart.points.isNotEmpty) ...[
                  Text('Recent Entries', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),

                  // Newest first reads more naturally in a log list
                  ...chart.points.reversed.take(10).map((point) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor:
                              _painColor(point.painLevel).withValues(alpha: 0.15),
                          child: Text(
                            '${point.painLevel}',
                            style: TextStyle(
                              color: _painColor(point.painLevel),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          point.condition,
                          style: theme.textTheme.bodyMedium,
                        ),
                        subtitle: point.notes == null || point.notes!.isEmpty
                            ? null
                            : Text(
                                point.notes!,
                                style: theme.textTheme.bodySmall,
                              ),
                        trailing: Text(
                          DateFormat('d MMM').format(point.date),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Pain colour ramps from green through amber to red as severity rises.
Color _painColor(int painLevel) {
  if (painLevel <= 3) return AppColors.success;
  if (painLevel <= 6) return AppColors.warning;
  return AppColors.danger;
}

class _PainChart extends StatelessWidget {
  const _PainChart({required this.points});

  final List<ProgressPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 10,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.dividerColor,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              reservedSize: 28,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              // Only a handful of labels fit, so intermediate ones are skipped
              interval: (points.length / 5).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (value, _) {
                final int index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('d MMM').format(points[index].date),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((spot) {
              final point = points[spot.x.toInt()];
              return LineTooltipItem(
                'Pain ${point.painLevel}/10\n${DateFormat('d MMM').format(point.date)}',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              points.length,
              (index) => FlSpot(
                index.toDouble(),
                points[index].painLevel.toDouble(),
              ),
            ),
            isCurved: true,
            curveSmoothness: 0.28,
            color: theme.colorScheme.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3.5,
                color: _painColor(spot.y.toInt()),
                strokeWidth: 2,
                strokeColor: theme.colorScheme.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.trend, required this.label});

  final String trend;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ({Color color, IconData icon}) style = switch (trend) {
      'improving' => (color: AppColors.success, icon: Icons.trending_down),
      'worsening' => (color: AppColors.danger, icon: Icons.trending_up),
      'stable' => (color: AppColors.info, icon: Icons.trending_flat),
      _ => (color: Colors.grey, icon: Icons.help_outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: style.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 20),
              const SizedBox(height: 6),
              Text(value, style: theme.textTheme.titleLarge),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogPainSheet extends ConsumerStatefulWidget {
  const _LogPainSheet();

  @override
  ConsumerState<_LogPainSheet> createState() => _LogPainSheetState();
}

class _LogPainSheetState extends ConsumerState<_LogPainSheet> {
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  double _painLevel = 5;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _conditionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String condition = _conditionController.text.trim();

    if (condition.isEmpty) {
      AppSnackbar.error(context, 'Enter the condition you are tracking');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(progressRepositoryProvider).log(
            condition: condition,
            painLevel: _painLevel.round(),
            notes: _notesController.text.trim(),
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppSnackbar.error(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final conditionsAsync = ref.watch(progressConditionsProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Log Pain Level', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),

          TextField(
            controller: _conditionController,
            decoration: const InputDecoration(
              labelText: 'Condition',
              hintText: 'e.g. Back Pain',
            ),
          ),

          // Previously used conditions are offered as quick picks
          conditionsAsync.maybeWhen(
            data: (conditions) {
              if (conditions.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: conditions.map((condition) {
                    return ActionChip(
                      label: Text(condition, style: const TextStyle(fontSize: 12)),
                      onPressed: () =>
                          _conditionController.text = condition,
                    );
                  }).toList(),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          const SizedBox(height: AppSpacing.lg),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pain level', style: theme.textTheme.titleMedium),
              Text(
                '${_painLevel.round()} / 10',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: _painColor(_painLevel.round()),
                ),
              ),
            ],
          ),

          Slider(
            value: _painLevel,
            min: 0,
            max: 10,
            divisions: 10,
            activeColor: _painColor(_painLevel.round()),
            label: _painLevel.round().toString(),
            onChanged: (value) => setState(() => _painLevel = value),
          ),

          const SizedBox(height: AppSpacing.sm),

          TextField(
            controller: _notesController,
            maxLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'How did it feel today?',
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          AppButton(
            label: 'Save Entry',
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
