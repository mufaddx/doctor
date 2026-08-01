import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../search/data/therapist_repository.dart';
import '../../../search/presentation/providers/therapist_provider.dart';

/// Step 1 of booking: pick a date, then a free 30-minute slot.
class SelectSlotScreen extends ConsumerStatefulWidget {
  const SelectSlotScreen({super.key, required this.therapistId});

  final String therapistId;

  @override
  ConsumerState<SelectSlotScreen> createState() => _SelectSlotScreenState();
}

class _SelectSlotScreenState extends ConsumerState<SelectSlotScreen> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  String? _selectedTime;

  /// Bookings open only 60 days ahead, matching the backend rule.
  static const int _maxAdvanceDays = 60;

  @override
  void initState() {
    super.initState();
    final DateTime today = DateTime.now();
    _selectedDay = DateTime(today.year, today.month, today.day);
    _focusedDay = _selectedDay;
  }

  void _continue() {
    if (_selectedTime == null) return;

    final String date = DateFormat('yyyy-MM-dd').format(_selectedDay);

    context.go(
      '${AppRoutes.home}/${AppRoutes.therapistProfile}/${widget.therapistId}/'
      '${AppRoutes.appointmentType}?date=$date&time=$_selectedTime',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final slotsAsync = ref.watch(
      availableSlotsProvider(
        (therapistId: widget.therapistId, date: _selectedDay),
      ),
    );

    final DateTime today = DateTime.now();
    final DateTime firstDay = DateTime(today.year, today.month, today.day);
    final DateTime lastDay = firstDay.add(const Duration(days: _maxAdvanceDays));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Select Date & Time'),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(AppSpacing.md),
            child: TableCalendar<void>(
              firstDay: firstDay,
              lastDay: lastDay,
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              calendarFormat: CalendarFormat.month,
              availableGestures: AvailableGestures.horizontalSwipe,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: theme.textTheme.titleMedium!,
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(color: theme.colorScheme.primary),
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = DateTime(
                    selected.year,
                    selected.month,
                    selected.day,
                  );
                  _focusedDay = focused;
                  // A previously chosen time may not exist on the new day
                  _selectedTime = null;
                });
              },
              onPageChanged: (focused) => _focusedDay = focused,
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Available Slots',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          Expanded(
            child: slotsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => AppErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(
                  availableSlotsProvider(
                    (therapistId: widget.therapistId, date: _selectedDay),
                  ),
                ),
              ),
              data: (slots) {
                final List<TimeSlot> bookable =
                    slots.where((slot) => slot.available).toList();

                if (bookable.isEmpty) {
                  return const AppEmptyView(
                    title: 'No slots available',
                    message:
                        'This therapist has no free slots on the selected date. Try another day.',
                    icon: Icons.event_busy_outlined,
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: bookable.map((slot) {
                      final bool selected = _selectedTime == slot.startTime;

                      return ChoiceChip(
                        label: Text(slot.displayTime),
                        selected: selected,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected ? Colors.white : null,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedTime = slot.startTime),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppButton(
                label: 'Continue',
                onPressed: _selectedTime == null ? null : _continue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
