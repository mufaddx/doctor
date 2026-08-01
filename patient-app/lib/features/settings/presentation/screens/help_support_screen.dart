import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/support_repository.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _raiseTicket() async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController messageController = TextEditingController();
    bool isSubmitting = false;

    final bool? submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Raise a Ticket', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  validator: (value) =>
                      (value?.trim().isEmpty ?? true) ? 'Enter a subject' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: messageController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'How can we help?',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) =>
                      (value?.trim().isEmpty ?? true) ? 'Describe your issue' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Submit',
                  isLoading: isSubmitting,
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    setState(() => isSubmitting = true);

                    try {
                      await ref.read(supportRepositoryProvider).createTicket(
                            subject: subjectController.text.trim(),
                            message: messageController.text.trim(),
                          );
                      if (!context.mounted) return;
                      Navigator.of(context).pop(true);
                    } catch (error) {
                      setState(() => isSubmitting = false);
                      if (!context.mounted) return;
                      AppSnackbar.error(context, error.toString());
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );

    if (submitted == true) {
      ref.invalidate(myTicketsProvider);
      _tabController.animateTo(1);
      if (mounted) AppSnackbar.success(context, 'Ticket submitted');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Help & Support'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'FAQs'),
            Tab(text: 'My Tickets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_FaqsTab(), _TicketsTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _raiseTicket,
        icon: const Icon(Icons.support_agent_outlined),
        label: const Text('Raise a Ticket'),
      ),
    );
  }
}

class _FaqsTab extends ConsumerWidget {
  const _FaqsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqsAsync = ref.watch(faqsProvider);

    return faqsAsync.when(
      loading: () => const AppListSkeleton(itemHeight: 60),
      error: (error, _) => AppErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(faqsProvider),
      ),
      data: (faqs) {
        if (faqs.isEmpty) {
          return const AppEmptyView(
            title: 'No FAQs yet',
            icon: Icons.help_outline,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: faqs.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final faq = faqs[index];

            return Card(
              child: ExpansionTile(
                title: Text(
                  faq.question,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(faq.answer, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TicketsTab extends ConsumerWidget {
  const _TicketsTab();

  Color _statusColor(String status) => switch (status) {
        'OPEN' => AppColors.info,
        'IN_PROGRESS' => AppColors.warning,
        'RESOLVED' || 'CLOSED' => AppColors.success,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(myTicketsProvider);

    return ticketsAsync.when(
      loading: () => const AppListSkeleton(itemHeight: 76),
      error: (error, _) => AppErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(myTicketsProvider),
      ),
      data: (tickets) {
        if (tickets.isEmpty) {
          return const AppEmptyView(
            title: 'No support tickets yet',
            message: 'Raise a ticket if you need help from our team.',
            icon: Icons.support_agent_outlined,
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myTicketsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              80,
            ),
            itemCount: tickets.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              final Color color = _statusColor(ticket.status);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ticket.subject,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ticket.readableStatus,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(ticket.message, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('d MMM yyyy, h:mm a').format(ticket.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
