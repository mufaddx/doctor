import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/patients_repository.dart';

class MyPatientsScreen extends ConsumerStatefulWidget {
  const MyPatientsScreen({super.key});

  @override
  ConsumerState<MyPatientsScreen> createState() => _MyPatientsScreenState();
}

class _MyPatientsScreenState extends ConsumerState<MyPatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Debounced so typing a name does not fire one request per keystroke.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(patientSearchProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(myPatientsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My Patients')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search patients...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),

          Expanded(
            child: patientsAsync.when(
              loading: () => const AppListSkeleton(itemHeight: 76),
              error: (error, _) => AppErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(myPatientsProvider),
              ),
              data: (patients) {
                if (patients.isEmpty) {
                  return const AppEmptyView(
                    title: 'No patients yet',
                    message:
                        'Patients appear here once you have treated them at least once.',
                    icon: Icons.people_outline,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(myPatientsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    itemCount: patients.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final patient = patients[index];

                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(AppSpacing.sm),
                          leading: AppAvatar(
                            imageUrl: patient.avatarUrl,
                            name: patient.fullName,
                            size: 46,
                          ),
                          title: Text(
                            patient.fullName,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (patient.demographics.isNotEmpty)
                                Text(
                                  patient.demographics,
                                  style: theme.textTheme.bodySmall,
                                ),
                              if (patient.lastAppointment != null)
                                Text(
                                  'Last visit: ${DateFormat('d MMM yyyy').format(patient.lastAppointment!)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go('/patients/${patient.id}'),
                        ),
                      );
                    },
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
