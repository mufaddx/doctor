import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/availability_repository.dart';

const List<String> _dayLabels = [
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
];

class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  /// Which weekday's slots are currently shown. Defaults to today.
  late int _selectedDay = DateTime.now().weekday % 7;

  bool _isSaving = false;

  Future<void> _addSlot() async {
    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Start time',
    );
    if (start == null || !mounted) return;

    final TimeOfDay? end = await showTimePicker(
      context: context,
      // Defaulting to four hours later matches a typical clinic block
      initialTime: TimeOfDay(hour: (start.hour + 4) % 24, minute: start.minute),
      helpText: 'End time',
    );
    if (end == null || !mounted) return;

    final String startTime = _toApiTime(start);
    final String endTime = _toApiTime(end);

    if (_toMinutes(endTime) <= _toMinutes(startTime)) {
      AppSnackbar.error(context, 'End time must be after start time');
      return;
    }
    // The backend books in 30-minute units, so windows must align to them
    if ((_toMinutes(endTime) - _toMinutes(startTime)) % 30 != 0) {
      AppSnackbar.error(
        context,
        'Window length must be a multiple of 30 minutes',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref
          .read(availabilityRepositoryProvider)
          .create(
            dayOfWeek: _selectedDay,
            startTime: startTime,
            endTime: endTime,
          );

      ref.invalidate(availabilityProvider);

      if (!mounted) return;
      AppSnackbar.success(context, 'Working hours added');
    } catch (error) {
      if (!mounted) return;
      AppSnackbar.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteSlot(AvailabilitySlot slot) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this window?'),
        content: Text(
          'Patients will no longer be able to book ${slot.displayRange} on ${_dayLabels[slot.dayOfWeek]}. '
          'Existing bookings are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(availabilityRepositoryProvider).delete(slot.id);
      ref.invalidate(availabilityProvider);

      if (!mounted) return;
      AppSnackbar.success(context, 'Window removed');
    } catch (error) {
      if (!mounted) return;
      AppSnackbar.error(context, error.toString());
    }
  }

  String _toApiTime(TimeOfDay time) {
    // Times are snapped to the nearest half hour to match the booking grid
    final int minute = time.minute < 15 ? 0 : (time.minute < 45 ? 30 : 0);
    final int hour = time.minute >= 45 ? (time.hour + 1) % 24 : time.hour;

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  int _toMinutes(String time) {
    final parts = time.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(availabilityProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My Availability')),
      body: slotsAsync.when(
        loading: () => const AppListSkeleton(itemHeight: 64),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(availabilityProvider),
        ),
        data: (allSlots) {
          final daySlots =
              allSlots.where((slot) => slot.dayOfWeek == _selectedDay).toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (day) {
                    final bool selected = day == _selectedDay;
                    // A dot marks days that already have working hours
                    final bool hasSlots = allSlots.any(
                      (slot) => slot.dayOfWeek == day,
                    );

                    return GestureDetector(
                      onTap: () => setState(() => _selectedDay = day),
                      child: Container(
                        width: 42,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                          border: Border.all(
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.dividerColor,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _dayLabels[day],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hasSlots
                                    ? (selected
                                          ? Colors.white
                                          : theme.colorScheme.primary)
                                    : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const Divider(height: 1),

              Expanded(
                child: daySlots.isEmpty
                    ? AppEmptyView(
                        title:
                            'No working hours on ${_dayLabels[_selectedDay]}',
                        message:
                            'Add a window so patients can book slots on this day.',
                        icon: Icons.schedule_outlined,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: daySlots.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final slot = daySlots[index];
                          final int bookableSlots = slot.durationMinutes ~/ 30;

                          return Card(
                            child: ListTile(
                              leading: Icon(
                                Icons.access_time,
                                color: theme.colorScheme.primary,
                              ),
                              title: Text(
                                slot.displayRange,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '$bookableSlots bookable slots',
                                style: theme.textTheme.bodySmall,
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.danger,
                                ),
                                onPressed: () => _deleteSlot(slot),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: AppButton(
                    label: 'Add Working Hours',
                    icon: Icons.add,
                    isLoading: _isSaving,
                    onPressed: _addSlot,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
