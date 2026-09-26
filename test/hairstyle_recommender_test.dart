import 'package:flutter_test/flutter_test.dart';
import 'package:hair_app/features/face_scanner/models/face_analysis.dart';
import 'package:hair_app/features/hairstyles/services/hairstyle_recommender.dart';
import 'package:hair_app/shared/models/hair_attributes.dart';
import 'package:hair_app/shared/models/hairstyle.dart';

Hairstyle style(
  String name, {
  Shape face = Shape.oval,
  HairTexture texture = HairTexture.wavy,
  HairLength length = HairLength.medium,
}) => Hairstyle(
  id: name,
  name: name,
  description: '',
  imageAsset: '',
  suitableFaceShapes: [face],
  suitableTextures: [texture],
  suitableLengths: [length],
  maintenanceLevel: 'low',
  stylingDifficulty: 'easy',
);

void main() {
  const profile = HairProfileSelection(
    faceShape: Shape.oval,
    texture: HairTexture.wavy,
    length: HairLength.medium,
  );
  test(
    'matching tags rank first, shorter styles before styles requiring growth',
    () {
      final catalog = [
        style('Grow', length: HairLength.long),
        style('Shorter', length: HairLength.short),
        style('Exact'),
        style('Other', face: Shape.square, texture: HairTexture.coily),
      ];
      final results = recommendHairstyles(catalog, profile);
      expect(results.map((r) => r.hairstyle.name), [
        'Exact',
        'Shorter',
        'Grow',
        'Other',
      ]);
      expect(results.first.reasons, hasLength(3));
      expect(results.first.considerations, isEmpty);
      expect(results[1].considerations.single, contains('shorter'));
      expect(results[2].considerations.single, contains('more hair length'));
      expect(results.last.considerations, hasLength(2));
      expect(catalog.first.name, 'Grow');
    },
  );
  test('manual diamond and coily selections affect ranking', () {
    final results = recommendHairstyles(
      [
        style('Oval'),
        style('Diamond', face: Shape.diamond, texture: HairTexture.coily),
      ],
      const HairProfileSelection(
        faceShape: Shape.diamond,
        texture: HairTexture.coily,
        length: HairLength.medium,
      ),
    );
    expect(results.first.hairstyle.name, 'Diamond');
    expect(recommendHairstyles([], profile), isEmpty);
  });
}
