import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/booking_repository.dart';

/// Lets the user pick from available offers or type a code manually. Both
/// paths validate server-side so the shown discount is authoritative.
class CouponSheet extends ConsumerStatefulWidget {
  const CouponSheet({super.key, required this.orderAmount});

  final double orderAmount;

  @override
  ConsumerState<CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends ConsumerState<CouponSheet> {
  final TextEditingController _codeController = TextEditingController();

  bool _isValidating = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _apply(String code) async {
    if (code.trim().isEmpty) {
      setState(() => _error = 'Enter a coupon code');
      return;
    }

    setState(() {
      _isValidating = true;
      _error = null;
    });

    try {
      final CouponPreview preview = await ref
          .read(bookingRepositoryProvider)
          .previewCoupon(code.trim().toUpperCase(), widget.orderAmount);

      if (!mounted) return;
      Navigator.of(context).pop(preview);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final couponsAsync = ref.watch(availableCouponsProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          // Lifts the sheet above the keyboard when the code field is focused
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Apply Coupon', style: theme.textTheme.titleLarge),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Enter coupon code',
                          errorText: _error,
                          prefixIcon: const Icon(Icons.local_offer_outlined),
                        ),
                        onSubmitted: _apply,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton(
                      label: 'Apply',
                      expanded: false,
                      isLoading: _isValidating,
                      onPressed: () => _apply(_codeController.text),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),

              Expanded(
                child: couponsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => AppErrorView(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(availableCouponsProvider),
                  ),
                  data: (coupons) {
                    if (coupons.isEmpty) {
                      return const AppEmptyView(
                        title: 'No offers available',
                        message: 'You have no coupons to use right now.',
                        icon: Icons.local_offer_outlined,
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: coupons.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final coupon = coupons[index];

                        // Offers below the minimum order value are shown but
                        // disabled, so the user knows why they cannot use them
                        final bool eligible = coupon.minOrderValue == null ||
                            widget.orderAmount >= coupon.minOrderValue!;

                        return Opacity(
                          opacity: eligible ? 1 : 0.5,
                          child: Card(
                            child: ListTile(
                              onTap: eligible && !_isValidating
                                  ? () => _apply(coupon.code)
                                  : null,
                              title: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      coupon.code,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      coupon.description,
                                      style: theme.textTheme.bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  eligible
                                      ? 'Valid until ${DateFormat('d MMM yyyy').format(coupon.validUntil)}'
                                      : 'Minimum order ₹${coupon.minOrderValue!.toStringAsFixed(0)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
