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

class ExerciseRepository {
  ExerciseRepository(this._api);

  final ApiClient _api;

  Future<List<ExerciseModel>> library({String? category}) async {
    final data = await _api.get<Map<String, dynamic>>(
      ApiRoutes.exercises,
      query: {
        'limit': 50,
        if (category != null) 'category': category,
      },
    );

    return (data['items'] as List<dynamic>)
        .map((e) => ExerciseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> categories() async {
    final data = await _api.get<List<dynamic>>(
      '${ApiRoutes.exercises}/categories',
    );

    return data.map((e) => e.toString()).toList();
  }
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepository(ref.watch(apiClientProvider));
});

final selectedCategoryProvider = StateProvider.autoDispose<String?>((ref) => null);

final exerciseCategoriesProvider =
    FutureProvider.autoDispose<List<String>>((ref) {
  return ref.watch(exerciseRepositoryProvider).categories();
});

final exerciseLibraryProvider =
    FutureProvider.autoDispose<List<ExerciseModel>>((ref) {
  final String? category = ref.watch(selectedCategoryProvider);
  return ref.watch(exerciseRepositoryProvider).library(category: category);
});
