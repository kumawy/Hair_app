import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hair_app/features/hairstyles/models/hairstyle_repository.dart';
import 'package:hair_app/shared/models/hair_attributes.dart';
import 'package:hair_app/shared/models/hairstyle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled catalog loads with matching attributes and valid images',
    () async {
      final json =
          jsonDecode(await rootBundle.loadString('assets/data/hairstyles.json'))
              as Map<String, dynamic>;
      final records = json['hairstyles'] as List<dynamic>;
      final hairstyles = await HairstyleRepository().loadHairstyles();

      expect(hairstyles, isNotEmpty);
      expect(hairstyles, hasLength(records.length));
      expect(
        hairstyles.map((style) => style.id).toSet(),
        hasLength(records.length),
      );
      for (var i = 0; i < hairstyles.length; i++) {
        final style = hairstyles[i];
        final record = records[i] as Map<String, dynamic>;
        expect(style.name, record['name']);
        expect(
          style.suitableFaceShapes.map((value) => value.name),
          record['suitableFaceShapes'],
        );
        expect(
          style.suitableTextures.map((value) => value.name),
          record['suitableTextures'],
        );
        expect(
          style.suitableLengths.map((value) => value.name),
          record['suitableLengths'],
        );
        expect(
          (await rootBundle.load(style.imageAsset)).lengthInBytes,
          greaterThan(0),
        );
      }
    },
  );

  test('face shape strings are converted to enum values', () {
    final style = Hairstyle.fromJson({
      'id': 'test',
      'name': 'Test',
      'description': '',
      'imageAsset': '',
      'suitableFaceShapes': ['oval', 'round', 'square'],
      'suitableTextures': ['coily'],
      'suitableLengths': ['medium'],
      'maintenanceLevel': 'Low',
      'stylingDifficulty': 'Easy',
    });
    expect(style.suitableFaceShapes, [Shape.oval, Shape.round, Shape.square]);
    expect(style.suitableTextures, [HairTexture.coily]);
    expect(style.suitableLengths, [HairLength.medium]);
  });
}
