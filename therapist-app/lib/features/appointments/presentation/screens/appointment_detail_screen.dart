import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/appointment_model.dart';
import '../../data/appointments_repository.dart';
import '../providers/appointments_provider.dart';

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  ConsumerState<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState
    extends ConsumerState<AppointmentDetailScreen> {
  bool _isBusy = false;

  Future<void> _run(
    Future<AppointmentModel> Function() action,
    String successMessage,
  ) async {
    setState(() => _isBusy = true);

    try {
      await action();

      ref.invalidate(appointmentDetailProvider(widget.appointmentId));
      ref.invalidate(appointmentsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(todayScheduleProvider);

      if (!mounted) return;
      AppSnackbar.success(context, successMessage);
    } catch (error) {
      if (!mounted) return;
      AppSnackbar.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _callPatient(String? phone) async {
    if (phone == null) return;

    final Uri uri = Uri(scheme: 'tel', path: '+91$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final appointmentAsync = ref.watch(
      appointmentDetailProvider(widget.appointmentId),
    );
    final repository = ref.read(appointmentsRepositoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Appointment Details'),
      ),
      body: appointmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(appointmentDetailProvider(widget.appointmentId)),
        ),
        data: (appointment) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                appointment.readableType,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    AppAvatar(
                      imageUrl: appointment.patientAvatarUrl,
                      name: appointment.patientName,
                      size: 52,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appointment.patientName,
                            style: theme.textTheme.titleMedium,
                          ),
                          if (appointment.patientPhone != null)
                            Text(
                              '+91 ${appointment.patientPhone}',
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => _callPatient(appointment.patientPhone),
                      icon: const Icon(Icons.call),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    _Row(
                      icon: Icons.event_outlined,
                      label: 'Date',
                      value: DateFormat(
                        'd MMMM yyyy',
                      ).format(appointment.scheduledDate),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Row(
                      icon: Icons.access_time,
                      label: 'Time',
                      value: appointment.displayTime,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Row(
                      icon: Icons.timelapse_outlined,
                      label: 'Duration',
                      value: '${appointment.durationMinutes} Minutes',
                    ),
                    if (appointment.problem != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _Row(
                        icon: Icons.healing_outlined,
                        label: 'Problem',
                        value: appointment.problem!,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    _Row(
                      icon: Icons.payments_outlined,
                      label: 'Payment',
                      value:
                          '₹${appointment.consultationFee.toStringAsFixed(0)} · ${appointment.isPaid ? 'Paid' : 'Pending'}',
                      valueColor: appointment.isPaid
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ],
                ),
              ),
            ),

            if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Patient Notes', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    appointment.notes!,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
              ),
            ],

            if (appointment.cancelReason != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.danger),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Cancelled: ${appointment.cancelReason}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // The action set depends on where the appointment is in its
            // lifecycle, so only the relevant buttons are rendered.
            if (appointment.canJoinCall)
              AppButton(
                label: 'Start Video Call',
                icon: Icons.videocam,
                onPressed: () => context.push('/call/${appointment.id}'),
              ),

            if (appointment.isConfirmed && !appointment.isVideo) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Mark as Started',
                isLoading: _isBusy,
                onPressed: () => _run(
                  () => repository.start(appointment.id),
                  'Session started',
                ),
              ),
            ],

            if (appointment.status == 'IN_PROGRESS') ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Mark as Completed',
                isLoading: _isBusy,
                onPressed: () => _run(
                  () => repository.complete(appointment.id),
                  'Session marked complete',
                ),
              ),
            ],

            if (appointment.canWritePrescription) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Add Prescription',
                icon: Icons.description_outlined,
                variant: AppButtonVariant.outlined,
                onPressed: () => context.push(
                  '/appointments/detail/${appointment.id}/prescription',
                ),
              ),
            ],

            if (appointment.patientId.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'View Patient History',
                icon: Icons.folder_outlined,
                variant: AppButtonVariant.outlined,
                onPressed: () =>
                    context.go('/patients/${appointment.patientId}'),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
