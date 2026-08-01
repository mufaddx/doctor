import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';
import 'appointment_model.dart';

class AppointmentsRepository {
  AppointmentsRepository(this._api);

  final ApiClient _api;

  Future<List<AppointmentModel>> list({String? status, int page = 1}) async {
    final data = await _api.get<Map<String, dynamic>>(
      ApiRoutes.appointments,
      query: {
        'page': page,
        'limit': AppConfig.pageSize,
        if (status != null) 'status': status,
      },
    );

    return (data['items'] as List<dynamic>)
        .map((e) => AppointmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AppointmentModel>> todaySchedule() async {
    final data = await _api.get<List<dynamic>>(ApiRoutes.todaySchedule);

    return data
        .map((e) => AppointmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DashboardStats> stats() async {
    final data = await _api.get<Map<String, dynamic>>(ApiRoutes.dashboardStats);
    return DashboardStats.fromJson(data);
  }

  Future<AppointmentModel> findOne(String id) async {
    final data = await _api.get<Map<String, dynamic>>(
      '${ApiRoutes.appointments}/$id',
    );

    return AppointmentModel.fromJson(data);
  }

  Future<AppointmentModel> accept(String id) async {
    final data = await _api.patch<Map<String, dynamic>>(
      '${ApiRoutes.appointments}/$id/accept',
    );

    return AppointmentModel.fromJson(data);
  }

  Future<AppointmentModel> reject(String id, String reason) async {
    final data = await _api.patch<Map<String, dynamic>>(
      '${ApiRoutes.appointments}/$id/reject',
      body: {'reason': reason},
    );

    return AppointmentModel.fromJson(data);
  }

  Future<AppointmentModel> cancel(String id, String reason) async {
    final data = await _api.patch<Map<String, dynamic>>(
      '${ApiRoutes.appointments}/$id/cancel',
      body: {'reason': reason},
    );

    return AppointmentModel.fromJson(data);
  }

  Future<AppointmentModel> start(String id) async {
    final data = await _api.patch<Map<String, dynamic>>(
      '${ApiRoutes.appointments}/$id/start',
    );

    return AppointmentModel.fromJson(data);
  }

  Future<AppointmentModel> complete(String id) async {
    final data = await _api.patch<Map<String, dynamic>>(
      '${ApiRoutes.appointments}/$id/complete',
    );

    return AppointmentModel.fromJson(data);
  }
}

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  return AppointmentsRepository(ref.watch(apiClientProvider));
});
