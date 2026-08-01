/// Therapist as returned by the search and top-rated endpoints.
class TherapistModel {
  const TherapistModel({
    required this.id,
    required this.fullName,
    required this.specialization,
    required this.experienceYears,
    required this.clinicFee,
    required this.homeVisitFee,
    required this.videoFee,
    required this.ratingAvg,
    required this.ratingCount,
    this.userId,
    this.avatarUrl,
    this.bio,
    this.clinicAddress,
    this.isAvailable = true,
    this.distanceKm,
    this.completedAppointments = 0,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String? userId;
  final String fullName;
  final String? avatarUrl;
  final List<String> specialization;
  final int experienceYears;
  final double clinicFee;
  final double homeVisitFee;
  final double videoFee;
  final double ratingAvg;
  final int ratingCount;
  final String? bio;
  final String? clinicAddress;
  final bool isAvailable;
  final double? distanceKm;
  final int completedAppointments;
  final double? latitude;
  final double? longitude;

  factory TherapistModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return TherapistModel(
      id: json['id'] as String,
      userId: user?['id'] as String?,
      fullName: user?['fullName'] as String? ?? 'Therapist',
      avatarUrl: user?['avatarUrl'] as String?,
      specialization: (json['specialization'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      experienceYears: json['experienceYears'] as int? ?? 0,
      // Decimals arrive as strings so no precision is lost in transit
      clinicFee: double.tryParse('${json['clinicFee'] ?? 0}') ?? 0,
      homeVisitFee: double.tryParse('${json['homeVisitFee'] ?? 0}') ?? 0,
      videoFee: double.tryParse('${json['videoFee'] ?? 0}') ?? 0,
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 0,
      ratingCount: json['ratingCount'] as int? ?? 0,
      bio: json['bio'] as String?,
      clinicAddress: json['clinicAddress'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? true,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      completedAppointments: json['completedAppointments'] as int? ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  /// Cheapest of the three modes, shown as the "from" price in list cards.
  double get startingFee {
    final fees = [clinicFee, homeVisitFee, videoFee].where((f) => f > 0);
    return fees.isEmpty ? 0 : fees.reduce((a, b) => a < b ? a : b);
  }

  double feeForType(String type) => switch (type) {
        'CLINIC_VISIT' => clinicFee,
        'HOME_VISIT' => homeVisitFee,
        'VIDEO_CONSULTATION' => videoFee,
        _ => 0,
      };

  String get experienceLabel =>
      experienceYears > 0 ? '$experienceYears+ Yrs Exp.' : 'New';
}

/// Generic wrapper for every paginated list endpoint.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  final List<T> items;
  final int total;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};

    return Paginated<T>(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => parse(e as Map<String, dynamic>))
          .toList(),
      total: meta['total'] as int? ?? 0,
      page: meta['page'] as int? ?? 1,
      totalPages: meta['totalPages'] as int? ?? 1,
    );
  }
}
