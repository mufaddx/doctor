import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../data/appointment_model.dart';

/// Compact row used on the dashboard's "Today's Schedule" list. The left
/// accent bar encodes the appointment type at a glance.
class ScheduleTile extends StatelessWidget {
  const ScheduleTile({
    super.key,
    required this.appointment,
    required this.onTap,
    this.onJoinCall,
  });

  final AppointmentModel appointment;
  final VoidCallback onTap;
  final VoidCallback? onJoinCall;

  Color _accentColor(BuildContext context) => switch (appointment.type) {
        'VIDEO_CONSULTATION' => AppColors.info,
        'HOME_VISIT' => AppColors.warning,
        _ => Theme.of(context).colorScheme.primary,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color accent = _accentColor(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppSpacing.radiusLg),
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 62,
                        child: Text(
                          appointment.displayTime,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      AppAvatar(
                        imageUrl: appointment.patientAvatarUrl,
                        name: appointment.patientName,
                        size: 36,
                      ),
                      const SizedBox(width: AppSpacing.sm),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appointment.patientName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              appointment.problem?.isNotEmpty == true
                                  ? appointment.problem!
                                  : appointment.readableType,
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      if (onJoinCall != null)
                        FilledButton(
                          onPressed: onJoinCall,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          child: const Text('Join'),
                        )
                      else if (appointment.isPending)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Pending',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
