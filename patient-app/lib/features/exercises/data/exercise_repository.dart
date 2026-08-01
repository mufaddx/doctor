import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';

class ExerciseModel {
  const ExerciseModel({
    required this.id,
    required this.title,
    required this.category,
    required this.level,
    required this.durationMinutes,
    required this.videoUrl,
    this.thumbnailUrl,
    this.instructions = const [],
  });

  final String id;
  final String title;
  final String category;
  final String level;
  final int durationMinutes;
  final String videoUrl;
  final String? thumbnailUrl;
  final List<String> instructions;

  factory ExerciseModel.fromJson(Map<String, dynamic> json) => ExerciseModel(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String? ?? '',
        level: json['level'] as String? ?? 'Beginner',
        durationMinutes: json['durationMinutes'] as int? ?? 0,
        videoUrl: json['videoUrl'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String?,
        instructions: (json['instructions'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// An exercise as assigned to this patient, carrying completion state.
class ExerciseAssignment {
  const ExerciseAssignment({
    required this.assignmentId,
    required this.exercise,
    required this.sets,
    required this.completed,
    required this.assignedAt,
    this.condition,
    this.completedAt,
  });

  final String assignmentId;
  final ExerciseModel exercise;
  final int sets;
  final bool completed;
  final String? condition;
  final DateTime assignedAt;
  final DateTime? completedAt;

  factory ExerciseAssignment.fromJson(Map<String, dynamic> json) =>
      ExerciseAssignment(
        assignmentId: json['assignmentId'] as String,
        exercise:
            ExerciseModel.fromJson(json['exercise'] as Map<String, dynamic>),
        sets: json['sets'] as int? ?? 3,
        completed: json['completed'] as bool? ?? false,
        condition: json['condition'] as String?,
        assignedAt: DateTime.parse(json['assignedAt'] as String),
        completedAt: json['completedAt'] == null
            ? null
            : DateTime.parse(json['completedAt'] as String),
      );
}

class ExercisePlan {
  const ExercisePlan({
    required this.assignments,
    required this.total,
    required this.completed,
    required this.sessionsLogged,
  });

  final List<ExerciseAssignment> assignments;
  final int total;
  final int completed;
  final int sessionsLogged;

  int get pending => total - completed;

  double get completionRatio => total == 0 ? 0 : completed / total;

  factory ExercisePlan.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? const {};

    return ExercisePlan(
      assignments: (json['assignments'] as List<dynamic>? ?? [])
          .map((e) => ExerciseAssignment.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: summary['total'] as int? ?? 0,
      completed: summary['completed'] as int? ?? 0,
      sessionsLogged: summary['sessionsLogged'] as int? ?? 0,
    );
  }
}

class ExerciseRepository {
  ExerciseRepository(this._api);

  final ApiClient _api;

  Future<List<ExerciseModel>> library({String? category, String? search}) async {
    final data = await _api.get<Map<String, dynamic>>(
      ApiRoutes.exercises,
      query: {
        'limit': 50,
        if (category != null) 'category': category,
        if (search != null && search.isNotEmpty) 'search': search,
      },
      skipAuth: true,
    );

    return (data['items'] as List<dynamic>)
        .map((e) => ExerciseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> categories() async {
    final data = await _api.get<List<dynamic>>(
      '${ApiRoutes.exercises}/categories',
      skipAuth: true,
    );

    return data.map((e) => e.toString()).toList();
  }

  Future<ExerciseModel> findOne(String id) async {
    final data = await _api.get<Map<String, dynamic>>(
      '${ApiRoutes.exercises}/$id',
      skipAuth: true,
    );

    return ExerciseModel.fromJson(data);
  }

  Future<ExercisePlan> myPlan() async {
    final data = await _api.get<Map<String, dynamic>>(ApiRoutes.myExercisePlan);
    return ExercisePlan.fromJson(data);
  }

  Future<void> markCompleted(String assignmentId) => _api.patch(
        '${ApiRoutes.exercises}/assignments/$assignmentId/complete',
      );
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepository(ref.watch(apiClientProvider));
});

final exerciseCategoriesProvider =
    FutureProvider.autoDispose<List<String>>((ref) {
  return ref.watch(exerciseRepositoryProvider).categories();
});

final selectedExerciseCategoryProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final exerciseLibraryProvider =
    FutureProvider.autoDispose<List<ExerciseModel>>((ref) {
  final String? category = ref.watch(selectedExerciseCategoryProvider);
  return ref.watch(exerciseRepositoryProvider).library(category: category);
});

final myExercisePlanProvider = FutureProvider.autoDispose<ExercisePlan>((ref) {
  return ref.watch(exerciseRepositoryProvider).myPlan();
});

final exerciseDetailProvider = FutureProvider.autoDispose
    .family<ExerciseModel, String>((ref, id) {
  return ref.watch(exerciseRepositoryProvider).findOne(id);
});
