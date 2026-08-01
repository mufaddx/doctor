class PrescribedMedicine {
  const PrescribedMedicine({
    required this.name,
    required this.dosage,
    this.frequency,
  });

  final String name;
  final String dosage;
  final String? frequency;

  factory PrescribedMedicine.fromJson(Map<String, dynamic> json) =>
      PrescribedMedicine(
        name: json['name'] as String? ?? '',
        dosage: json['dosage'] as String? ?? '',
        frequency: json['frequency'] as String?,
      );
}

class PrescriptionModel {
  const PrescriptionModel({
    required this.id,
    required this.diagnosis,
    required this.createdAt,
    required this.therapistName,
    required this.patientName,
    this.advice,
    this.pdfUrl,
    this.therapistAvatarUrl,
    this.medicines = const [],
    this.appointmentId,
    this.appointmentDate,
  });

  final String id;
  final String diagnosis;
  final String? advice;
  final String? pdfUrl;
  final DateTime createdAt;
  final List<PrescribedMedicine> medicines;

  final String therapistName;
  final String? therapistAvatarUrl;
  final String patientName;

  final String? appointmentId;
  final DateTime? appointmentDate;

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    final therapist = json['therapist'] as Map<String, dynamic>?;
    final therapistUser = therapist?['user'] as Map<String, dynamic>?;
    final patient = json['patient'] as Map<String, dynamic>?;
    final patientUser = patient?['user'] as Map<String, dynamic>?;
    final appointment = json['appointment'] as Map<String, dynamic>?;

    return PrescriptionModel(
      id: json['id'] as String,
      diagnosis: json['diagnosis'] as String? ?? '',
      advice: json['advice'] as String?,
      pdfUrl: json['pdfUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      medicines: (json['medicines'] as List<dynamic>? ?? [])
          .map((e) => PrescribedMedicine.fromJson(e as Map<String, dynamic>))
          .toList(),
      therapistName: therapistUser?['fullName'] as String? ?? 'Therapist',
      therapistAvatarUrl: therapistUser?['avatarUrl'] as String?,
      patientName: patientUser?['fullName'] as String? ?? 'Patient',
      appointmentId: appointment?['id'] as String?,
      appointmentDate: appointment?['scheduledDate'] == null
          ? null
          : DateTime.parse(appointment!['scheduledDate'] as String),
    );
  }
}
