/// Appointment from the therapist's perspective: the counterpart is the patient.
class AppointmentModel {
  const AppointmentModel({
    required this.id,
    required this.type,
    required this.status,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.consultationFee,
    required this.totalAmount,
    required this.patientId,
    required this.patientName,
    this.patientUserId,
    this.patientAvatarUrl,
    this.patientPhone,
    this.problem,
    this.notes,
    this.cancelReason,
    this.paymentStatus,
    this.prescriptionId,
  });

  final String id;
  final String type;
  final String status;
  final DateTime scheduledDate;
  final String startTime;
  final String endTime;
  final int durationMinutes;

  final double consultationFee;
  final double totalAmount;

  final String patientId;
  final String? patientUserId;
  final String patientName;
  final String? patientAvatarUrl;
  final String? patientPhone;

  final String? problem;
  final String? notes;
  final String? cancelReason;
  final String? paymentStatus;
  final String? prescriptionId;

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'] as Map<String, dynamic>?;
    final patientUser = patient?['user'] as Map<String, dynamic>?;
    final payment = json['payment'] as Map<String, dynamic>?;
    final prescription = json['prescription'] as Map<String, dynamic>?;

    return AppointmentModel(
      id: json['id'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      scheduledDate: DateTime.parse(json['scheduledDate'] as String),
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String? ?? '',
      durationMinutes: json['durationMinutes'] as int? ?? 30,
      consultationFee: double.tryParse('${json['consultationFee'] ?? 0}') ?? 0,
      totalAmount: double.tryParse('${json['totalAmount'] ?? 0}') ?? 0,
      patientId: patient?['id'] as String? ?? '',
      patientUserId: patientUser?['id'] as String?,
      patientName: patientUser?['fullName'] as String? ?? 'Patient',
      patientAvatarUrl: patientUser?['avatarUrl'] as String?,
      patientPhone: patientUser?['phone'] as String?,
      problem: json['problem'] as String?,
      notes: json['notes'] as String?,
      cancelReason: json['cancelReason'] as String?,
      paymentStatus: payment?['status'] as String?,
      prescriptionId: prescription?['id'] as String?,
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isVideo => type == 'VIDEO_CONSULTATION';
  bool get isPaid => paymentStatus == 'PAID';

  /// A prescription can only be written once the session has actually started.
  bool get canWritePrescription =>
      prescriptionId == null &&
      (status == 'IN_PROGRESS' ||
          status == 'CONFIRMED' ||
          status == 'COMPLETED');

  /// The room opens 15 minutes early and closes 15 minutes after the end.
  bool get canJoinCall {
    if (!isVideo) return false;
    if (status != 'CONFIRMED' && status != 'IN_PROGRESS') return false;

    final parts = startTime.split(':');
    final DateTime start = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    final DateTime now = DateTime.now();
    return now.isAfter(start.subtract(const Duration(minutes: 15))) &&
        now.isBefore(start.add(Duration(minutes: durationMinutes + 15)));
  }

  String get readableType => switch (type) {
    'CLINIC_VISIT' => 'Clinic Visit',
    'HOME_VISIT' => 'Home Visit',
    'VIDEO_CONSULTATION' => 'Video Consultation',
    _ => type,
  };

  String get readableStatus => switch (status) {
    'PENDING' => 'Awaiting Your Response',
    'CONFIRMED' => 'Confirmed',
    'IN_PROGRESS' => 'In Progress',
    'COMPLETED' => 'Completed',
    'CANCELLED' => 'Cancelled',
    'REJECTED' => 'Declined',
    'NO_SHOW' => 'No Show',
    _ => status,
  };

  String get displayTime {
    final parts = startTime.split(':');
    final int hour = int.parse(parts[0]);
    final String period = hour >= 12 ? 'PM' : 'AM';
    final int displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:${parts[1]} $period';
  }
}

class DashboardStats {
  const DashboardStats({
    required this.todayAppointments,
    required this.pendingRequests,
    required this.videoConsultations,
    required this.homeVisits,
  });

  final int todayAppointments;
  final int pendingRequests;
  final int videoConsultations;
  final int homeVisits;

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
    todayAppointments: json['todayAppointments'] as int? ?? 0,
    pendingRequests: json['pendingRequests'] as int? ?? 0,
    videoConsultations: json['videoConsultations'] as int? ?? 0,
    homeVisits: json['homeVisits'] as int? ?? 0,
  );
}
