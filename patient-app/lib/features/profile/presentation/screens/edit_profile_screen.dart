import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/profile_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _historyController;

  DateTime? _dateOfBirth;
  String? _gender;
  File? _pickedImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final user = ref.read(currentUserProvider);

    _nameController = TextEditingController(text: user?.fullName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _historyController =
        TextEditingController(text: user?.patient?.medicalHistory ?? '');

    _dateOfBirth = user?.patient?.dateOfBirth;
    _gender = user?.patient?.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _historyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Compressed before upload so slow connections still succeed
      imageQuality: 75,
      maxWidth: 1000,
    );

    if (file != null) setState(() => _pickedImage = File(file.path));
  }

  Future<void> _pickDateOfBirth() async {
    final DateTime now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );

    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repository = ref.read(profileRepositoryProvider);

      // Upload the photo first so a failure there does not leave the text
      // fields saved with a stale avatar
      if (_pickedImage != null) {
        await repository.uploadAvatar(_pickedImage!.path);
      }

      await repository.updateProfile(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        dateOfBirth: _dateOfBirth == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_dateOfBirth!),
        gender: _gender,
        medicalHistory: _historyController.text.trim(),
      );

      await ref.read(authProvider.notifier).refreshUser();

      if (!mounted) return;
      AppSnackbar.success(context, 'Profile updated');
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackbar.error(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Edit Profile'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Center(
              child: Stack(
                children: [
                  if (_pickedImage != null)
                    ClipOval(
                      child: Image.file(
                        _pickedImage!,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    AppAvatar(
                      imageUrl: user?.avatarUrl,
                      name: user?.fullName ?? 'User',
                      size: 96,
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
              validator: (value) {
                if ((value?.trim().length ?? 0) < 2) {
                  return 'Enter your full name';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.md),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) {
                final String email = value?.trim() ?? '';
                if (email.isEmpty) return null;

                if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.md),

            TextFormField(
              enabled: false,
              initialValue: '+91 ${user?.phone ?? ''}',
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                helperText: 'Contact support to change your number',
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: const ['Male', 'Female', 'Other']
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (value) => setState(() => _gender = value),
            ),

            const SizedBox(height: AppSpacing.md),

            InkWell(
              onTap: _pickDateOfBirth,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(
                  _dateOfBirth == null
                      ? 'Select date'
                      : DateFormat('d MMMM yyyy').format(_dateOfBirth!),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            TextFormField(
              controller: _historyController,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Medical History',
                hintText: 'Existing conditions, surgeries, allergies',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            AppButton(
              label: 'Save Changes',
              isLoading: _isSaving,
              onPressed: _save,
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
