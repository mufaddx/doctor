import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/prescription_model.dart';
import '../../data/prescription_repository.dart';

class PrescriptionScreen extends ConsumerWidget {
  const PrescriptionScreen({super.key, required this.prescriptionId});

  final String prescriptionId;

  Future<void> _openPdf(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    final bool opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      AppSnackbar.error(context, 'Could not open the prescription PDF');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptionAsync = ref.watch(prescriptionProvider(prescriptionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Prescription')),
      body: prescriptionAsync.when(
        loading: () => const AppListSkeleton(itemCount: 3, itemHeight: 100),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(prescriptionProvider(prescriptionId)),
        ),
        data: (prescription) => _Body(
          prescription: prescription,
          onOpenPdf: prescription.pdfUrl == null
              ? null
              : () => _openPdf(context, prescription.pdfUrl!),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.prescription, this.onOpenPdf});

  final PrescriptionModel prescription;
  final VoidCallback? onOpenPdf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                AppAvatar(
                  imageUrl: prescription.therapistAvatarUrl,
                  name: prescription.therapistName,
                  size: 48,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prescription.therapistName,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'Issued ${DateFormat('d MMM yyyy').format(prescription.createdAt)}',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Diagnosis', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(prescription.diagnosis, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),

        if (prescription.advice != null && prescription.advice!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Advice', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(prescription.advice!, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],

        if (prescription.medicines.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Medicines', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  for (final medicine in prescription.medicines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.circle, size: 6),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: theme.textTheme.bodyMedium,
                                children: [
                                  TextSpan(
                                    text: medicine.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' — ${medicine.dosage}'
                                        '${medicine.frequency != null ? ' (${medicine.frequency})' : ''}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),

        if (onOpenPdf != null)
          AppButton(
            label: 'Download PDF',
            icon: Icons.picture_as_pdf_outlined,
            onPressed: onOpenPdf,
          ),
      ],
    );
  }
}
