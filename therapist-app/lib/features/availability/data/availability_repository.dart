import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/api_client.dart';

/// A recurring weekly working window, e.g. Monday 09:00 to 13:00.
class AvailabilitySlot {
  const AvailabilitySlot({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
  });

  final String id;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final bool isActive;

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) =>
      AvailabilitySlot(
        id: json['id'] as String,
        dayOfWeek: json['dayOfWeek'] as int,
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String,
        isActive: json['isActive'] as bool? ?? true,
      );

  /// "09:00 AM - 01:00 PM" for display.
  String get displayRange => '${_format(startTime)} - ${_format(endTime)}';

  static String _format(String time) {
    final parts = time.split(':');
    final int hour = int.parse(parts[0]);
    final String period = hour >= 12 ? 'PM' : 'AM';
    final int displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:${parts[1]} $period';
  }

  /// Total minutes covered, used to warn about very short windows.
  int get durationMinutes {
    int toMinutes(String value) {
      final parts = value.split(':').map(int.parse).toList();
      return parts[0] * 60 + parts[1];
    }

    return toMinutes(endTime) - toMinutes(startTime);
  }
}

class AvailabilityRepository {
  AvailabilityRepository(this._api);

  final ApiClient _api;

  Future<List<AvailabilitySlot>> list() async {
    final data = await _api.get<List<dynamic>>(ApiRoutes.availability);

    return data
        .map((e) => AvailabilitySlot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AvailabilitySlot> create({
    required int dayOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiRoutes.availability,
      body: {
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
      },
    );

    return AvailabilitySlot.fromJson(data);
  }

  Future<void> delete(String slotId) =>
      _api.delete('${ApiRoutes.availability}/$slotId');

  /// Replaces the whole week in one call, used by the bulk save button.
  Future<List<AvailabilitySlot>> replaceWeek(
    List<({int dayOfWeek, String startTime, String endTime})> slots,
  ) async {
    final data = await _api.put<List<dynamic>>(
      ApiRoutes.availability,
      body: {
        'slots': slots
            .map((slot) => {
                  'dayOfWeek': slot.dayOfWeek,
                  'startTime': slot.startTime,
                  'endTime': slot.endTime,
                })
            .toList(),
      },
    );

    return data
        .map((e) => AvailabilitySlot.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  return AvailabilityRepository(ref.watch(apiClientProvider));
});

final availabilityProvider =
    FutureProvider.autoDispose<List<AvailabilitySlot>>((ref) {
  return ref.watch(availabilityRepositoryProvider).list();
});
