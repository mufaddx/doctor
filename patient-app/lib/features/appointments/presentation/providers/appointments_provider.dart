import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/appointment_model.dart';
import '../../data/appointments_repository.dart';

/// Which tab the appointments screen is showing.
enum AppointmentTab { upcoming, completed, cancelled }

extension AppointmentTabX on AppointmentTab {
  String get label => switch (this) {
        AppointmentTab.upcoming => 'Upcoming',
        AppointmentTab.completed => 'Completed',
        AppointmentTab.cancelled => 'Cancelled',
      };

  /// Upcoming spans several statuses, so it is filtered client-side rather
  /// than passed to the API as a single status value.
  String? get statusFilter => switch (this) {
        AppointmentTab.upcoming => null,
        AppointmentTab.completed => 'COMPLETED',
        AppointmentTab.cancelled => 'CANCELLED',
      };

  bool matches(AppointmentModel appointment) => switch (this) {
        AppointmentTab.upcoming => appointment.isUpcoming,
        AppointmentTab.completed => appointment.isCompleted,
        AppointmentTab.cancelled => appointment.isCancelled,
      };
}

final selectedAppointmentTabProvider =
    StateProvider.autoDispose<AppointmentTab>((ref) => AppointmentTab.upcoming);

/// List for the currently selected tab.
final appointmentsProvider = FutureProvider.autoDispose
    .family<List<AppointmentModel>, AppointmentTab>((ref, tab) async {
  final result = await ref
      .watch(appointmentsRepositoryProvider)
      .list(status: tab.statusFilter);

  // The upcoming tab covers PENDING, CONFIRMED and IN_PROGRESS together
  final List<AppointmentModel> items =
      result.items.where(tab.matches).toList();

  // Soonest first for upcoming, most recent first for history
  items.sort((a, b) => tab == AppointmentTab.upcoming
      ? a.scheduledDate.compareTo(b.scheduledDate)
      : b.scheduledDate.compareTo(a.scheduledDate));

  return items;
});

final appointmentDetailProvider = FutureProvider.autoDispose
    .family<AppointmentModel, String>((ref, id) {
  return ref.watch(appointmentsRepositoryProvider).findOne(id);
});

/// The single next appointment, used by the home screen hero card.
final upcomingAppointmentProvider =
    FutureProvider.autoDispose<AppointmentModel?>((ref) async {
  final result = await ref.watch(appointmentsRepositoryProvider).list();

  final upcoming = result.items.where((a) => a.isUpcoming).toList()
    ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

  return upcoming.isEmpty ? null : upcoming.first;
});
