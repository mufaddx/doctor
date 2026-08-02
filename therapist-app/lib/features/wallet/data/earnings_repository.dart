import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';

class EarningsSummary {
  const EarningsSummary({
    required this.period,
    required this.totalEarnings,
    required this.previousPeriodEarnings,
    required this.changePercent,
    required this.sessionCount,
    required this.clinicVisit,
    required this.homeVisit,
    required this.videoConsultation,
  });

  final String period;
  final double totalEarnings;
  final double previousPeriodEarnings;
  final double changePercent;
  final int sessionCount;

  final double clinicVisit;
  final double homeVisit;
  final double videoConsultation;

  bool get isUp => changePercent >= 0;

  factory EarningsSummary.fromJson(Map<String, dynamic> json) {
    final breakdown = json['breakdown'] as Map<String, dynamic>? ?? const {};

    return EarningsSummary(
      period: json['period'] as String? ?? 'daily',
      totalEarnings: (json['totalEarnings'] as num?)?.toDouble() ?? 0,
      previousPeriodEarnings:
          (json['previousPeriodEarnings'] as num?)?.toDouble() ?? 0,
      changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0,
      sessionCount: json['sessionCount'] as int? ?? 0,
      clinicVisit: (breakdown['clinicVisit'] as num?)?.toDouble() ?? 0,
      homeVisit: (breakdown['homeVisit'] as num?)?.toDouble() ?? 0,
      videoConsultation:
          (breakdown['videoConsultation'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PayoutRecord {
  const PayoutRecord({
    required this.id,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.processedAt,
  });

  final String id;
  final double amount;
  final String status;
  final DateTime createdAt;
  final DateTime? processedAt;

  factory PayoutRecord.fromJson(Map<String, dynamic> json) => PayoutRecord(
    id: json['id'] as String,
    amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
    status: json['status'] as String? ?? 'PENDING',
    createdAt: DateTime.parse(json['createdAt'] as String),
    processedAt: json['processedAt'] == null
        ? null
        : DateTime.parse(json['processedAt'] as String),
  );
}

class EarningsRepository {
  EarningsRepository(this._api);

  final ApiClient _api;

  Future<EarningsSummary> earnings(String period) async {
    final data = await _api.get<Map<String, dynamic>>(
      ApiRoutes.earnings,
      query: {'period': period},
    );

    return EarningsSummary.fromJson(data);
  }

  Future<List<PayoutRecord>> payouts() async {
    final data = await _api.get<Map<String, dynamic>>(
      ApiRoutes.payouts,
      query: {'limit': AppConfig.pageSize},
    );

    return (data['items'] as List<dynamic>)
        .map((e) => PayoutRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final earningsRepositoryProvider = Provider<EarningsRepository>((ref) {
  return EarningsRepository(ref.watch(apiClientProvider));
});

final selectedPeriodProvider = StateProvider.autoDispose<String>(
  (ref) => 'daily',
);

final earningsProvider = FutureProvider.autoDispose<EarningsSummary>((ref) {
  final String period = ref.watch(selectedPeriodProvider);
  return ref.watch(earningsRepositoryProvider).earnings(period);
});

final payoutsProvider = FutureProvider.autoDispose<List<PayoutRecord>>((ref) {
  return ref.watch(earningsRepositoryProvider).payouts();
});
