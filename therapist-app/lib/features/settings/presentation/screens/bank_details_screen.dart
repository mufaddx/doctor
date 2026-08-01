import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';

/// Saved payout account. The account number arrives masked from the server,
/// so it is display-only until the therapist types a new one.
class BankDetail {
  const BankDetail({
    required this.accountHolder,
    required this.accountNumber,
    required this.ifscCode,
    required this.bankName,
    required this.verified,
    this.upiId,
  });

  final String accountHolder;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final bool verified;
  final String? upiId;

  factory BankDetail.fromJson(Map<String, dynamic> json) => BankDetail(
        accountHolder: json['accountHolder'] as String? ?? '',
        accountNumber: json['accountNumber'] as String? ?? '',
        ifscCode: json['ifscCode'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        verified: json['verified'] as bool? ?? false,
        upiId: json['upiId'] as String?,
      );
}

final bankDetailProvider = FutureProvider.autoDispose<BankDetail?>((ref) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>?>(ApiRoutes.bankDetails);

  return data == null ? null : BankDetail.fromJson(data);
});

class BankDetailsScreen extends ConsumerStatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  ConsumerState<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends ConsumerState<BankDetailsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _holderController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _confirmAccountController =
      TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();

  bool _isSaving = false;
  bool _isEditing = false;

  @override
  void dispose() {
    _holderController.dispose();
    _accountController.dispose();
    _confirmAccountController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  void _startEditing(BankDetail? existing) {
    // The masked account number is never prefilled, so it must be retyped
    _holderController.text = existing?.accountHolder ?? '';
    _ifscController.text = existing?.ifscCode ?? '';
    _bankNameController.text = existing?.bankName ?? '';
    _upiController.text = existing?.upiId ?? '';
    _accountController.clear();
    _confirmAccountController.clear();

    setState(() => _isEditing = true);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(apiClientProvider).post(
        ApiRoutes.bankDetails,
        body: {
          'accountHolder': _holderController.text.trim(),
          'accountNumber': _accountController.text.trim(),
          'ifscCode': _ifscController.text.trim().toUpperCase(),
          'bankName': _bankNameController.text.trim(),
          if (_upiController.text.trim().isNotEmpty)
            'upiId': _upiController.text.trim(),
        },
      );

      ref.invalidate(bankDetailProvider);

      if (!mounted) return;
      setState(() => _isEditing = false);
      AppSnackbar.success(
        context,
        'Bank details saved. They will be verified before your next payout.',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      AppSnackbar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankAsync = ref.watch(bankDetailProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Bank Details'),
      ),
      body: bankAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(bankDetailProvider),
        ),
        data: (bank) {
          if (bank != null && !_isEditing) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: (bank.verified
                            ? AppColors.success
                            : AppColors.warning)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        bank.verified
                            ? Icons.verified_outlined
                            : Icons.hourglass_empty,
                        color: bank.verified
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          bank.verified
                              ? 'Verified. Payouts will be sent to this account.'
                              : 'Awaiting verification. Payouts are on hold until this is approved.',
                          style: theme.textTheme.bodySmall,
                        ),
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
                        _DetailRow(
                          label: 'Account Holder',
                          value: bank.accountHolder,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _DetailRow(
                          label: 'Account Number',
                          value: bank.accountNumber,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _DetailRow(label: 'IFSC Code', value: bank.ifscCode),
                        const SizedBox(height: AppSpacing.sm),
                        _DetailRow(label: 'Bank', value: bank.bankName),
                        if (bank.upiId != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _DetailRow(label: 'UPI ID', value: bank.upiId!),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                AppButton(
                  label: 'Update Bank Details',
                  variant: AppButtonVariant.outlined,
                  onPressed: () => _startEditing(bank),
                ),
              ],
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  'Earnings are transferred to this account. Changing it resets verification.',
                  style: theme.textTheme.bodySmall,
                ),

                const SizedBox(height: AppSpacing.lg),

                TextFormField(
                  controller: _holderController,
                  decoration: const InputDecoration(
                    labelText: 'Account Holder Name',
                  ),
                  validator: (value) =>
                      (value?.trim().length ?? 0) < 2 ? 'Enter the name' : null,
                ),

                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _accountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Account Number',
                  ),
                  validator: (value) {
                    final String account = value?.trim() ?? '';
                    if (!RegExp(r'^\d{9,18}$').hasMatch(account)) {
                      return 'Account number must be 9-18 digits';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _confirmAccountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Confirm Account Number',
                  ),
                  // A typo here would send money to the wrong account, so the
                  // number must be entered twice
                  validator: (value) =>
                      value?.trim() != _accountController.text.trim()
                          ? 'Account numbers do not match'
                          : null,
                ),

                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _ifscController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'IFSC Code',
                    hintText: 'HDFC0001234',
                  ),
                  validator: (value) {
                    final String ifsc = (value?.trim() ?? '').toUpperCase();
                    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc)) {
                      return 'Enter a valid IFSC code';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _bankNameController,
                  decoration: const InputDecoration(labelText: 'Bank Name'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Enter the bank name'
                      : null,
                ),

                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _upiController,
                  decoration: const InputDecoration(
                    labelText: 'UPI ID (optional)',
                    hintText: 'name@okhdfcbank',
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                AppButton(
                  label: 'Save Bank Details',
                  isLoading: _isSaving,
                  onPressed: _save,
                ),

                if (bank != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.text,
                    onPressed: () => setState(() => _isEditing = false),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
