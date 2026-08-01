import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.source,
    required this.amount,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String type;
  final String source;
  final double amount;
  final String? description;
  final DateTime createdAt;

  bool get isCredit => type == 'CREDIT';

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] as String,
        type: json['type'] as String,
        source: json['source'] as String? ?? '',
        amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  String get readableSource => switch (source) {
        'APPOINTMENT_PAYMENT' => 'Payment for Appointment',
        'REFUND' => 'Refund',
        'REFERRAL_BONUS' => 'Referral Bonus',
        'WALLET_TOPUP' => 'Money Added',
        'PAYOUT' => 'Payout',
        _ => 'Adjustment',
      };
}

class ReferralInfo {
  const ReferralInfo({
    required this.referralCode,
    required this.referredCount,
    required this.bonusPerReferral,
  });

  final String referralCode;
  final int referredCount;
  final double bonusPerReferral;

  double get totalEarned => referredCount * bonusPerReferral;

  factory ReferralInfo.fromJson(Map<String, dynamic> json) => ReferralInfo(
        referralCode: json['referralCode'] as String? ?? '',
        referredCount: json['referredCount'] as int? ?? 0,
        bonusPerReferral:
            double.tryParse('${json['bonusPerReferral'] ?? 0}') ?? 0,
      );
}

class WalletRepository {
  WalletRepository(this._api);

  final ApiClient _api;

  Future<double> balance() async {
    final data = await _api.get<Map<String, dynamic>>(ApiRoutes.walletBalance);
    return double.tryParse('${data['balance'] ?? 0}') ?? 0;
  }

  Future<List<WalletTransaction>> transactions({int page = 1}) async {
    final data = await _api.get<Map<String, dynamic>>(
      ApiRoutes.walletTransactions,
      query: {'page': page, 'limit': AppConfig.pageSize},
    );

    return (data['items'] as List<dynamic>)
        .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ReferralInfo> referralInfo() async {
    final data = await _api.get<Map<String, dynamic>>(ApiRoutes.referral);
    return ReferralInfo.fromJson(data);
  }

  /// Applies someone else's code to this account; the bonus goes to them.
  Future<String> applyReferralCode(String code) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiRoutes.applyReferral,
      body: {'referralCode': code},
    );

    return data['message'] as String? ?? 'Referral applied';
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(apiClientProvider));
});

final walletBalanceProvider = FutureProvider.autoDispose<double>((ref) {
  return ref.watch(walletRepositoryProvider).balance();
});

final walletTransactionsProvider =
    FutureProvider.autoDispose<List<WalletTransaction>>((ref) {
  return ref.watch(walletRepositoryProvider).transactions();
});

final referralInfoProvider = FutureProvider.autoDispose<ReferralInfo>((ref) {
  return ref.watch(walletRepositoryProvider).referralInfo();
});
