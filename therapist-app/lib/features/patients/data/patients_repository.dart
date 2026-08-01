import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';

/// Row in the therapist's "My Patients" list, derived from their appointments.
class PatientSummary {
  const PatientSummary({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.phone,
    this.gender,
    this.age,
    this.lastAppointment,
    this.lastProblem,
  });

  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? phone;
  final String? gender;
  final int? age;
  final DateTime? lastAppointment;
  final String? lastProblem;

  factory PatientSummary.fromJson(Map<String, dynamic> json) => PatientSummary(
        id: json['id'] as String,
        fullName: json['fullName'] as String? ?? 'Patient',
        avatarUrl: json['avatarUrl'] as String?,
        phone: json['phone'] as String?,
        gender: json['gender'] as String?,
        age: json['age'] as int?,
        lastAppointment: json['lastAppointment'] == null
            ? null
            : DateTime.parse(json['lastAppointment'] as String),
        lastProblem: json['lastProblem'] as String?,
      );

  /// "Male, 28 Years" style subtitle; omits whichever field is missing.
  String get demographics => [
        if (gender != null) gender,
        if (age != null) '$age Years',
      ].join(', ');
}

class PatientAppointment {
  const PatientAppointment({
    required this.id,
    required this.type,
    required this.status,
    required this.scheduledDate,
    required this.startTime,
    this.problem,
  });

  final String id;
  final String type;
  final String status;
  final DateTime scheduledDate;
  final String startTime;
  final String? problem;

  factory PatientAppointment.fromJson(Map<String, dynamic> json) =>
      PatientAppointment(
        id: json['id'] as String,
        type: json['type'] as String,
        status: json['status'] as String,
        scheduledDate: DateTime.parse(json['scheduledDate'] as String),
        startTime: json['startTime'] as String,
        problem: json['problem'] as String?,
      );
}

class PatientPrescription {
  const PatientPrescription({
    required this.id,
    required this.diagnosis,
    required this.createdAt,
    this.advice,
    this.medicines = const [],
  });

  final String id;
  final String diagnosis;
  final String? advice;
  final List<Map<String, dynamic>> medicines;
  final DateTime createdAt;

  factory PatientPrescription.fromJson(Map<String, dynamic> json) =>
      PatientPrescription(
        id: json['id'] as String,
        diagnosis: json['diagnosis'] as String? ?? '',
        advice: json['advice'] as String?,
        medicines: (json['medicines'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class PatientProgressEntry {
  const PatientProgressEntry({
    required this.id,
    required this.condition,
    required this.painLevel,
    required this.loggedAt,
  });

  final String id;
  final String condition;
  final int painLevel;
  final DateTime loggedAt;

  factory PatientProgressEntry.fromJson(Map<String, dynamic> json) =>
      PatientProgressEntry(
        id: json['id'] as String,
        condition: json['condition'] as String? ?? '',
        painLevel: json['painLevel'] as int? ?? 0,
        loggedAt: DateTime.parse(json['loggedAt'] as String),
      );
}

/// Full clinical picture shown on the patient profile screen.
class PatientHistory {
  const PatientHistory({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.phone,
    this.gender,
    this.dateOfBirth,
    this.medicalHistory,
    this.appointments = const [],
    this.prescriptions = const [],
    this.progressLogs = const [],
  });

  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? phone;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? medicalHistory;

  final List<PatientAppointment> appointments;
  final List<PatientPrescription> prescriptions;
  final List<PatientProgressEntry> progressLogs;

  int? get age {
    if (dateOfBirth == null) return null;
    return (DateTime.now().difference(dateOfBirth!).inDays / 365.25).floor();
  }

  /// Most recent pain reading, shown as the headline vital.
  int? get currentPainLevel =>
      progressLogs.isEmpty ? null : progressLogs.first.painLevel;

  int get completedSessions =>
      appointments.where((a) => a.status == 'COMPLETED').length;

  factory PatientHistory.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return PatientHistory(
      id: json['id'] as String,
      fullName: user?['fullName'] as String? ?? 'Patient',
      avatarUrl: user?['avatarUrl'] as String?,
      phone: user?['phone'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: json['dateOfBirth'] == null
          ? null
          : DateTime.parse(json['dateOfBirth'] as String),
      medicalHistory: json['medicalHistory'] as String?,
      appointments: (json['appointments'] as List<dynamic>? ?? [])
          .map((e) => PatientAppointment.fromJson(e as Map<String, dynamic>))
          .toList(),
      prescriptions: (json['prescriptions'] as List<dynamic>? ?? [])
          .map((e) => PatientPrescription.fromJson(e as Map<String, dynamic>))
          .toList(),
      progressLogs: (json['progressLogs'] as List<dynamic>? ?? [])
          .map((e) => PatientProgressEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PatientsRepository {
  PatientsRepository(this._api);

  final ApiClient _api;

  Future<List<PatientSummary>> myPatients({String? search}) async {
    final data = await _api.get<List<dynamic>>(
      ApiRoutes.myPatients,
      query: {if (search != null && search.isNotEmpty) 'search': search},
    );

    return data
        .map((e) => PatientSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PatientHistory> history(String patientId) async {
    final data = await _api.get<Map<String, dynamic>>(
      ApiRoutes.patientHistory(patientId),
    );

    return PatientHistory.fromJson(data);
  }
}

final patientsRepositoryProvider = Provider<PatientsRepository>((ref) {
  return PatientsRepository(ref.watch(apiClientProvider));
});

final patientSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final myPatientsProvider =
    FutureProvider.autoDispose<List<PatientSummary>>((ref) {
  final String search = ref.watch(patientSearchProvider);
  return ref.watch(patientsRepositoryProvider).myPatients(search: search);
});

final patientHistoryProvider =
    FutureProvider.autoDispose.family<PatientHistory, String>((ref, patientId) {
  return ref.watch(patientsRepositoryProvider).history(patientId);
});
