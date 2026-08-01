import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';

class ProgressPoint {
  const ProgressPoint({
    required this.date,
    required this.painLevel,
    required this.condition,
    this.notes,
  });

  final DateTime date;
  final int painLevel;
  final String condition;
  final String? notes;

  factory ProgressPoint.fromJson(Map<String, dynamic> json) => ProgressPoint(
        date: DateTime.parse(json['date'] as String),
        painLevel: json['painLevel'] as int? ?? 0,
        condition: json['condition'] as String? ?? '',
        notes: json['notes'] as String?,
      );
}

class ProgressChart {
  const ProgressChart({
    required this.points,
    required this.completedExercises,
    required this.pendingExercises,
    required this.sessionsCompleted,
    required this.trend,
    required this.changePercent,
    this.currentPain,
  });

  final List<ProgressPoint> points;
  final int completedExercises;
  final int pendingExercises;
  final int sessionsCompleted;

  /// One of improving, stable, worsening or insufficient_data.
  final String trend;
  final double changePercent;
  final int? currentPain;

  factory ProgressChart.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? const {};

    return ProgressChart(
      points: (json['points'] as List<dynamic>? ?? [])
          .map((e) => ProgressPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      completedExercises: summary['completedExercises'] as int? ?? 0,
      pendingExercises: summary['pendingExercises'] as int? ?? 0,
      sessionsCompleted: summary['sessionsCompleted'] as int? ?? 0,
      trend: summary['trend'] as String? ?? 'insufficient_data',
      changePercent: (summary['changePercent'] as num?)?.toDouble() ?? 0,
      currentPain: summary['currentPain'] as int?,
    );
  }

  String get trendLabel => switch (trend) {
        'improving' => 'Improving',
        'worsening' => 'Needs attention',
        'stable' => 'Stable',
        _ => 'Not enough data',
      };
}

class ProgressRepository {
  ProgressRepository(this._api);

  final ApiClient _api;

  Future<ProgressChart> chart({String? condition, int days = 30}) async {
    final data = await _api.get<Map<String, dynamic>>(
      ApiRoutes.progressChart,
      query: {'days': days, if (condition != null) 'condition': condition},
    );

    return ProgressChart.fromJson(data);
  }

  Future<List<String>> conditions() async {
    final data = await _api.get<List<dynamic>>('${ApiRoutes.progress}/conditions');
    return data.map((e) => e.toString()).toList();
  }

  Future<void> log({
    required String condition,
    required int painLevel,
    String? notes,
  }) {
    return _api.post(
      ApiRoutes.progress,
      body: {
        'condition': condition,
        'painLevel': painLevel,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(ref.watch(apiClientProvider));
});

final progressConditionsProvider =
    FutureProvider.autoDispose<List<String>>((ref) {
  return ref.watch(progressRepositoryProvider).conditions();
});

final selectedProgressConditionProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final progressChartProvider =
    FutureProvider.autoDispose<ProgressChart>((ref) {
  final String? condition = ref.watch(selectedProgressConditionProvider);
  return ref.watch(progressRepositoryProvider).chart(condition: condition);
});
