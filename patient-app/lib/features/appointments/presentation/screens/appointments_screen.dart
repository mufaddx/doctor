import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/appointment_model.dart';
import '../providers/appointments_provider.dart';

class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppointmentTab selectedTab = ref.watch(selectedAppointmentTabProvider);
    final appointmentsAsync = ref.watch(appointmentsProvider(selectedTab));

    return Scaffold(
      appBar: AppBar(title: const Text('My Appointments')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: AppointmentTab.values.map((tab) {
                final bool selected = tab == selectedTab;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(tab.label, textAlign: TextAlign.center),
                      ),
                      selected: selected,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected ? Colors.white : null,
                      ),
                      onSelected: (_) => ref
                          .read(selectedAppointmentTabProvider.notifier)
                          .state = tab,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          Expanded(
            child: appointmentsAsync.when(
              loading: () => const AppListSkeleton(itemHeight: 120),
              error: (error, _) => AppErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(appointmentsProvider(selectedTab)),
              ),
              data: (appointments) {
                if (appointments.isEmpty) {
                  return AppEmptyView(
                    title: 'No ${selectedTab.label.toLowerCase()} appointments',
                    message: selectedTab == AppointmentTab.upcoming
                        ? 'Book a session with a therapist to get started.'
                        : 'Nothing to show here yet.',
                    icon: Icons.event_note_outlined,
                    actionLabel: selectedTab == AppointmentTab.upcoming
                        ? 'Find a Therapist'
                        : null,
                    onAction: selectedTab == AppointmentTab.upcoming
                        ? () => context.go(
                              '${AppRoutes.home}/${AppRoutes.search}',
                            )
                        : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(appointmentsProvider(selectedTab)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: appointments.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => AppointmentCard(
                      appointment: appointments[index],
                      onTap: () => context.go(
                        '${AppRoutes.appointments}/${AppRoutes.appointmentDetail}/${appointments[index].id}',
                      ),
                      onJoinCall: () =>
                          context.push('/call/${appointments[index].id}'),
                    ),
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

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
    this.onJoinCall,
  });

  final AppointmentModel appointment;
  final VoidCallback onTap;
  final VoidCallback? onJoinCall;

  /// Colour-codes the status pill so state is readable at a glance.
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
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
                    imageUrl: appointment.therapistAvatarUrl,
                    name: appointment.therapistName,
                    size: 46,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.therapistName,
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
                  Text(
                    '₹${appointment.totalAmount.toStringAsFixed(0)}',
                    style: theme.textTheme.titleMedium,
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
                    '${DateFormat('d MMM yyyy').format(appointment.scheduledDate)} · ${appointment.displayTime}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),

                  // The join button appears only inside the call window
                  if (appointment.canJoinCall)
                    FilledButton(
                      onPressed: onJoinCall,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('Join Call'),
                    )
                  else if (!appointment.isPaid && appointment.isUpcoming)
                    Text(
                      'Payment pending',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.warning),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
