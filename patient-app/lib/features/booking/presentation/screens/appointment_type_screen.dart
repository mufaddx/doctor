import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../search/presentation/providers/therapist_provider.dart';

/// Step 2 of booking: choose clinic visit, home visit or video consultation.
class AppointmentTypeScreen extends ConsumerStatefulWidget {
  const AppointmentTypeScreen({
    super.key,
    required this.therapistId,
    required this.date,
    required this.startTime,
  });

  final String therapistId;
  final String date;
  final String startTime;

  @override
  ConsumerState<AppointmentTypeScreen> createState() =>
      _AppointmentTypeScreenState();
}

class _AppointmentTypeScreenState extends ConsumerState<AppointmentTypeScreen> {
  String? _selectedType;

  void _continue() {
    if (_selectedType == null) return;

    context.go(
      '${AppRoutes.home}/${AppRoutes.therapistProfile}/${widget.therapistId}/'
      '${AppRoutes.bookingSummary}'
      '?date=${widget.date}&time=${widget.startTime}&type=$_selectedType',
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(therapistDetailProvider(widget.therapistId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Choose Appointment Type'),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(therapistDetailProvider(widget.therapistId)),
        ),
        data: (therapist) {
          final options = <({String type, String title, String subtitle, IconData icon, double fee})>[
            (
              type: 'CLINIC_VISIT',
              title: 'Clinic Visit',
              subtitle: 'Visit the therapist at their clinic',
              icon: Icons.local_hospital_outlined,
              fee: therapist.clinicFee,
            ),
            (
              type: 'HOME_VISIT',
              title: 'Home Visit',
              subtitle: 'Therapist will visit your home',
              icon: Icons.home_outlined,
              fee: therapist.homeVisitFee,
            ),
            (
              type: 'VIDEO_CONSULTATION',
              title: 'Video Consultation',
              subtitle: 'Consult over a secure video call',
              icon: Icons.videocam_outlined,
              fee: therapist.videoFee,
            ),
            // A fee of zero means the therapist does not offer that mode
          ].where((option) => option.fee > 0).toList();

          if (options.isEmpty) {
            return const AppEmptyView(
              title: 'No consultation modes available',
              message: 'This therapist has not configured any fees yet.',
              icon: Icons.info_outline,
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: options.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final bool selected = _selectedType == option.type;

                    return _TypeCard(
                      title: option.title,
                      subtitle: option.subtitle,
                      icon: option.icon,
                      fee: option.fee,
                      selected: selected,
                      onTap: () => setState(() => _selectedType = option.type),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: AppButton(
                    label: 'Continue',
                    onPressed: _selectedType == null ? null : _continue,
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

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.fee,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final double fee;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.06)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.dividerColor,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${fee.toStringAsFixed(0)}',
                  style: theme.textTheme.titleMedium,
                ),
                if (selected) ...[
                  const SizedBox(height: 4),
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
