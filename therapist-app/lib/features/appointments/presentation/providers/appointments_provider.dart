import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/appointment_model.dart';
import '../../data/appointments_repository.dart';

enum AppointmentTab { upcoming, completed, cancelled }

extension AppointmentTabX on AppointmentTab {
  String get label => switch (this) {
    AppointmentTab.upcoming => 'Upcoming',
    AppointmentTab.completed => 'Completed',
    AppointmentTab.cancelled => 'Cancelled',
  };

  /// Upcoming spans PENDING, CONFIRMED and IN_PROGRESS, so it is filtered
  /// locally rather than sent as a single status to the API.
  String? get statusFilter => switch (this) {
    AppointmentTab.upcoming => null,
    AppointmentTab.completed => 'COMPLETED',
    AppointmentTab.cancelled => 'CANCELLED',
  };

  bool matches(AppointmentModel appointment) => switch (this) {
    AppointmentTab.upcoming =>
      appointment.status == 'PENDING' ||
          appointment.status == 'CONFIRMED' ||
          appointment.status == 'IN_PROGRESS',
    AppointmentTab.completed => appointment.status == 'COMPLETED',
    AppointmentTab.cancelled =>
      appointment.status == 'CANCELLED' || appointment.status == 'REJECTED',
  };
}

final selectedTabProvider = StateProvider.autoDispose<AppointmentTab>(
  (ref) => AppointmentTab.upcoming,
);

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((
  ref,
) {
  return ref.watch(appointmentsRepositoryProvider).stats();
});

final todayScheduleProvider =
    FutureProvider.autoDispose<List<AppointmentModel>>((ref) {
      return ref.watch(appointmentsRepositoryProvider).todaySchedule();
    });

final appointmentsProvider = FutureProvider.autoDispose
    .family<List<AppointmentModel>, AppointmentTab>((ref, tab) async {
      final items = await ref
          .watch(appointmentsRepositoryProvider)
          .list(status: tab.statusFilter);

      final filtered = items.where(tab.matches).toList();

      // Pending requests float to the top of the upcoming tab because they are
      // the only rows that need an action from the therapist.
      filtered.sort((a, b) {
        if (tab == AppointmentTab.upcoming) {
          if (a.isPending != b.isPending) return a.isPending ? -1 : 1;
          return a.scheduledDate.compareTo(b.scheduledDate);
        }
        return b.scheduledDate.compareTo(a.scheduledDate);
      });

      return filtered;
    });

final appointmentDetailProvider = FutureProvider.autoDispose
    .family<AppointmentModel, String>((ref, id) {
      return ref.watch(appointmentsRepositoryProvider).findOne(id);
    });
