import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/patients_repository.dart';

class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<PatientProfileScreen> createState() =>
      _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _call(String? phone) async {
    if (phone == null) return;

    final Uri uri = Uri(scheme: 'tel', path: '+91$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(patientHistoryProvider(widget.patientId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Patient Profile'),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(patientHistoryProvider(widget.patientId)),
        ),
        data: (patient) => Column(
          children: [
            _Header(patient: patient, onCall: () => _call(patient.phone)),

            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'History'),
                Tab(text: 'Prescriptions'),
                Tab(text: 'Progress'),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _OverviewTab(patient: patient),
                  _HistoryTab(patient: patient),
                  _PrescriptionsTab(patient: patient),
                  _ProgressTab(patient: patient),
                ],
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: historyAsync.maybeWhen(
        data: (patient) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AppButton(
              label: 'Assign Exercise Plan',
              icon: Icons.fitness_center,
              onPressed: () => context.push(
                '/patients/${widget.patientId}/assign-exercises',
              ),
            ),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.patient, required this.onCall});

  final PatientHistory patient;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AppAvatar(
            imageUrl: patient.avatarUrl,
            name: patient.fullName,
            size: 60,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.fullName, style: theme.textTheme.titleLarge),
                Text(
                  [
                    if (patient.gender != null) patient.gender,
                    if (patient.age != null) '${patient.age} Years',
                  ].join(', '),
                  style: theme.textTheme.bodySmall,
                ),
                if (patient.phone != null)
                  Text(
                    '+91 ${patient.phone}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onCall,
            icon: const Icon(Icons.call),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.patient});

  final PatientHistory patient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final PatientAppointment? upcoming = patient.appointments
        .where((a) => a.status == 'CONFIRMED' || a.status == 'PENDING')
        .fold<PatientAppointment?>(null, (earliest, appointment) {
          // Keep the soonest upcoming appointment
          if (earliest == null) return appointment;
          return appointment.scheduledDate.isBefore(earliest.scheduledDate)
              ? appointment
              : earliest;
        });

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                _InfoRow(
                  label: 'Problem',
                  value: patient.appointments.isEmpty
                      ? '—'
                      : (patient.appointments.first.problem ?? '—'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(
                  label: 'Pain Level',
                  value: patient.currentPainLevel == null
                      ? 'Not logged'
                      : '${patient.currentPainLevel}/10',
                  valueColor: patient.currentPainLevel == null
                      ? null
                      : _painColor(patient.currentPainLevel!),
                ),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(
                  label: 'Sessions Completed',
                  value: '${patient.completedSessions}',
                ),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(
                  label: 'Last Appointment',
                  value: patient.appointments.isEmpty
                      ? '—'
                      : DateFormat(
                          'd MMM yyyy',
                        ).format(patient.appointments.first.scheduledDate),
                ),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(
                  label: 'Next Appointment',
                  value: upcoming == null
                      ? 'None scheduled'
                      : '${DateFormat('d MMM yyyy').format(upcoming.scheduledDate)}, ${upcoming.startTime}',
                ),
              ],
            ),
          ),
        ),

        if (patient.medicalHistory != null &&
            patient.medicalHistory!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Medical History', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                patient.medicalHistory!,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),
          ),
        ],

        const SizedBox(height: 80),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.patient});

  final PatientHistory patient;

  @override
  Widget build(BuildContext context) {
    if (patient.appointments.isEmpty) {
      return const AppEmptyView(
        title: 'No appointment history',
        icon: Icons.event_note_outlined,
      );
    }

    final theme = Theme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: patient.appointments.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final appointment = patient.appointments[index];

        return Card(
          child: ListTile(
            title: Text(
              appointment.problem ?? _readableType(appointment.type),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${DateFormat('d MMM yyyy').format(appointment.scheduledDate)} · ${appointment.startTime}',
              style: theme.textTheme.bodySmall,
            ),
            trailing: Text(
              appointment.status,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: appointment.status == 'COMPLETED'
                    ? AppColors.success
                    : (appointment.status == 'CANCELLED'
                          ? AppColors.danger
                          : theme.colorScheme.primary),
              ),
            ),
          ),
        );
      },
    );
  }

  String _readableType(String type) => switch (type) {
    'CLINIC_VISIT' => 'Clinic Visit',
    'HOME_VISIT' => 'Home Visit',
    'VIDEO_CONSULTATION' => 'Video Consultation',
    _ => type,
  };
}

class _PrescriptionsTab extends StatelessWidget {
  const _PrescriptionsTab({required this.patient});

  final PatientHistory patient;

  @override
  Widget build(BuildContext context) {
    if (patient.prescriptions.isEmpty) {
      return const AppEmptyView(
        title: 'No prescriptions yet',
        message: 'Prescriptions you write will appear here.',
        icon: Icons.description_outlined,
      );
    }

    final theme = Theme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: patient.prescriptions.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final prescription = patient.prescriptions[index];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        prescription.diagnosis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      DateFormat('d MMM yyyy').format(prescription.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),

                if (prescription.advice != null &&
                    prescription.advice!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(prescription.advice!, style: theme.textTheme.bodySmall),
                ],

                if (prescription.medicines.isNotEmpty) ...[
                  const Divider(height: AppSpacing.lg),
                  ...prescription.medicines.map(
                    (medicine) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${medicine['name']}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            '${medicine['dosage']}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProgressTab extends StatelessWidget {
  const _ProgressTab({required this.patient});

  final PatientHistory patient;

  @override
  Widget build(BuildContext context) {
    if (patient.progressLogs.isEmpty) {
      return const AppEmptyView(
        title: 'No progress logged',
        message: 'The patient has not recorded any pain levels yet.',
        icon: Icons.insights_outlined,
      );
    }

    final theme = Theme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: patient.progressLogs.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final entry = patient.progressLogs[index];

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _painColor(
                entry.painLevel,
              ).withValues(alpha: 0.15),
              child: Text(
                '${entry.painLevel}',
                style: TextStyle(
                  color: _painColor(entry.painLevel),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Text(entry.condition, style: theme.textTheme.bodyMedium),
            subtitle: Text(
              DateFormat('d MMM yyyy').format(entry.loggedAt),
              style: theme.textTheme.bodySmall,
            ),
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
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

/// Pain colour ramps from green through amber to red as severity rises.
Color _painColor(int painLevel) {
  if (painLevel <= 3) return AppColors.success;
  if (painLevel <= 6) return AppColors.warning;
  return AppColors.danger;
}
