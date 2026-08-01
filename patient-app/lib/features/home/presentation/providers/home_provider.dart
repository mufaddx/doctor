import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/network/api_client.dart';

class BannerModel {
  const BannerModel({
    required this.id,
    required this.imageUrl,
    this.title,
    this.linkUrl,
  });

  final String id;
  final String imageUrl;
  final String? title;
  final String? linkUrl;

  factory BannerModel.fromJson(Map<String, dynamic> json) => BannerModel(
        id: json['id'] as String,
        imageUrl: json['imageUrl'] as String,
        title: json['title'] as String?,
        linkUrl: json['linkUrl'] as String?,
      );
}

class HomeRepository {
  HomeRepository(this._api);

  final ApiClient _api;

  Future<List<BannerModel>> banners() async {
    final data = await _api.get<List<dynamic>>(
      ApiRoutes.banners,
      skipAuth: true,
    );

    return data
        .map((e) => BannerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(apiClientProvider));
});

final bannersProvider = FutureProvider.autoDispose<List<BannerModel>>((ref) {
  return ref.watch(homeRepositoryProvider).banners();
});
