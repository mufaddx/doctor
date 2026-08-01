import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/earnings_repository.dart';

const List<({String value, String label})> _periods = [
  (value: 'daily', label: 'Daily'),
  (value: 'weekly', label: 'Weekly'),
  (value: 'monthly', label: 'Monthly'),
  (value: 'yearly', label: 'Yearly'),
];

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String period = ref.watch(selectedPeriodProvider);
    final earningsAsync = ref.watch(earningsProvider);
    final payoutsAsync = ref.watch(payoutsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(earningsProvider);
          ref.invalidate(payoutsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Row(
              children: _periods.map((option) {
                final bool selected = option.value == period;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(option.label, textAlign: TextAlign.center),
                      ),
                      selected: selected,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white : null,
                      ),
                      onSelected: (_) => ref
                          .read(selectedPeriodProvider.notifier)
                          .state = option.value,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.md),

            earningsAsync.when(
              loading: () => const AppListSkeleton(itemCount: 2, itemHeight: 110),
              error: (error, _) => AppErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(earningsProvider),
              ),
              data: (earnings) => Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.brandTeal, AppColors.brandTealDark],
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_periods.firstWhere((p) => p.value == period).label} Earnings',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '₹${earnings.totalEarnings.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Icon(
                              earnings.isUp
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${earnings.changePercent.abs()}% from the previous period',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          _BreakdownRow(
                            label: 'Clinic Visits',
                            amount: earnings.clinicVisit,
                            icon: Icons.local_hospital_outlined,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _BreakdownRow(
                            label: 'Home Visits',
                            amount: earnings.homeVisit,
                            icon: Icons.home_outlined,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _BreakdownRow(
                            label: 'Video Consultations',
                            amount: earnings.videoConsultation,
                            icon: Icons.videocam_outlined,
                          ),
                          const Divider(height: AppSpacing.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sessions Completed',
                                style: theme.textTheme.bodyMedium,
                              ),
                              Text(
                                '${earnings.sessionCount}',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Text('Payout History', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),

            payoutsAsync.when(
              loading: () => const AppListSkeleton(itemCount: 3, itemHeight: 64),
              error: (error, _) => AppErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(payoutsProvider),
              ),
              data: (payouts) {
                if (payouts.isEmpty) {
                  return const AppEmptyView(
                    title: 'No payouts yet',
                    message:
                        'Earnings are transferred to your registered bank account.',
                    icon: Icons.account_balance_outlined,
                  );
                }

                return Column(
                  children: payouts.map((payout) {
                    final bool settled = payout.status == 'PAID';

                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (settled
                                  ? AppColors.success
                                  : AppColors.warning)
                              .withValues(alpha: 0.12),
                          child: Icon(
                            settled ? Icons.check : Icons.schedule,
                            size: 18,
                            color:
                                settled ? AppColors.success : AppColors.warning,
                          ),
                        ),
                        title: Text(
                          '₹${payout.amount.toStringAsFixed(0)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('d MMM yyyy').format(
                            payout.processedAt ?? payout.createdAt,
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: Text(
                          settled ? 'Paid' : 'Processing',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: settled
                                ? AppColors.success
                                : AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.amount,
    required this.icon,
  });

  final String label;
  final double amount;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
