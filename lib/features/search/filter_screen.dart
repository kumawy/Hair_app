import 'package:flutter/material.dart';

import '../../shared/models/hair_attributes.dart';
import 'filter_bottom_sheet.dart';

Future<Map<String, dynamic>?> filterScreen(
    BuildContext context, {
      FaceShape? faceShape,
      HairTexture? texture,
      HairLength? length,
    }) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(25),
      ),
    ),
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    clipBehavior: Clip.antiAlias,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.8,
    ),
    showDragHandle: true,
    enableDrag: true,
    builder: (context) {
      return FilterBottomSheet(
        initialFaceShape: faceShape,
        initialTexture: texture,
        initialLength: length,
      );
    },
  );
}