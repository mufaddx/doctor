/// Appointment as returned by the API, shared across booking, list and detail.
class AppointmentModel {
  const AppointmentModel({
    required this.id,
    required this.type,
    required this.status,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
    required this.consultationFee,
    required this.platformFee,
    required this.discountAmount,
    required this.totalAmount,
    required this.therapistId,
    required this.therapistName,
    this.therapistUserId,
    this.therapistAvatarUrl,
    this.specialization = const [],
    this.problem,
    this.notes,
    this.cancelReason,
    this.paymentStatus,
    this.prescriptionId,
    this.hasReview = false,
    this.durationMinutes = 30,
  });

  final String id;
  final String type;
  final String status;
  final DateTime scheduledDate;
  final String startTime;
  final String endTime;
  final int durationMinutes;

  final double consultationFee;
  final double platformFee;
  final double discountAmount;
  final double totalAmount;

  final String therapistId;
  final String? therapistUserId;
  final String therapistName;
  final String? therapistAvatarUrl;
  final List<String> specialization;

  final String? problem;
  final String? notes;
  final String? cancelReason;
  final String? paymentStatus;
  final String? prescriptionId;
  final bool hasReview;

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    final therapist = json['therapist'] as Map<String, dynamic>?;
    final therapistUser = therapist?['user'] as Map<String, dynamic>?;
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
      platformFee: double.tryParse('${json['platformFee'] ?? 0}') ?? 0,
      discountAmount: double.tryParse('${json['discountAmount'] ?? 0}') ?? 0,
      totalAmount: double.tryParse('${json['totalAmount'] ?? 0}') ?? 0,
      therapistId: therapist?['id'] as String? ?? '',
      therapistUserId: therapistUser?['id'] as String?,
      therapistName: therapistUser?['fullName'] as String? ?? 'Therapist',
      therapistAvatarUrl: therapistUser?['avatarUrl'] as String?,
      specialization: (therapist?['specialization'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      problem: json['problem'] as String?,
      notes: json['notes'] as String?,
      cancelReason: json['cancelReason'] as String?,
      paymentStatus: payment?['status'] as String?,
      prescriptionId: prescription?['id'] as String?,
      hasReview: json['review'] != null,
    );
  }

  bool get isPaid => paymentStatus == 'PAID';

  bool get isUpcoming =>
      status == 'PENDING' || status == 'CONFIRMED' || status == 'IN_PROGRESS';

  bool get isCompleted => status == 'COMPLETED';

  bool get isCancelled => status == 'CANCELLED' || status == 'REJECTED';

  bool get isVideo => type == 'VIDEO_CONSULTATION';

  /// The video room only opens 15 minutes before the scheduled start.
  bool get canJoinCall {
    if (!isVideo || !isPaid) return false;
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

  /// Free cancellation applies at least 12 hours before the start.
  bool get isFreeCancellation {
    final parts = startTime.split(':');
    final DateTime start = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    return start.difference(DateTime.now()).inHours >= 12;
  }

  String get readableType => switch (type) {
        'CLINIC_VISIT' => 'Clinic Visit',
        'HOME_VISIT' => 'Home Visit',
        'VIDEO_CONSULTATION' => 'Video Consultation',
        _ => type,
      };

  String get readableStatus => switch (status) {
        'PENDING' => 'Awaiting Confirmation',
        'CONFIRMED' => 'Confirmed',
        'IN_PROGRESS' => 'In Progress',
        'COMPLETED' => 'Completed',
        'CANCELLED' => 'Cancelled',
        'REJECTED' => 'Declined',
        'NO_SHOW' => 'No Show',
        _ => status,
      };

  /// "09:00" formatted as "09:00 AM" for display.
  String get displayTime {
    final parts = startTime.split(':');
    final int hour = int.parse(parts[0]);
    final String period = hour >= 12 ? 'PM' : 'AM';
    final int displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:${parts[1]} $period';
  }
}
