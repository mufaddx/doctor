/// Immutable view of the authenticated user, mirroring the API payload.
class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    this.email,
    this.avatarUrl,
    this.isVerified = false,
    this.walletBalance = 0,
    this.patient,
  });

  final String id;
  final String fullName;
  final String phone;
  final String role;
  final String? email;
  final String? avatarUrl;
  final bool isVerified;
  final double walletBalance;
  final PatientProfile? patient;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final wallet = json['wallet'] as Map<String, dynamic>?;

    return UserModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'PATIENT',
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      // The API returns Decimal as a string to avoid float rounding
      walletBalance:
          double.tryParse('${wallet?['balance'] ?? 0}') ?? 0,
      patient: json['patient'] == null
          ? null
          : PatientProfile.fromJson(json['patient'] as Map<String, dynamic>),
    );
  }

  /// Initials used by the avatar fallback when no photo is set.
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  UserModel copyWith({
    String? fullName,
    String? email,
    String? avatarUrl,
    double? walletBalance,
    PatientProfile? patient,
  }) {
    return UserModel(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone,
      role: role,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified,
      walletBalance: walletBalance ?? this.walletBalance,
      patient: patient ?? this.patient,
    );
  }
}

class PatientProfile {
  const PatientProfile({
    required this.id,
    required this.referralCode,
    this.dateOfBirth,
    this.gender,
    this.medicalHistory,
    this.addresses = const [],
  });

  final String id;
  final String referralCode;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? medicalHistory;
  final List<AddressModel> addresses;

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      id: json['id'] as String,
      referralCode: json['referralCode'] as String? ?? '',
      dateOfBirth: json['dateOfBirth'] == null
          ? null
          : DateTime.parse(json['dateOfBirth'] as String),
      gender: json['gender'] as String?,
      medicalHistory: json['medicalHistory'] as String?,
      addresses: (json['addresses'] as List<dynamic>? ?? [])
          .map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  int? get age {
    if (dateOfBirth == null) return null;
    final diff = DateTime.now().difference(dateOfBirth!);
    return (diff.inDays / 365.25).floor();
  }
}

class AddressModel {
  const AddressModel({
    required this.id,
    required this.label,
    required this.line1,
    required this.city,
    required this.state,
    required this.pincode,
    this.line2,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String pincode;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'] as String,
      label: json['label'] as String? ?? 'Address',
      line1: json['line1'] as String? ?? '',
      line2: json['line2'] as String?,
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  String get formatted => [
        line1,
        if (line2 != null && line2!.isNotEmpty) line2,
        city,
        '$state $pincode',
      ].join(', ');

  Map<String, dynamic> toJson() => {
        'label': label,
        'line1': line1,
        if (line2 != null) 'line2': line2,
        'city': city,
        'state': state,
        'pincode': pincode,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'isDefault': isDefault,
      };
}
