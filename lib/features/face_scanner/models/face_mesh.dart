import 'dart:ui';

/// MediaPipe points normalized to the upright, EXIF-corrected photograph.
class FaceMesh {
  const FaceMesh({
    required this.points,
    required this.edges,
    required this.imageSize,
  });
  final List<Offset> points;
  final List<(int, int)> edges;
  final Size imageSize;

  factory FaceMesh.fromJson(Map<String, dynamic> json) {
    final width = json['width'];
    final height = json['height'];
    final rawPoints = json['points'];
    final rawEdges = json['edges'];
    if (width is! num ||
        height is! num ||
        !width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0 ||
        rawPoints is! List ||
        rawPoints.length < 468 ||
        rawPoints.length > 500 ||
        rawEdges is! List ||
        rawEdges.length > 3000) {
      throw const FormatException('Invalid face mesh');
    }
    final points = rawPoints
        .map((p) {
          if (p is! List || p.length != 2 || p[0] is! num || p[1] is! num) {
            throw const FormatException('Invalid landmark');
          }
          final x = (p[0] as num).toDouble();
          final y = (p[1] as num).toDouble();
          if (!x.isFinite || !y.isFinite || x.abs() > 2 || y.abs() > 2) {
            throw const FormatException('Invalid landmark coordinates');
          }
          return Offset(x, y);
        })
        .toList(growable: false);
    final edges = rawEdges
        .map((e) {
          if (e is! List ||
              e.length != 2 ||
              e[0] is! int ||
              e[1] is! int ||
              e[0] < 0 ||
              e[1] < 0 ||
              e[0] >= points.length ||
              e[1] >= points.length) {
            throw const FormatException('Invalid mesh edge');
          }
          return (e[0] as int, e[1] as int);
        })
        .toList(growable: false);
    return FaceMesh(
      points: List.unmodifiable(points),
      edges: List.unmodifiable(edges),
      imageSize: Size(width.toDouble(), height.toDouble()),
    );
  }
}
