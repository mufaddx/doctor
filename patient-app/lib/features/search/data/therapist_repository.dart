import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';
import 'therapist_model.dart';

/// Filters bound to the search screen's filter sheet.
class TherapistFilters {
  const TherapistFilters({
    this.search,
    this.specialization = const [],
    this.minRating,
    this.minExperience,
    this.maxFee,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.sortBy = 'ratingAvg',
    this.sortOrder = 'desc',
  });

  final String? search;
  final List<String> specialization;
  final double? minRating;
  final int? minExperience;
  final double? maxFee;
  final double? latitude;
  final double? longitude;
  final double? radiusKm;
  final String sortBy;
  final String sortOrder;

  bool get hasActiveFilters =>
      specialization.isNotEmpty ||
      minRating != null ||
      minExperience != null ||
      maxFee != null ||
      radiusKm != null;

  /// Count shown on the filter badge.
  int get activeCount => [
        specialization.isNotEmpty,
        minRating != null,
        minExperience != null,
        maxFee != null,
        radiusKm != null,
      ].where((active) => active).length;

  Map<String, dynamic> toQuery(int page) => {
        'page': page,
        'limit': AppConfig.pageSize,
        'sortBy': sortBy,
        'sortOrder': sortOrder,
        if (search != null && search!.isNotEmpty) 'search': search,
        if (specialization.isNotEmpty) 'specialization': specialization,
        if (minRating != null) 'minRating': minRating,
        if (minExperience != null) 'minExperience': minExperience,
        if (maxFee != null) 'maxFee': maxFee,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (radiusKm != null) 'radiusKm': radiusKm,
      };

  TherapistFilters copyWith({
    String? search,
    List<String>? specialization,
    double? minRating,
    int? minExperience,
    double? maxFee,
    double? latitude,
    double? longitude,
    double? radiusKm,
    String? sortBy,
    String? sortOrder,
    bool clearFilters = false,
  }) {
    if (clearFilters) {
      return TherapistFilters(
        search: search ?? this.search,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );
    }

    return TherapistFilters(
      search: search ?? this.search,
      specialization: specialization ?? this.specialization,
      minRating: minRating ?? this.minRating,
      minExperience: minExperience ?? this.minExperience,
      maxFee: maxFee ?? this.maxFee,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusKm: radiusKm ?? this.radiusKm,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class TherapistRepository {
  TherapistRepository(this._api);

  final ApiClient _api;

  Future<Paginated<TherapistModel>> search(
    TherapistFilters filters, {
    int page = 1,
  }) async {
    final data = await _api.get<Map<String, dynamic>>(
      ApiRoutes.therapists,
      query: filters.toQuery(page),
      skipAuth: true,
    );

    return Paginated.fromJson(data, TherapistModel.fromJson);
  }

  Future<List<TherapistModel>> topRated() async {
    final data = await _api.get<List<dynamic>>(
      ApiRoutes.topRatedTherapists,
      skipAuth: true,
    );

    return data
        .map((e) => TherapistModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TherapistDetail> findOne(String therapistId) async {
    final data = await _api.get<Map<String, dynamic>>(
      '${ApiRoutes.therapists}/$therapistId',
      skipAuth: true,
    );

    return TherapistDetail.fromJson(data);
  }

  /// Free 30-minute slots for a specific day.
  Future<List<TimeSlot>> availableSlots(String therapistId, DateTime date) async {
    final String formatted =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final data = await _api.get<Map<String, dynamic>>(
      ApiRoutes.slots(therapistId),
      query: {'date': formatted},
      skipAuth: true,
    );

    return (data['slots'] as List<dynamic>)
        .map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Full profile, which adds reviews, certificates and weekly availability.
class TherapistDetail extends TherapistModel {
  const TherapistDetail({
    required super.id,
    required super.fullName,
    required super.specialization,
    required super.experienceYears,
    required super.clinicFee,
    required super.homeVisitFee,
    required super.videoFee,
    required super.ratingAvg,
    required super.ratingCount,
    super.userId,
    super.avatarUrl,
    super.bio,
    super.clinicAddress,
    super.isAvailable,
    super.completedAppointments,
    super.latitude,
    super.longitude,
    this.reviews = const [],
    this.certificates = const [],
  });

  final List<TherapistReview> reviews;
  final List<String> certificates;

  factory TherapistDetail.fromJson(Map<String, dynamic> json) {
    final base = TherapistModel.fromJson(json);

    return TherapistDetail(
      id: base.id,
      userId: base.userId,
      fullName: base.fullName,
      avatarUrl: base.avatarUrl,
      specialization: base.specialization,
      experienceYears: base.experienceYears,
      clinicFee: base.clinicFee,
      homeVisitFee: base.homeVisitFee,
      videoFee: base.videoFee,
      ratingAvg: base.ratingAvg,
      ratingCount: base.ratingCount,
      bio: base.bio,
      clinicAddress: base.clinicAddress,
      isAvailable: base.isAvailable,
      completedAppointments: base.completedAppointments,
      latitude: base.latitude,
      longitude: base.longitude,
      reviews: (json['reviews'] as List<dynamic>? ?? [])
          .map((e) => TherapistReview.fromJson(e as Map<String, dynamic>))
          .toList(),
      certificates: (json['certificates'] as List<dynamic>? ?? [])
          .map((e) => (e as Map<String, dynamic>)['title'].toString())
          .toList(),
    );
  }
}

class TherapistReview {
  const TherapistReview({
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

  factory TherapistReview.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;

    return TherapistReview(
      id: json['id'] as String,
      rating: json['rating'] as int? ?? 0,
      authorName: author?['fullName'] as String? ?? 'Patient',
      authorAvatarUrl: author?['avatarUrl'] as String?,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class TimeSlot {
  const TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.available,
  });

  final String startTime;
  final String endTime;
  final bool available;

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String,
        available: json['available'] as bool? ?? false,
      );

  /// Converts 24-hour "14:30" into the "02:30 PM" the UI displays.
  String get displayTime {
    final parts = startTime.split(':');
    final int hour = int.parse(parts[0]);
    final String period = hour >= 12 ? 'PM' : 'AM';
    final int displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:${parts[1]} $period';
  }
}

final therapistRepositoryProvider = Provider<TherapistRepository>((ref) {
  return TherapistRepository(ref.watch(apiClientProvider));
});
