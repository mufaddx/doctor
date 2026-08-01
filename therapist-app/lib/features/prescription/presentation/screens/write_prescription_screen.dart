import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../appointments/presentation/providers/appointments_provider.dart';

/// One editable medicine row. Controllers live here so the row keeps its own
/// text state when the list is reordered or an entry above it is removed.
class _MedicineEntry {
  _MedicineEntry()
      : nameController = TextEditingController(),
        dosageController = TextEditingController(),
        frequencyController = TextEditingController();

  final TextEditingController nameController;
  final TextEditingController dosageController;
  final TextEditingController frequencyController;

  bool get isFilled =>
      nameController.text.trim().isNotEmpty &&
      dosageController.text.trim().isNotEmpty;

  Map<String, String> toJson() => {
        'name': nameController.text.trim(),
        'dosage': dosageController.text.trim(),
        if (frequencyController.text.trim().isNotEmpty)
          'frequency': frequencyController.text.trim(),
      };

  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    frequencyController.dispose();
  }
}

class WritePrescriptionScreen extends ConsumerStatefulWidget {
  const WritePrescriptionScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  ConsumerState<WritePrescriptionScreen> createState() =>
      _WritePrescriptionScreenState();
}

class _WritePrescriptionScreenState
    extends ConsumerState<WritePrescriptionScreen> {
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _adviceController = TextEditingController();

  final List<_MedicineEntry> _medicines = [_MedicineEntry()];

  bool _isSaving = false;

  @override
  void dispose() {
    _diagnosisController.dispose();
    _adviceController.dispose();
    for (final medicine in _medicines) {
      medicine.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final String diagnosis = _diagnosisController.text.trim();

    if (diagnosis.isEmpty) {
      AppSnackbar.error(context, 'Enter a diagnosis');
      return;
    }

    // Half-filled rows are dropped rather than rejected, so a stray blank row
    // does not block saving an otherwise valid prescription.
    final filled = _medicines.where((medicine) => medicine.isFilled).toList();

    if (filled.isEmpty) {
      AppSnackbar.error(context, 'Add at least one medicine with its dosage');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref.read(apiClientProvider).post(
        ApiRoutes.prescriptions,
        body: {
          'appointmentId': widget.appointmentId,
          'diagnosis': diagnosis,
          if (_adviceController.text.trim().isNotEmpty)
            'advice': _adviceController.text.trim(),
          'medicines': filled.map((medicine) => medicine.toJson()).toList(),
        },
      );

      ref.invalidate(appointmentDetailProvider(widget.appointmentId));

      if (!mounted) return;
      AppSnackbar.success(context, 'Prescription saved and sent to the patient');
      context.pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackbar.error(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointmentAsync =
        ref.watch(appointmentDetailProvider(widget.appointmentId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Add Prescription'),
      ),
      body: appointmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(appointmentDetailProvider(widget.appointmentId)),
        ),
        data: (appointment) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    AppAvatar(
                      imageUrl: appointment.patientAvatarUrl,
                      name: appointment.patientName,
                      size: 46,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appointment.patientName,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            appointment.problem ?? appointment.readableType,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Text('Diagnosis', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _diagnosisController,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'e.g. Lumbar Muscle Strain',
                counterText: '',
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Text('Advice', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _adviceController,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'e.g. Avoid heavy lifting and long sitting.',
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Medicines', style: theme.textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _medicines.length >= 20
                      ? null
                      : () => setState(() => _medicines.add(_MedicineEntry())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),

            ...List.generate(_medicines.length, (index) {
              final medicine = _medicines[index];

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: medicine.nameController,
                              decoration: InputDecoration(
                                labelText: 'Medicine ${index + 1}',
                                hintText: 'e.g. Dolo 650',
                                isDense: true,
                              ),
                            ),
                          ),
                          // The last remaining row cannot be removed
                          if (_medicines.length > 1)
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: AppColors.danger,
                              ),
                              onPressed: () => setState(() {
                                _medicines.removeAt(index).dispose();
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: medicine.dosageController,
                              decoration: const InputDecoration(
                                labelText: 'Dosage',
                                hintText: '1-0-1',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: medicine.frequencyController,
                              decoration: const InputDecoration(
                                labelText: 'Instructions',
                                hintText: 'After meals, 5 days',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: AppSpacing.md),

            AppButton(
              label: 'Save Prescription',
              isLoading: _isSaving,
              onPressed: _save,
            ),

            const SizedBox(height: AppSpacing.sm),

            Text(
              'A PDF is generated automatically and shared with the patient.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
