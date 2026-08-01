import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../home/presentation/widgets/therapist_card.dart';
import '../../data/therapist_repository.dart';
import '../providers/therapist_provider.dart';
import '../widgets/filter_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    _searchController.text = widget.initialQuery ?? '';
    _scrollController.addListener(_onScroll);

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(therapistFiltersProvider.notifier).update(
              (filters) => filters.copyWith(search: widget.initialQuery),
            );
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Fetches the next page once the user is within one screen of the bottom,
  /// which keeps scrolling smooth instead of stalling at the very end.
  void _onScroll() {
    final double threshold = _scrollController.position.maxScrollExtent - 400;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(therapistSearchProvider.notifier).loadMore();
    }
  }

  /// Debounced so a fast typist triggers one request, not one per keystroke.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      ref
          .read(therapistFiltersProvider.notifier)
          .update((filters) => filters.copyWith(search: value.trim()));
    });
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SearchState state = ref.watch(therapistSearchProvider);
    final TherapistFilters filters = ref.watch(therapistFiltersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Find Therapist'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onQueryChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search therapist, pain or treatment',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onQueryChanged('');
                                setState(() {});
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Badge(
                  isLabelVisible: filters.activeCount > 0,
                  label: Text('${filters.activeCount}'),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: IconButton(
                      onPressed: _openFilters,
                      icon: const Icon(Icons.tune, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (filters.hasActiveFilters)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 4,
                ),
                child: TextButton.icon(
                  onPressed: () => ref
                      .read(therapistFiltersProvider.notifier)
                      .update((f) => f.copyWith(clearFilters: true)),
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear filters'),
                ),
              ),
            ),

          Expanded(child: _buildResults(state)),
        ],
      ),
    );
  }

  Widget _buildResults(SearchState state) {
    if (state.isLoading) return const AppListSkeleton();

    if (state.error != null && state.therapists.isEmpty) {
      return AppErrorView(
        message: state.error!,
        onRetry: () => ref.read(therapistSearchProvider.notifier).refresh(),
      );
    }

    if (state.therapists.isEmpty) {
      return const AppEmptyView(
        title: 'No therapists found',
        message: 'Try widening your filters or searching a different term.',
        icon: Icons.person_search_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(therapistSearchProvider.notifier).refresh(),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.md),
        // One extra row hosts either the loading spinner or the end-of-list note
        itemCount: state.therapists.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == state.therapists.length) {
            if (state.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!state.hasMore) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: Text(
                    '${state.total} therapists found',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            }
            return const SizedBox(height: AppSpacing.lg);
          }

          final therapist = state.therapists[index];

          return TherapistCard(
            therapist: therapist,
            onTap: () => context.go(
              '${AppRoutes.home}/${AppRoutes.therapistProfile}/${therapist.id}',
            ),
          );
        },
      ),
    );
  }
}
