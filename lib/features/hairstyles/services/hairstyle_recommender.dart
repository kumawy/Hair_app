import '../../../shared/models/hairstyle.dart';
import '../../face_scanner/models/face_analysis.dart';

class HairstyleRecommendation {
  final Hairstyle hairstyle;
  final int score;
  final List<String> reasons;
  final List<String> considerations;

  const HairstyleRecommendation({
    required this.hairstyle,
    required this.score,
    required this.reasons,
    required this.considerations,
  });
}

/// Ranks editorial catalog tags. Scores are not probabilities or ML predictions.
List<HairstyleRecommendation> recommendHairstyles(
  List<Hairstyle> catalog,
  HairProfileSelection profile,
) {
  final ranked = catalog.map((style) {
    final face = style.suitableFaceShapes.contains(profile.faceShape);
    final texture = style.suitableTextures.contains(profile.texture);
    final length = style.suitableLengths.contains(profile.length);
    final canCutShorter = style.suitableLengths.any(
      (l) => l.index < profile.length.index,
    );
    return HairstyleRecommendation(
      hairstyle: style,
      score:
          (face ? 3 : 0) +
          (texture ? 3 : 0) +
          (length
              ? 2
              : canCutShorter
              ? 1
              : 0),
      reasons: [
        if (face) 'Listed for ${profile.faceShape.name} faces',
        if (texture) 'Listed for ${profile.texture.name} hair',
        if (length) 'Matches your length category',
      ],
      considerations: [
        if (!face) 'Your face shape is not listed for this style',
        if (!texture) 'Your hair texture is not listed for this style',
        if (!length)
          canCutShorter
              ? 'A shorter style to discuss with your barber'
              : 'May need more hair length',
      ],
    );
  }).toList();
  ranked.sort((a, b) {
    final score = b.score.compareTo(a.score);
    return score != 0 ? score : a.hairstyle.name.compareTo(b.hairstyle.name);
  });
  return ranked;
}

/// Do not advertise incompatible textures or face shapes as personal matches.
List<HairstyleRecommendation> compatibleRecommendations(
  List<Hairstyle> catalog,
  HairProfileSelection profile,
) => recommendHairstyles(catalog, profile)
    .where(
      (item) =>
          item.hairstyle.suitableTextures.contains(profile.texture) &&
          item.hairstyle.suitableFaceShapes.contains(profile.faceShape),
    )
    .toList();
