import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../search/presentation/providers/therapist_provider.dart';
import '../../data/booking_repository.dart';
import '../widgets/coupon_sheet.dart';

/// Final booking step: confirms the details, applies a coupon and creates the
/// appointment before handing off to payment.
class BookingSummaryScreen extends ConsumerStatefulWidget {
  const BookingSummaryScreen({
    super.key,
    required this.therapistId,
    required this.date,
    required this.startTime,
    required this.type,
  });

  final String therapistId;
  final String date;
  final String startTime;
  final String type;

  @override
  ConsumerState<BookingSummaryScreen> createState() =>
      _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends ConsumerState<BookingSummaryScreen> {
  final TextEditingController _problemController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _selectedAddressId;
  CouponPreview? _appliedCoupon;
  bool _isSubmitting = false;

  /// Platform fee is fixed and mirrored from the backend configuration.
  static const double _platformFee = 20;

  bool get _requiresAddress => widget.type == 'HOME_VISIT';

  @override
  void initState() {
    super.initState();

    // Pre-select the default address so home visits need no extra tap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final addresses = ref.read(currentUserProvider)?.patient?.addresses ?? [];
      if (addresses.isEmpty) return;

      final defaultAddress = addresses.firstWhere(
        (address) => address.isDefault,
        orElse: () => addresses.first,
      );

      setState(() => _selectedAddressId = defaultAddress.id);
    });
  }

  @override
  void dispose() {
    _problemController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double _consultationFee() {
    final therapist =
        ref.read(therapistDetailProvider(widget.therapistId)).value;
    return therapist?.feeForType(widget.type) ?? 0;
  }

  Future<void> _openCouponSheet() async {
    final double orderAmount = _consultationFee();

    final CouponPreview? preview = await showModalBottomSheet<CouponPreview>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CouponSheet(orderAmount: orderAmount),
    );

    if (preview != null) {
      setState(() => _appliedCoupon = preview);
      if (mounted) {
        AppSnackbar.success(
          context,
          '₹${preview.discountAmount.toStringAsFixed(0)} discount applied',
        );
      }
    }
  }

  Future<void> _confirm() async {
    if (_requiresAddress && _selectedAddressId == null) {
      AppSnackbar.error(context, 'Please select an address for the home visit');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appointment =
          await ref.read(bookingRepositoryProvider).createAppointment(
                BookingDraft(
                  therapistId: widget.therapistId,
                  type: widget.type,
                  scheduledDate: widget.date,
                  startTime: widget.startTime,
                  addressId: _requiresAddress ? _selectedAddressId : null,
                  problem: _problemController.text.trim(),
                  notes: _notesController.text.trim(),
                  couponCode: _appliedCoupon?.code,
                ),
              );

      if (!mounted) return;

      context.go('${AppRoutes.home}/${AppRoutes.payment}/${appointment.id}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppSnackbar.error(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(therapistDetailProvider(widget.therapistId));
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Booking Summary'),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(therapistDetailProvider(widget.therapistId)),
        ),
        data: (therapist) {
          final double consultationFee = therapist.feeForType(widget.type);
          final double discount = _appliedCoupon?.discountAmount ?? 0;
          final double total =
              (consultationFee + _platformFee - discount).clamp(0, double.infinity);

          final DateTime date = DateTime.parse(widget.date);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      AppAvatar(
                        imageUrl: therapist.avatarUrl,
                        name: therapist.fullName,
                        size: 52,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              therapist.fullName,
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              _readableType,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.event_outlined,
                        label: 'Date',
                        value: DateFormat('d MMMM yyyy').format(date),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _InfoRow(
                        icon: Icons.access_time,
                        label: 'Time',
                        value: _displayTime,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const _InfoRow(
                        icon: Icons.timelapse_outlined,
                        label: 'Duration',
                        value: '30 Minutes',
                      ),
                    ],
                  ),
                ),
              ),

              if (_requiresAddress) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Visit Address', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),

                if ((user?.patient?.addresses ?? []).isEmpty)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.add_location_alt_outlined),
                      title: const Text('Add an address'),
                      subtitle:
                          const Text('A home visit needs a delivery address'),
                      onTap: () => context.go(
                        '${AppRoutes.profile}/${AppRoutes.addresses}',
                      ),
                    ),
                  )
                else
                  ...user!.patient!.addresses.map((address) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: RadioListTile<String>(
                        value: address.id,
                        groupValue: _selectedAddressId,
                        onChanged: (value) =>
                            setState(() => _selectedAddressId = value),
                        title: Text(
                          address.label,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          address.formatted,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    );
                  }),
              ],

              const SizedBox(height: AppSpacing.md),
              Text('Your Concern', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),

              TextField(
                controller: _problemController,
                maxLength: 200,
                decoration: const InputDecoration(
                  hintText: 'e.g. Lower back pain',
                  counterText: '',
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              TextField(
                controller: _notesController,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Any additional notes for the therapist',
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.local_offer_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    _appliedCoupon == null
                        ? 'Apply a coupon'
                        : 'Coupon ${_appliedCoupon!.code} applied',
                    style: theme.textTheme.bodyMedium,
                  ),
                  subtitle: _appliedCoupon == null
                      ? null
                      : Text(
                          'You saved ₹${_appliedCoupon!.discountAmount.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.success),
                        ),
                  trailing: _appliedCoupon == null
                      ? const Icon(Icons.chevron_right)
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => _appliedCoupon = null),
                        ),
                  onTap: _appliedCoupon == null ? _openCouponSheet : null,
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      _AmountRow(
                        label: 'Consultation Fee',
                        amount: consultationFee,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _AmountRow(label: 'Platform Fee', amount: _platformFee),
                      if (discount > 0) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _AmountRow(
                          label: 'Discount (${_appliedCoupon!.code})',
                          amount: -discount,
                          color: AppColors.success,
                        ),
                      ],
                      const Divider(height: AppSpacing.lg),
                      _AmountRow(
                        label: 'Total Amount',
                        amount: total,
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              AppButton(
                label: 'Proceed to Pay ₹${total.toStringAsFixed(0)}',
                isLoading: _isSubmitting,
                onPressed: _confirm,
              ),

              const SizedBox(height: AppSpacing.md),

              Text(
                'Free cancellation up to 12 hours before the appointment.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }

  String get _readableType => switch (widget.type) {
        'CLINIC_VISIT' => 'Clinic Visit',
        'HOME_VISIT' => 'Home Visit',
        'VIDEO_CONSULTATION' => 'Video Consultation',
        _ => widget.type,
      };

  String get _displayTime {
    final parts = widget.startTime.split(':');
    final int hour = int.parse(parts[0]);
    final String period = hour >= 12 ? 'PM' : 'AM';
    final int displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:${parts[1]} $period';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          value,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.isTotal = false,
    this.color,
  });

  final String label;
  final double amount;
  final bool isTotal;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final TextStyle? style =
        isTotal ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style?.copyWith(color: color)),
        Text(
          // Negative amounts are discounts and read better with a minus sign
          amount < 0
              ? '- ₹${amount.abs().toStringAsFixed(0)}'
              : '₹${amount.toStringAsFixed(0)}',
          style: style?.copyWith(
            color: color ?? (isTotal ? theme.colorScheme.primary : null),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
