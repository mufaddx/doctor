import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../search/data/therapist_model.dart';

/// Compact therapist row used on the home screen and in search results.
class TherapistCard extends StatelessWidget {
  const TherapistCard({super.key, required this.therapist, required this.onTap});

  final TherapistModel therapist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(
                imageUrl: therapist.avatarUrl,
                name: therapist.fullName,
                size: 56,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      therapist.fullName,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      therapist.specialization.isEmpty
                          ? 'Physiotherapist'
                          : therapist.specialization.take(2).join(' · '),
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: 4,
                      children: [
                        _MetaChip(
                          icon: Icons.workspace_premium_outlined,
                          label: therapist.experienceLabel,
                        ),
                        _MetaChip(
                          icon: Icons.star_rounded,
                          label:
                              '${therapist.ratingAvg.toStringAsFixed(1)} (${therapist.ratingCount})',
                          iconColor: AppColors.warning,
                        ),
                        // Distance only exists when the user shared location
                        if (therapist.distanceKm != null)
                          _MetaChip(
                            icon: Icons.location_on_outlined,
                            label: '${therapist.distanceKm} km',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${therapist.startingFee.toStringAsFixed(0)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text('onwards', style: theme.textTheme.bodySmall),
                  if (!therapist.isAvailable) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Unavailable',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.danger),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.iconColor});

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: iconColor ?? Theme.of(context).textTheme.bodySmall?.color,
        ),
        const SizedBox(width: 3),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
