import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hair_app/shared/widgets/fading_app_bar.dart';

import '../../auth/auth_repository.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../../shared/models/hair_attributes.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController();
  final _surname = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _surname.dispose();
    super.dispose();
  }

  bool _isInitialized = false;
  bool _isSaving = false;
  String? _saveError;
  Shape? _selectedFaceShape;
  HairTexture? _selectedHairTexture;
  HairLength? _selectedHairLength;

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .updateHairProfile(
            name: _name.text,
            surname: _surname.text,
            faceShape: _selectedFaceShape,
            hairTexture: _selectedHairTexture,
            hairLength: _selectedHairLength,
          );
      if (!mounted) return;

      ref.invalidate(userProfileProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved')));
      if (context.canPop()) context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saveError = 'Failed to save profile. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _choices<T extends Enum>({
    required String title,
    required List<T> values,
    required T? selected,
    required String Function(T) label,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final value in values)
              ChoiceChip(
                key: ValueKey('$title-${value.name}'),
                label: Text(label(value)),
                selected: selected == value,
                onSelected: _isSaving
                    ? null
                    : (isSelected) =>
                          setState(() => onChanged(isSelected ? value : null)),
              ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final profileAsync = ref.watch(userProfileProvider);

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: FadingAppBar(
          title: Text('Edit Profile', style: textTheme.headlineLarge),
        ),
        body: profileAsync.when(
          data: (profile) {
            if (profile == null) {
              _isInitialized = false;
              return Center(
                child: TextButton(
                  onPressed: () => context.push('/loginscreen'),
                  child: const Text('Sign in to edit your profile'),
                ),
              );
            }
            if (!_isInitialized) {
              _name.text = profile.name;
              _surname.text = profile.surname;
              _selectedFaceShape = profile.faceShape;
              _selectedHairTexture = profile.hairTexture;
              _selectedHairLength = profile.hairLength;
              _isInitialized = true;
            }

            return ListView(
              padding: FadingAppBar.contentPadding(
                context,
                const EdgeInsets.all(20),
              ),
              children: [
                TextField(
                  controller: _name,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'First name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _surname,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
                const SizedBox(height: 24),
                _choices<Shape>(
                  title: 'Face Shape',
                  values: Shape.values,
                  selected: _selectedFaceShape,
                  label: (value) => value.label,
                  onChanged: (value) => _selectedFaceShape = value,
                ),
                _choices<HairTexture>(
                  title: 'Hair Texture',
                  values: HairTexture.values,
                  selected: _selectedHairTexture,
                  label: (value) => value.label,
                  onChanged: (value) => _selectedHairTexture = value,
                ),
                _choices<HairLength>(
                  title: 'Hair Length',
                  values: [
                    HairLength.long,
                    HairLength.medium,
                    HairLength.short,
                  ],
                  selected: _selectedHairLength,
                  label: (value) => value.label,
                  onChanged: (value) => _selectedHairLength = value,
                ),
                if (_saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _saveError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save changes'),
                  ),
                ),
              ],
            );
          },
          error: (error, stackTrace) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(userProfileProvider),
              child: const Text('Failed to load profile. Tap to retry.'),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
