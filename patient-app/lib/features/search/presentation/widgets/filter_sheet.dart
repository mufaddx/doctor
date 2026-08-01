import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../data/therapist_repository.dart';
import '../providers/therapist_provider.dart';

/// Specialisations offered on the platform. Kept client-side because the list
/// is short and stable; a longer list would come from an endpoint.
const List<String> _specializations = [
  'Back Pain',
  'Neck Pain',
  'Sports Injury',
  'Post Surgery',
  'Knee Pain',
  'Shoulder',
  'Arthritis',
  'Posture Correction',
];

const List<({String label, String sortBy, String sortOrder})> _sortOptions = [
  (label: 'Highest rated', sortBy: 'ratingAvg', sortOrder: 'desc'),
  (label: 'Most experienced', sortBy: 'experienceYears', sortOrder: 'desc'),
  (label: 'Price: low to high', sortBy: 'clinicFee', sortOrder: 'asc'),
  (label: 'Price: high to low', sortBy: 'clinicFee', sortOrder: 'desc'),
];

class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key});

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late List<String> _selectedSpecializations;
  late double _minRating;
  late double _maxFee;
  late int _minExperience;
  late String _sortBy;
  late String _sortOrder;

  static const double _feeCeiling = 2000;

  @override
  void initState() {
    super.initState();

    // Seed the draft from the live filters so the sheet opens with the
    // user's current selection rather than defaults.
    final TherapistFilters current = ref.read(therapistFiltersProvider);

    _selectedSpecializations = List<String>.from(current.specialization);
    _minRating = current.minRating ?? 0;
    _maxFee = current.maxFee ?? _feeCeiling;
    _minExperience = current.minExperience ?? 0;
    _sortBy = current.sortBy;
    _sortOrder = current.sortOrder;
  }

  void _apply() {
    ref.read(therapistFiltersProvider.notifier).update((filters) {
      return TherapistFilters(
        search: filters.search,
        latitude: filters.latitude,
        longitude: filters.longitude,
        radiusKm: filters.radiusKm,
        specialization: _selectedSpecializations,
        // Zero means "no minimum", so it is sent as null rather than 0
        minRating: _minRating > 0 ? _minRating : null,
        minExperience: _minExperience > 0 ? _minExperience : null,
        maxFee: _maxFee < _feeCeiling ? _maxFee : null,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      );
    });

    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _selectedSpecializations = [];
      _minRating = 0;
      _maxFee = _feeCeiling;
      _minExperience = 0;
      _sortBy = 'ratingAvg';
      _sortOrder = 'desc';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filters', style: theme.textTheme.titleLarge),
                  TextButton(onPressed: _reset, child: const Text('Reset')),
                ],
              ),
            ),

            const Divider(height: AppSpacing.lg),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  _SectionTitle('Specialization'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _specializations.map((item) {
                      final bool selected =
                          _selectedSpecializations.contains(item);

                      return FilterChip(
                        label: Text(item),
                        selected: selected,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          color: selected ? Colors.white : null,
                        ),
                        onSelected: (value) {
                          setState(() {
                            value
                                ? _selectedSpecializations.add(item)
                                : _selectedSpecializations.remove(item);
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  _SectionTitle(
                    'Minimum rating',
                    trailing: _minRating == 0
                        ? 'Any'
                        : '${_minRating.toStringAsFixed(1)}+',
                  ),
                  Slider(
                    value: _minRating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    label: _minRating == 0
                        ? 'Any'
                        : _minRating.toStringAsFixed(1),
                    onChanged: (value) => setState(() => _minRating = value),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  _SectionTitle(
                    'Maximum fee',
                    trailing: _maxFee >= _feeCeiling
                        ? 'Any'
                        : '₹${_maxFee.toStringAsFixed(0)}',
                  ),
                  Slider(
                    value: _maxFee,
                    min: 100,
                    max: _feeCeiling,
                    divisions: 19,
                    label: '₹${_maxFee.toStringAsFixed(0)}',
                    onChanged: (value) => setState(() => _maxFee = value),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  _SectionTitle(
                    'Minimum experience',
                    trailing:
                        _minExperience == 0 ? 'Any' : '$_minExperience+ years',
                  ),
                  Slider(
                    value: _minExperience.toDouble(),
                    min: 0,
                    max: 20,
                    divisions: 20,
                    label: '$_minExperience years',
                    onChanged: (value) =>
                        setState(() => _minExperience = value.round()),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  _SectionTitle('Sort by'),
                  ..._sortOptions.map((option) {
                    final bool selected =
                        _sortBy == option.sortBy && _sortOrder == option.sortOrder;

                    return RadioListTile<String>(
                      value: '${option.sortBy}_${option.sortOrder}',
                      groupValue: '${_sortBy}_$_sortOrder',
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        option.label,
                        style: theme.textTheme.bodyMedium,
                      ),
                      onChanged: (_) => setState(() {
                        _sortBy = option.sortBy;
                        _sortOrder = option.sortOrder;
                      }),
                      selected: selected,
                    );
                  }),

                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppButton(label: 'Apply Filters', onPressed: _apply),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (trailing != null)
            Text(
              trailing!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
        ],
      ),
    );
  }
}
