import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';

/// Response from order creation. Wallet payments come back already settled,
/// so the UI must not open the gateway for them.
class PaymentOrder {
  const PaymentOrder({
    required this.paymentId,
    required this.amount,
    this.razorpayOrderId,
    this.razorpayKeyId,
    this.status,
  });

  final String paymentId;
  final double amount;
  final String? razorpayOrderId;
  final String? razorpayKeyId;
  final String? status;

  bool get isSettled => status == 'PAID' || razorpayOrderId == null;

  factory PaymentOrder.fromJson(Map<String, dynamic> json) => PaymentOrder(
        paymentId: json['paymentId'] as String,
        amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
        razorpayOrderId: json['razorpayOrderId'] as String?,
        razorpayKeyId: json['razorpayKeyId'] as String?,
        status: json['status'] as String?,
      );
}

class PaymentRepository {
  PaymentRepository(this._api);

  final ApiClient _api;

  Future<PaymentOrder> createOrder({
    required String appointmentId,
    required String method,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiRoutes.paymentOrder,
      body: {'appointmentId': appointmentId, 'method': method},
    );

    return PaymentOrder.fromJson(data);
  }

  Future<void> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) {
    return _api.post(
      ApiRoutes.paymentVerify,
      body: {
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      },
    );
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(apiClientProvider));
});
