import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/therapist_model.dart';
import '../../data/therapist_repository.dart';

/// Home screen carousel.
final topRatedTherapistsProvider =
    FutureProvider.autoDispose<List<TherapistModel>>((ref) {
  return ref.watch(therapistRepositoryProvider).topRated();
});

/// Detail page, keyed by therapist id.
final therapistDetailProvider =
    FutureProvider.autoDispose.family<TherapistDetail, String>((ref, id) {
  return ref.watch(therapistRepositoryProvider).findOne(id);
});

/// Slots for a therapist on a given day.
typedef SlotQuery = ({String therapistId, DateTime date});

final availableSlotsProvider =
    FutureProvider.autoDispose.family<List<TimeSlot>, SlotQuery>((ref, query) {
  return ref
      .watch(therapistRepositoryProvider)
      .availableSlots(query.therapistId, query.date);
});

/// Holds the current filter set; the search list watches this.
final therapistFiltersProvider =
    StateProvider.autoDispose<TherapistFilters>((ref) {
  return const TherapistFilters();
});

class SearchState {
  const SearchState({
    this.therapists = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.total = 0,
    this.error,
  });

  final List<TherapistModel> therapists;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final int total;
  final String? error;

  SearchState copyWith({
    List<TherapistModel>? therapists,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    int? total,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      therapists: therapists ?? this.therapists,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      total: total ?? this.total,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Paginated search list with infinite scroll. Kept as a notifier rather than
/// a FutureProvider because pages accumulate instead of replacing each other.
class TherapistSearchNotifier extends StateNotifier<SearchState> {
  TherapistSearchNotifier(this._repository, this._filters)
      : super(const SearchState()) {
    loadFirstPage();
  }

  final TherapistRepository _repository;
  final TherapistFilters _filters;

  Future<void> loadFirstPage() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _repository.search(_filters, page: 1);

      state = SearchState(
        therapists: result.items,
        page: 1,
        total: result.total,
        hasMore: result.hasMore,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> loadMore() async {
    // Guard against the scroll listener firing repeatedly near the bottom
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final result = await _repository.search(_filters, page: state.page + 1);

      state = state.copyWith(
        therapists: [...state.therapists, ...result.items],
        page: result.page,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (error) {
      state = state.copyWith(isLoadingMore: false, error: error.toString());
    }
  }

  Future<void> refresh() => loadFirstPage();
}

final therapistSearchProvider =
    StateNotifierProvider.autoDispose<TherapistSearchNotifier, SearchState>(
        (ref) {
  // Watching the filters means any filter change rebuilds the notifier and
  // automatically reloads from page one.
  return TherapistSearchNotifier(
    ref.watch(therapistRepositoryProvider),
    ref.watch(therapistFiltersProvider),
  );
});
