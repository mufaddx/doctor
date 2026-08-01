import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/appointment_model.dart';
import '../../data/appointments_repository.dart';
import '../providers/appointments_provider.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  /// Tracks which row is mid-request so only that card shows a spinner.
  String? _busyAppointmentId;

  Future<void> _accept(AppointmentModel appointment) async {
    setState(() => _busyAppointmentId = appointment.id);

    try {
      await ref.read(appointmentsRepositoryProvider).accept(appointment.id);
      _refreshAll();

      if (!mounted) return;
      AppSnackbar.success(
        context,
        'Appointment with ${appointment.patientName} confirmed',
      );
    } catch (error) {
      if (!mounted) return;
      AppSnackbar.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _busyAppointmentId = null);
    }
  }

  Future<void> _reject(AppointmentModel appointment) async {
    final String? reason = await _askReason(
      title: 'Decline this request?',
      subtitle:
          '${appointment.patientName} will be notified and any payment refunded.',
      confirmLabel: 'Decline',
    );

    if (reason == null) return;

    setState(() => _busyAppointmentId = appointment.id);

    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .reject(appointment.id, reason);
      _refreshAll();

      if (!mounted) return;
      AppSnackbar.info(context, 'Request declined');
    } catch (error) {
      if (!mounted) return;
      AppSnackbar.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _busyAppointmentId = null);
    }
  }

  /// Shared reason prompt; returns null when the therapist backs out.
  Future<String?> _askReason({
    required String title,
    required String subtitle,
    required String confirmLabel,
  }) {
    final TextEditingController controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              maxLines: 2,
              maxLength: 300,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Reason (visible to the patient)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              final String reason = controller.text.trim();
              // A blank reason leaves the patient with no explanation
              if (reason.length < 5) return;
              Navigator.of(context).pop(reason);
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _refreshAll() {
    ref.invalidate(appointmentsProvider);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(todayScheduleProvider);
  }

  @override
  Widget build(BuildContext context) {
    final AppointmentTab tab = ref.watch(selectedTabProvider);
    final appointmentsAsync = ref.watch(appointmentsProvider(tab));

    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: AppointmentTab.values.map((value) {
                final bool selected = value == tab;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(value.label, textAlign: TextAlign.center),
                      ),
                      selected: selected,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected ? Colors.white : null,
                      ),
                      onSelected: (_) =>
                          ref.read(selectedTabProvider.notifier).state = value,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          Expanded(
            child: appointmentsAsync.when(
              loading: () => const AppListSkeleton(itemHeight: 140),
              error: (error, _) => AppErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(appointmentsProvider(tab)),
              ),
              data: (appointments) {
                if (appointments.isEmpty) {
                  return AppEmptyView(
                    title: 'No ${tab.label.toLowerCase()} appointments',
                    message: tab == AppointmentTab.upcoming
                        ? 'New booking requests will appear here.'
                        : 'Nothing to show yet.',
                    icon: Icons.event_note_outlined,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(appointmentsProvider(tab)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: appointments.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final appointment = appointments[index];

                      return _AppointmentCard(
                        appointment: appointment,
                        isBusy: _busyAppointmentId == appointment.id,
                        onTap: () =>
                            context.go('/appointments/detail/${appointment.id}'),
                        onAccept: () => _accept(appointment),
                        onReject: () => _reject(appointment),
                        onJoinCall: () => context.push('/call/${appointment.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.isBusy,
    required this.onTap,
    required this.onAccept,
    required this.onReject,
    required this.onJoinCall,
  });

  final AppointmentModel appointment;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onJoinCall;

  Color _statusColor(BuildContext context) => switch (appointment.status) {
        'CONFIRMED' => AppColors.success,
        'PENDING' => AppColors.warning,
        'IN_PROGRESS' => AppColors.info,
        'COMPLETED' => Theme.of(context).colorScheme.primary,
        'CANCELLED' || 'REJECTED' => AppColors.danger,
        _ => Colors.grey,
      };

  IconData get _typeIcon => switch (appointment.type) {
        'CLINIC_VISIT' => Icons.local_hospital_outlined,
        'HOME_VISIT' => Icons.home_outlined,
        'VIDEO_CONSULTATION' => Icons.videocam_outlined,
        _ => Icons.event_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color statusColor = _statusColor(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_typeIcon, size: 13, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          appointment.readableType,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    appointment.readableStatus,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  AppAvatar(
                    imageUrl: appointment.patientAvatarUrl,
                    name: appointment.patientName,
                    size: 46,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.patientName,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (appointment.problem != null &&
                            appointment.problem!.isNotEmpty)
                          Text(
                            appointment.problem!,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${appointment.consultationFee.toStringAsFixed(0)}',
                        style: theme.textTheme.titleMedium,
                      ),
                      if (appointment.isPaid)
                        Text(
                          'Paid',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.success),
                        ),
                    ],
                  ),
                ],
              ),

              const Divider(height: AppSpacing.lg),

              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 15,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${DateFormat('d MMM').format(appointment.scheduledDate)} · ${appointment.displayTime}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),

                  if (isBusy)
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  // Pending requests get the accept/decline pair; everything
                  // else gets the contextual action for its state.
                  else if (appointment.isPending) ...[
                    OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      child: const Text('Decline'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      onPressed: onAccept,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      child: const Text('Accept'),
                    ),
                  ] else if (appointment.canJoinCall)
                    FilledButton(
                      onPressed: onJoinCall,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('Join Call'),
                    )
                  else
                    TextButton(onPressed: onTap, child: const Text('View')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
