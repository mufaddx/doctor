import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/wallet_repository.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletBalanceProvider);
    final transactionsAsync = ref.watch(walletTransactionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Wallet'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(walletBalanceProvider);
          ref.invalidate(walletTransactionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Container(
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
                    'Wallet Balance',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  balanceAsync.when(
                    loading: () => const SizedBox(
                      height: 34,
                      width: 34,
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    error: (_, __) => const Text(
                      '--',
                      style: TextStyle(color: Colors.white, fontSize: 30),
                    ),
                    data: (balance) => Text(
                      '₹${balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Your balance is applied automatically at checkout.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Text('Transaction History', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),

            transactionsAsync.when(
              loading: () => const AppListSkeleton(itemCount: 4, itemHeight: 64),
              error: (error, _) => AppErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(walletTransactionsProvider),
              ),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const AppEmptyView(
                    title: 'No transactions yet',
                    message: 'Refunds and referral bonuses will appear here.',
                    icon: Icons.receipt_long_outlined,
                  );
                }

                return Column(
                  children: transactions.map((transaction) {
                    final Color color = transaction.isCredit
                        ? AppColors.success
                        : AppColors.danger;

                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: Icon(
                            transaction.isCredit
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: color,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          transaction.readableSource,
                          style: theme.textTheme.bodyMedium,
                        ),
                        subtitle: Text(
                          DateFormat('d MMM yyyy, h:mm a')
                              .format(transaction.createdAt),
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: Text(
                          // Sign makes the direction unmistakable at a glance
                          '${transaction.isCredit ? '+' : '-'} ₹${transaction.amount.toStringAsFixed(0)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
