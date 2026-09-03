import 'package:flutter/material.dart';
import '../../../../../shared/models/hair_attributes.dart';

class FilterBottomSheet extends StatefulWidget {
  final FaceShape? initialFaceShape;
  final HairTexture? initialTexture;
  final HairLength? initialLength;

  const FilterBottomSheet({
    super.key,
    this.initialFaceShape,
    this.initialTexture,
    this.initialLength,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  FaceShape? _faceShape;
  HairTexture? _texture;
  HairLength? _length;

  @override
  void initState() {
    super.initState();
    _faceShape = widget.initialFaceShape;
    _texture = widget.initialTexture;
    _length = widget.initialLength;
  }

  void _reset() {
    setState(() {
      _faceShape = null;
      _texture = null;
      _length = null;
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      {
        'faceShape': _faceShape,
        'texture': _texture,
        'length': _length,
      },
    );
  }

  String _faceShapeName(FaceShape value) {
    switch (value) {
      case FaceShape.oval: return 'Oval';
      case FaceShape.round: return 'Round';
      case FaceShape.square: return 'Square';
      case FaceShape.heart: return 'Heart';
      case FaceShape.diamond: return 'Diamond';
      case FaceShape.long: return 'Long';
    }
  }

  String _textureName(HairTexture value) {
    switch (value) {
      case HairTexture.straight: return 'Straight';
      case HairTexture.wavy: return 'Wavy';
      case HairTexture.curly: return 'Curly';
      case HairTexture.coily: return 'Coily';
    }
  }

  String _lengthName(HairLength value) {
    switch (value) {
      case HairLength.short: return 'Short';
      case HairLength.medium: return 'Medium';
      case HairLength.long: return 'Long';
    }
  }

  Widget _sectionTitle(String title, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 18),
      child: Text(
        title,
        style: textTheme.titleMedium?.copyWith(fontSize: 17),
      ),
    );
  }

  Widget _choiceChip({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(title),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  Widget _wrap(List<Widget> children) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }

  int get _activeFilters {
    int count = 0;
    if (_faceShape != null) count++;
    if (_texture != null) count++;
    if (_length != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filters',
                    style: textTheme.titleLarge,
                  ),
                ),
                if (_activeFilters > 0)
                  TextButton(
                    onPressed: _reset,
                    child: Text(
                      'Reset',
                      style: TextStyle(color: theme.colorScheme.tertiary),
                    ),
                  ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Face shape', textTheme),
                    _wrap(
                      FaceShape.values.map((value) {
                        return _choiceChip(
                          title: _faceShapeName(value),
                          selected: _faceShape == value,
                          onTap: () {
                            setState(() {
                              _faceShape = _faceShape == value ? null : value;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    _sectionTitle('Hair texture', textTheme),
                    _wrap(
                      HairTexture.values.map((value) {
                        return _choiceChip(
                          title: _textureName(value),
                          selected: _texture == value,
                          onTap: () {
                            setState(() {
                              _texture = _texture == value ? null : value;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    _sectionTitle('Hair length', textTheme),
                    _wrap(
                      HairLength.values.map((value) {
                        return _choiceChip(
                          title: _lengthName(value),
                          selected: _length == value,
                          onTap: () {
                            setState(() {
                              _length = _length == value ? null : value;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _apply,
                child: Text(
                  _activeFilters == 0
                      ? 'Show all hairstyles'
                      : 'Apply filters ($_activeFilters)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
