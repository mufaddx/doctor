import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../appointments/data/appointment_model.dart';

/// Everything the summary screen needs to create and price a booking.
class BookingDraft {
  const BookingDraft({
    required this.therapistId,
    required this.type,
    required this.scheduledDate,
    required this.startTime,
    this.addressId,
    this.problem,
    this.notes,
    this.couponCode,
  });

  final String therapistId;
  final String type;
  final String scheduledDate;
  final String startTime;
  final String? addressId;
  final String? problem;
  final String? notes;
  final String? couponCode;

  Map<String, dynamic> toJson() => {
        'therapistId': therapistId,
        'type': type,
        'scheduledDate': scheduledDate,
        'startTime': startTime,
        if (addressId != null) 'addressId': addressId,
        if (problem != null && problem!.isNotEmpty) 'problem': problem,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (couponCode != null && couponCode!.isNotEmpty)
          'couponCode': couponCode,
      };

  BookingDraft copyWith({
    String? addressId,
    String? problem,
    String? notes,
    String? couponCode,
    bool clearCoupon = false,
  }) {
    return BookingDraft(
      therapistId: therapistId,
      type: type,
      scheduledDate: scheduledDate,
      startTime: startTime,
      addressId: addressId ?? this.addressId,
      problem: problem ?? this.problem,
      notes: notes ?? this.notes,
      couponCode: clearCoupon ? null : (couponCode ?? this.couponCode),
    );
  }
}

class CouponPreview {
  const CouponPreview({
    required this.code,
    required this.discountAmount,
    required this.payableAmount,
  });

  final String code;
  final double discountAmount;
  final double payableAmount;

  factory CouponPreview.fromJson(Map<String, dynamic> json) => CouponPreview(
        code: json['code'] as String,
        discountAmount:
            double.tryParse('${json['discountAmount'] ?? 0}') ?? 0,
        payableAmount: double.tryParse('${json['payableAmount'] ?? 0}') ?? 0,
      );
}

class AvailableCoupon {
  const AvailableCoupon({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    this.maxDiscount,
    this.minOrderValue,
    required this.validUntil,
  });

  final String id;
  final String code;
  final String type;
  final double value;
  final double? maxDiscount;
  final double? minOrderValue;
  final DateTime validUntil;

  factory AvailableCoupon.fromJson(Map<String, dynamic> json) =>
      AvailableCoupon(
        id: json['id'] as String,
        code: json['code'] as String,
        type: json['type'] as String,
        value: double.tryParse('${json['value'] ?? 0}') ?? 0,
        maxDiscount: json['maxDiscount'] == null
            ? null
            : double.tryParse('${json['maxDiscount']}'),
        minOrderValue: json['minOrderValue'] == null
            ? null
            : double.tryParse('${json['minOrderValue']}'),
        validUntil: DateTime.parse(json['validUntil'] as String),
      );

  /// Human-readable offer line, e.g. "30% off up to ₹150".
  String get description {
    if (type == 'PERCENTAGE') {
      final String cap =
          maxDiscount != null ? ' up to ₹${maxDiscount!.toStringAsFixed(0)}' : '';
      return '${value.toStringAsFixed(0)}% off$cap';
    }
    return '₹${value.toStringAsFixed(0)} off';
  }
}

class BookingRepository {
  BookingRepository(this._api);

  final ApiClient _api;

  /// Creates the appointment in PENDING state; payment happens next.
  Future<AppointmentModel> createAppointment(BookingDraft draft) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiRoutes.appointments,
      body: draft.toJson(),
    );

    return AppointmentModel.fromJson(data);
  }

  Future<List<AvailableCoupon>> availableCoupons() async {
    final data = await _api.get<List<dynamic>>(ApiRoutes.availableCoupons);

    return data
        .map((e) => AvailableCoupon.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Server-side preview so the displayed discount always matches what the
  /// backend will actually apply when the booking is created.
  Future<CouponPreview> previewCoupon(String code, double amount) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiRoutes.applyCoupon,
      body: {'code': code, 'amount': amount},
    );

    return CouponPreview.fromJson(data);
  }
}

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(ref.watch(apiClientProvider));
});

final availableCouponsProvider =
    FutureProvider.autoDispose<List<AvailableCoupon>>((ref) {
  return ref.watch(bookingRepositoryProvider).availableCoupons();
});
