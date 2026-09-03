import 'hair_attributes.dart';

class Hairstyle {
  final String id;
  final String name;
  final String description;
  final String imageAsset;

  final List<FaceShape> suitableFaceShapes;
  final List<HairTexture> suitableTextures;
  final List<HairLength> suitableLengths;

  final String maintenanceLevel;
  final String stylingDifficulty;

  Hairstyle({
    required this.id,
    required this.name,
    required this.description,
    required this.imageAsset,
    required this.suitableFaceShapes,
    required this.suitableTextures,
    required this.suitableLengths,
    required this.maintenanceLevel,
    required this.stylingDifficulty,
  });

  factory Hairstyle.fromJson(Map<String, dynamic> json) {
    return Hairstyle(
      id: json['id'] as String,

      name: json['name'] as String,

      description: json['description'] as String,

      imageAsset: json['imageAsset'] as String,

      suitableFaceShapes:
      (json['suitableFaceShapes'] as List<dynamic>)
          .map(
            (shape) => FaceShape.values.byName(
          shape as String,
        ),
      )
          .toList(),

      suitableTextures:
      (json['suitableTextures'] as List<dynamic>)
          .map(
            (texture) => HairTexture.values.byName(
          texture as String,
        ),
      )
          .toList(),

      suitableLengths:
      (json['suitableLengths'] as List<dynamic>)
          .map(
            (length) => HairLength.values.byName(
          length as String,
        ),
      )
          .toList(),

      maintenanceLevel:
      json['maintenanceLevel'] as String,

      stylingDifficulty:
      json['stylingDifficulty'] as String,
    );
  }
}