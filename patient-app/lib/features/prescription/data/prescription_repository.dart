import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';
import 'prescription_model.dart';

class PrescriptionRepository {
  PrescriptionRepository(this._api);

  final ApiClient _api;

  Future<PrescriptionModel> findOne(String id) async {
    final data = await _api.get<Map<String, dynamic>>(
      '${ApiRoutes.prescriptions}/$id',
    );

    return PrescriptionModel.fromJson(data);
  }
}

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>((ref) {
  return PrescriptionRepository(ref.watch(apiClientProvider));
});

final prescriptionProvider = FutureProvider.autoDispose
    .family<PrescriptionModel, String>((ref, id) {
  return ref.watch(prescriptionRepositoryProvider).findOne(id);
});
