import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../auth/data/user_model.dart';
import '../../data/profile_repository.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    AddressModel? existing,
  }) async {
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddressFormSheet(existing: existing),
    );

    if (saved == true) ref.invalidate(addressesProvider);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AddressModel address,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove address?'),
        content: Text('"${address.label}" will be removed from your saved addresses.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(profileRepositoryProvider).deleteAddress(address.id);
      ref.invalidate(addressesProvider);

      if (!context.mounted) return;
      AppSnackbar.success(context, 'Address removed');
    } catch (error) {
      if (!context.mounted) return;
      AppSnackbar.error(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Addresses'),
      ),
      body: addressesAsync.when(
        loading: () => const AppListSkeleton(itemHeight: 96),
        error: (error, _) => AppErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(addressesProvider),
        ),
        data: (addresses) {
          if (addresses.isEmpty) {
            return AppEmptyView(
              title: 'No saved addresses',
              message: 'Add a home visit address to book faster next time.',
              icon: Icons.location_on_outlined,
              actionLabel: 'Add Address',
              onAction: () => _openForm(context, ref),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(addressesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: addresses.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final address = addresses[index];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              address.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (address.isDefault) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Default',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _openForm(context, ref, existing: address);
                                } else {
                                  _delete(context, ref, address);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Remove')),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          address.formatted,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Address'),
      ),
    );
  }
}

class _AddressFormSheet extends ConsumerStatefulWidget {
  const _AddressFormSheet({this.existing});

  final AddressModel? existing;

  @override
  ConsumerState<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<_AddressFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _labelController;
  late final TextEditingController _line1Controller;
  late final TextEditingController _line2Controller;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;

  double? _latitude;
  double? _longitude;
  bool _isDefault = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final AddressModel? existing = widget.existing;

    _labelController = TextEditingController(text: existing?.label ?? 'Home');
    _line1Controller = TextEditingController(text: existing?.line1 ?? '');
    _line2Controller = TextEditingController(text: existing?.line2 ?? '');
    _cityController = TextEditingController(text: existing?.city ?? '');
    _stateController = TextEditingController(text: existing?.state ?? '');
    _pincodeController = TextEditingController(text: existing?.pincode ?? '');
    _latitude = existing?.latitude;
    _longitude = existing?.longitude;
    _isDefault = existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap() async {
    final LatLng? initial = _latitude != null && _longitude != null
        ? LatLng(_latitude!, _longitude!)
        : null;

    final LatLng? picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (context) => _MapPickerScreen(initialPosition: initial)),
    );

    if (picked == null) return;

    setState(() {
      _latitude = picked.latitude;
      _longitude = picked.longitude;
    });

    try {
      final List<Placemark> placemarks =
          await placemarkFromCoordinates(picked.latitude, picked.longitude);

      if (placemarks.isEmpty || !mounted) return;
      final Placemark place = placemarks.first;

      setState(() {
        if (_line1Controller.text.trim().isEmpty) {
          _line1Controller.text =
              [place.street, place.thoroughfare].where((s) => s != null && s.isNotEmpty).join(', ');
        }
        _cityController.text = place.locality?.isNotEmpty == true
            ? place.locality!
            : (place.subAdministrativeArea ?? _cityController.text);
        _stateController.text = place.administrativeArea ?? _stateController.text;
        _pincodeController.text = place.postalCode ?? _pincodeController.text;
      });
    } catch (_) {
      // Reverse geocoding is a convenience; the user can still fill the form by hand.
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final AddressModel address = AddressModel(
      id: widget.existing?.id ?? '',
      label: _labelController.text.trim(),
      line1: _line1Controller.text.trim(),
      line2: _line2Controller.text.trim().isEmpty ? null : _line2Controller.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pincode: _pincodeController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      isDefault: _isDefault,
    );

    try {
      final repository = ref.read(profileRepositoryProvider);

      if (widget.existing == null) {
        await repository.createAddress(address);
      } else {
        await repository.updateAddress(widget.existing!.id, address);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackbar.error(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.existing == null ? 'Add Address' : 'Edit Address',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'Home, Work, etc.',
                ),
                validator: (value) =>
                    (value?.trim().isEmpty ?? true) ? 'Enter a label' : null,
              ),

              const SizedBox(height: AppSpacing.md),

              OutlinedButton.icon(
                onPressed: _pickOnMap,
                icon: const Icon(Icons.map_outlined),
                label: Text(
                  _latitude == null ? 'Pick Location on Map' : 'Location Selected · Change',
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _line1Controller,
                decoration: const InputDecoration(labelText: 'Address Line 1'),
                validator: (value) =>
                    (value?.trim().isEmpty ?? true) ? 'Enter the address' : null,
              ),

              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _line2Controller,
                decoration: const InputDecoration(
                  labelText: 'Address Line 2 (optional)',
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'City'),
                      validator: (value) =>
                          (value?.trim().isEmpty ?? true) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(labelText: 'State'),
                      validator: (value) =>
                          (value?.trim().isEmpty ?? true) ? 'Required' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _pincodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Pincode'),
                validator: (value) {
                  if (!RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')) {
                    return 'Enter a valid 6-digit pincode';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.sm),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set as default address'),
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
              ),

              const SizedBox(height: AppSpacing.md),

              AppButton(
                label: 'Save Address',
                isLoading: _isSaving,
                onPressed: _save,
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets the patient drop a pin for the home-visit address instead of typing
/// coordinates blind; the centre marker stays fixed while the map moves.
class _MapPickerScreen extends StatefulWidget {
  const _MapPickerScreen({this.initialPosition});

  final LatLng? initialPosition;

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  static const LatLng _fallback = LatLng(28.6139, 77.2090);

  GoogleMapController? _controller;
  late LatLng _center = widget.initialPosition ?? _fallback;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition == null) _useCurrentLocation();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final LatLng point = LatLng(position.latitude, position.longitude);

      setState(() => _center = point);
      _controller?.animateCamera(CameraUpdate.newLatLng(point));
    } catch (_) {
      // Keep the fallback location; the user can still search the map manually.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick Location')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 16),
            onMapCreated: (controller) => _controller = controller,
            onCameraMove: (position) => _center = position.target,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          const Padding(
            padding: EdgeInsets.only(bottom: 40),
            child: Icon(
              Icons.location_pin,
              size: 44,
              color: AppColors.brandTeal,
            ),
          ),

          Positioned(
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: FloatingActionButton.small(
              heroTag: 'locate-me',
              onPressed: _locating ? null : _useCurrentLocation,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),

          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: AppButton(
              label: 'Confirm This Location',
              onPressed: () => Navigator.of(context).pop(_center),
            ),
          ),
        ],
      ),
    );
  }
}
