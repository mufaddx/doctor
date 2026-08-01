import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../search/data/therapist_model.dart';
import 'appointment_model.dart';

class AppointmentsRepository {
  AppointmentsRepository(this._api);

  final ApiClient _api;

  Future<Paginated<AppointmentModel>> list({
    String? status,
    int page = 1,
  }) async {
    final data = await _api.get<Map<String, dynamic>>(
      ApiRoutes.appointments,
      query: {
        'page': page,
        'limit': AppConfig.pageSize,
        if (status != null) 'status': status,
      },
    );

    return Paginated.fromJson(data, AppointmentModel.fromJson);
  }

  Future<AppointmentModel> findOne(String id) async {
    final data = await _api.get<Map<String, dynamic>>(
      '${ApiRoutes.appointments}/$id',
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

  Future<AppointmentModel> reschedule({
    required String id,
    required String scheduledDate,
    required String startTime,
  }) async {
    final data = await _api.patch<Map<String, dynamic>>(
      '${ApiRoutes.appointments}/$id/reschedule',
      body: {'scheduledDate': scheduledDate, 'startTime': startTime},
    );

    return AppointmentModel.fromJson(data);
  }

  Future<void> submitReview({
    required String appointmentId,
    required int rating,
    String? comment,
  }) {
    return _api.post(
      ApiRoutes.reviews,
      body: {
        'appointmentId': appointmentId,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
  }
}

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  return AppointmentsRepository(ref.watch(apiClientProvider));
});
