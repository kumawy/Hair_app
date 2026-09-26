import '../../../shared/models/hair_attributes.dart';

class FaceAnalysis {
  final Shape suggestedShape;
  final Map<Shape, double> scores;

  const FaceAnalysis({required this.suggestedShape, required this.scores});

  factory FaceAnalysis.fromJson(Map<String, dynamic> json) {
    Shape parseShape(Object? value) => switch (value) {
      'oval' => Shape.oval,
      'round' => Shape.round,
      'square' => Shape.square,
      'heart' => Shape.heart,
      'diamond' => Shape.diamond,
      'oblong' || 'long' => Shape.long,
      _ => throw const FormatException('Unknown face shape'),
    };
    final shape = parseShape(json['face_shape']);
    final rawScores = json['scores'];
    if (rawScores is! Map<String, dynamic> || rawScores.isEmpty) {
      throw const FormatException('Missing scores');
    }
    final scores = <Shape, double>{};
    for (final entry in rawScores.entries) {
      final value = entry.value;
      if (value is! num || !value.isFinite || value < 0 || value > 1) {
        throw const FormatException('Invalid score');
      }
      scores[parseShape(entry.key)] = value.toDouble();
    }
    if (!scores.containsKey(shape)) {
      throw const FormatException('Missing suggested shape score');
    }
    return FaceAnalysis(
      suggestedShape: shape,
      scores: Map.unmodifiable(scores),
    );
  }

  /// A review hint only, not a calibrated confidence estimate.
  bool get isAmbiguous {
    final sorted = scores.values.toList()..sort((a, b) => b.compareTo(a));
    return sorted.length < 2 ||
        sorted.first < 0.65 ||
        sorted[0] - sorted[1] < 0.15;
  }
}

class HairProfileSelection {
  final Shape faceShape;
  final HairTexture texture;
  final HairLength length;

  const HairProfileSelection({
    required this.faceShape,
    required this.texture,
    required this.length,
  });
}
