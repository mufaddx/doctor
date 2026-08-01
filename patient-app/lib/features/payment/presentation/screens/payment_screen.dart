import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../appointments/presentation/providers/appointments_provider.dart';
import '../../data/payment_repository.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late final Razorpay _razorpay;

  String _selectedMethod = 'UPI';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    // Failing to clear listeners leaks the native handler across screens
    _razorpay.clear();
    super.dispose();
  }

  /// Opens the Razorpay checkout, or settles instantly when paying by wallet.
  Future<void> _startPayment(double amount, String patientName, String phone) async {
    setState(() => _isProcessing = true);

    try {
      final order = await ref.read(paymentRepositoryProvider).createOrder(
            appointmentId: widget.appointmentId,
            method: _selectedMethod,
          );

      // Wallet payments never reach the gateway; the server has already
      // debited the balance and marked the booking paid.
      if (order.isSettled) {
        _completeBooking();
        return;
      }

      _razorpay.open({
        'key': order.razorpayKeyId,
        'order_id': order.razorpayOrderId,
        'amount': (amount * 100).round(),
        'currency': 'INR',
        'name': 'Touch of Cure',
        'description': 'Physiotherapy consultation',
        'prefill': {'contact': phone, 'name': patientName},
        'theme': {'color': '#0F766E'},
        'retry': {'enabled': true, 'max_count': 2},
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      AppSnackbar.error(context, error.toString());
    }
  }

  /// The gateway callback is only a claim; the server verifies the HMAC
  /// signature before the booking is treated as paid.
  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    try {
      await ref.read(paymentRepositoryProvider).verifyPayment(
            razorpayOrderId: response.orderId!,
            razorpayPaymentId: response.paymentId!,
            razorpaySignature: response.signature!,
          );

      _completeBooking();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      AppSnackbar.error(
        context,
        'Payment could not be verified. If money was deducted it will be refunded automatically.',
      );
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _isProcessing = false);

    AppSnackbar.error(
      context,
      response.message ?? 'Payment failed. Please try another method.',
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    AppSnackbar.info(context, 'Complete the payment in ${response.walletName}');
  }

  void _completeBooking() {
    if (!mounted) return;

    // Both lists are stale once a booking is paid
    ref.invalidate(appointmentsProvider);
    ref.invalidate(upcomingAppointmentProvider);
    ref.read(authProvider.notifier).refreshUser();

    context.go('${AppRoutes.home}/${AppRoutes.bookingSuccess}/${widget.appointmentId}');
  }

  @override
  Widget build(BuildContext context) {
    final appointmentAsync =
        ref.watch(appointmentDetailProvider(widget.appointmentId));
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isProcessing ? null : () => context.pop(),
        ),
        title: const Text('Select Payment Method'),
      ),
      body: appointmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(appointmentDetailProvider(widget.appointmentId)),
        ),
        data: (appointment) {
          final double walletBalance = user?.walletBalance ?? 0;
          final bool walletSufficient = walletBalance >= appointment.totalAmount;

          final methods = <({String value, String title, String? subtitle, IconData icon, bool enabled})>[
            (
              value: 'UPI',
              title: 'UPI',
              subtitle: 'GPay, PhonePe, Paytm and more',
              icon: Icons.account_balance_wallet_outlined,
              enabled: true,
            ),
            (
              value: 'CARD',
              title: 'Credit / Debit Card',
              subtitle: 'Visa, Mastercard, RuPay',
              icon: Icons.credit_card,
              enabled: true,
            ),
            (
              value: 'NETBANKING',
              title: 'Net Banking',
              subtitle: 'All major banks supported',
              icon: Icons.account_balance_outlined,
              enabled: true,
            ),
            (
              value: 'WALLET',
              title: 'Touch of Cure Wallet',
              // A short balance disables the option rather than failing later
              subtitle: walletSufficient
                  ? '₹${walletBalance.toStringAsFixed(0)} available'
                  : 'Insufficient balance (₹${walletBalance.toStringAsFixed(0)})',
              icon: Icons.account_balance_wallet,
              enabled: walletSufficient,
            ),
          ];

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  ...methods.map((method) {
                    final bool selected = _selectedMethod == method.value;

                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Opacity(
                        opacity: method.enabled ? 1 : 0.5,
                        child: RadioListTile<String>(
                          value: method.value,
                          groupValue: _selectedMethod,
                          onChanged: method.enabled && !_isProcessing
                              ? (value) =>
                                  setState(() => _selectedMethod = value!)
                              : null,
                          secondary: Icon(
                            method.icon,
                            color: selected ? theme.colorScheme.primary : null,
                          ),
                          title: Text(
                            method.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: method.subtitle == null
                              ? null
                              : Text(
                                  method.subtitle!,
                                  style: theme.textTheme.bodySmall,
                                ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: AppSpacing.md),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          _Row(
                            label: 'Consultation Fee',
                            value: '₹${appointment.consultationFee.toStringAsFixed(0)}',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _Row(
                            label: 'Platform Fee',
                            value: '₹${appointment.platformFee.toStringAsFixed(0)}',
                          ),
                          if (appointment.discountAmount > 0) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _Row(
                              label: 'Discount',
                              value:
                                  '- ₹${appointment.discountAmount.toStringAsFixed(0)}',
                              color: AppColors.success,
                            ),
                          ],
                          const Divider(height: AppSpacing.lg),
                          _Row(
                            label: 'Total Payable',
                            value: '₹${appointment.totalAmount.toStringAsFixed(0)}',
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  AppButton(
                    label:
                        'Pay ₹${appointment.totalAmount.toStringAsFixed(0)} Securely',
                    isLoading: _isProcessing,
                    onPressed: () => _startPayment(
                      appointment.totalAmount,
                      user?.fullName ?? '',
                      user?.phone ?? '',
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Payments are secured by Razorpay',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),
                ],
              ),

              if (_isProcessing)
                const AppLoadingOverlay(message: 'Processing payment...'),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.color,
  });

  final String label;
  final String value;
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
        Text(label, style: style),
        Text(
          value,
          style: style?.copyWith(
            color: color ?? (isTotal ? theme.colorScheme.primary : null),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
