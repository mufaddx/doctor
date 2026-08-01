import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/appointment_model.dart';
import '../../data/appointments_repository.dart';
import '../providers/appointments_provider.dart';

class AppointmentDetailScreen extends ConsumerWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final String appointmentId;

  void _refreshEverything(WidgetRef ref) {
    ref.invalidate(appointmentDetailProvider(appointmentId));
    ref.invalidate(upcomingAppointmentProvider);
    for (final tab in AppointmentTab.values) {
      ref.invalidate(appointmentsProvider(tab));
    }
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appointment,
  ) async {
    final TextEditingController reasonController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appointment.isFreeCancellation
                  ? 'This is more than 12 hours before your session, so you get a full refund.'
                  : 'This is within 12 hours of your session, so a cancellation fee may apply.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Appointment'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel It'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .cancel(appointment.id, reasonController.text.trim());
      _refreshEverything(ref);

      if (!context.mounted) return;
      AppSnackbar.success(context, 'Appointment cancelled');
    } catch (error) {
      if (!context.mounted) return;
      AppSnackbar.error(context, error.toString());
    }
  }

  Future<void> _rate(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appointment,
  ) async {
    int rating = 5;
    final TextEditingController commentController = TextEditingController();

    final bool? submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Rate ${appointment.therapistName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final int star = index + 1;
                  return IconButton(
                    onPressed: () => setState(() => rating = star),
                    icon: Icon(
                      star <= rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppColors.warning,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Share your experience (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true) return;

    try {
      await ref.read(appointmentsRepositoryProvider).submitReview(
            appointmentId: appointment.id,
            rating: rating,
            comment: commentController.text.trim(),
          );
      _refreshEverything(ref);

      if (!context.mounted) return;
      AppSnackbar.success(context, 'Thanks for your feedback');
    } catch (error) {
      if (!context.mounted) return;
      AppSnackbar.error(context, error.toString());
    }
  }

  Color _statusColor(String status) => switch (status) {
        'CONFIRMED' => AppColors.success,
        'PENDING' => AppColors.warning,
        'IN_PROGRESS' => AppColors.info,
        'COMPLETED' => AppColors.brandTeal,
        'CANCELLED' || 'REJECTED' => AppColors.danger,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentAsync = ref.watch(appointmentDetailProvider(appointmentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Appointment Details')),
      body: appointmentAsync.when(
        loading: () => const AppListSkeleton(itemCount: 3, itemHeight: 100),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(appointmentDetailProvider(appointmentId)),
        ),
        data: (appointment) => _DetailBody(
          appointment: appointment,
          statusColor: _statusColor(appointment.status),
          onCancel: () => _cancel(context, ref, appointment),
          onRate: () => _rate(context, ref, appointment),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.appointment,
    required this.statusColor,
    required this.onCancel,
    required this.onRate,
  });

  final AppointmentModel appointment;
  final Color statusColor;
  final VoidCallback onCancel;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Cancellation only makes sense while the session has not started yet.
    final bool canCancel =
        appointment.status == 'PENDING' || appointment.status == 'CONFIRMED';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: statusColor),
              const SizedBox(width: 6),
              Text(
                appointment.readableStatus,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                AppAvatar(
                  imageUrl: appointment.therapistAvatarUrl,
                  name: appointment.therapistName,
                  size: 52,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.therapistName,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (appointment.specialization.isNotEmpty)
                        Text(
                          appointment.specialization.join(', '),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.event_outlined,
                  label: 'Date & Time',
                  value:
                      '${DateFormat('EEEE, d MMM yyyy').format(appointment.scheduledDate)}\n${appointment.displayTime}',
                ),
                const Divider(height: AppSpacing.lg),
                _InfoRow(
                  icon: Icons.medical_services_outlined,
                  label: 'Consultation Type',
                  value: appointment.readableType,
                ),
                if (appointment.problem != null &&
                    appointment.problem!.isNotEmpty) ...[
                  const Divider(height: AppSpacing.lg),
                  _InfoRow(
                    icon: Icons.sick_outlined,
                    label: 'Problem',
                    value: appointment.problem!,
                  ),
                ],
                if (appointment.notes != null &&
                    appointment.notes!.isNotEmpty) ...[
                  const Divider(height: AppSpacing.lg),
                  _InfoRow(
                    icon: Icons.notes_outlined,
                    label: 'Notes',
                    value: appointment.notes!,
                  ),
                ],
                if (appointment.isCancelled &&
                    appointment.cancelReason != null &&
                    appointment.cancelReason!.isNotEmpty) ...[
                  const Divider(height: AppSpacing.lg),
                  _InfoRow(
                    icon: Icons.info_outline,
                    label: 'Cancellation Reason',
                    value: appointment.cancelReason!,
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment Summary', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                _MoneyRow(
                  label: 'Consultation Fee',
                  amount: appointment.consultationFee,
                ),
                _MoneyRow(
                  label: 'Platform Fee',
                  amount: appointment.platformFee,
                ),
                if (appointment.discountAmount > 0)
                  _MoneyRow(
                    label: 'Discount',
                    amount: -appointment.discountAmount,
                  ),
                const Divider(height: AppSpacing.lg),
                _MoneyRow(
                  label: 'Total',
                  amount: appointment.totalAmount,
                  emphasize: true,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  appointment.isPaid
                      ? 'Paid'
                      : (appointment.paymentStatus ?? 'Payment pending'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: appointment.isPaid
                        ? AppColors.success
                        : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        if (appointment.canJoinCall)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppButton(
              label: 'Join Video Call',
              icon: Icons.videocam_outlined,
              onPressed: () => context.push('/call/${appointment.id}'),
            ),
          ),

        if (appointment.prescriptionId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppButton(
              label: 'View Prescription',
              variant: AppButtonVariant.outlined,
              icon: Icons.description_outlined,
              onPressed: () => context.go(
                '${AppRoutes.appointments}/${AppRoutes.prescription}/${appointment.prescriptionId}',
              ),
            ),
          ),

        if (appointment.isCompleted && !appointment.hasReview)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppButton(
              label: 'Rate Your Experience',
              variant: AppButtonVariant.outlined,
              icon: Icons.star_outline_rounded,
              onPressed: onRate,
            ),
          ),

        if (canCancel)
          AppButton(
            label: 'Cancel Appointment',
            variant: AppButtonVariant.text,
            onPressed: onCancel,
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.amount,
    this.emphasize = false,
  });

  final String label;
  final double amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final TextStyle? style = emphasize
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            '${amount < 0 ? '-' : ''}₹${amount.abs().toStringAsFixed(0)}',
            style: style,
          ),
        ],
      ),
    );
  }
}
