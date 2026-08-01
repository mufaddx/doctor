import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/user_model.dart';

class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  Future<void> updateProfile({
    String? fullName,
    String? email,
    String? dateOfBirth,
    String? gender,
    String? medicalHistory,
  }) {
    return _api.patch(
      ApiRoutes.me,
      body: {
        if (fullName != null) 'fullName': fullName,
        if (email != null && email.isNotEmpty) 'email': email,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
        if (gender != null) 'gender': gender,
        if (medicalHistory != null) 'medicalHistory': medicalHistory,
      },
    );
  }

  Future<String> uploadAvatar(String filePath) async {
    final data = await _api.upload<Map<String, dynamic>>(
      ApiRoutes.avatar,
      filePath: filePath,
    );

    return data['avatarUrl'] as String;
  }

  Future<List<AddressModel>> addresses() async {
    final data = await _api.get<List<dynamic>>(ApiRoutes.addresses);

    return data
        .map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AddressModel> createAddress(AddressModel address) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiRoutes.addresses,
      body: address.toJson(),
    );

    return AddressModel.fromJson(data);
  }

  Future<AddressModel> updateAddress(String id, AddressModel address) async {
    final data = await _api.patch<Map<String, dynamic>>(
      '${ApiRoutes.addresses}/$id',
      body: address.toJson(),
    );

    return AddressModel.fromJson(data);
  }

  Future<void> deleteAddress(String id) =>
      _api.delete('${ApiRoutes.addresses}/$id');
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

final addressesProvider = FutureProvider.autoDispose<List<AddressModel>>((ref) {
  return ref.watch(profileRepositoryProvider).addresses();
});
