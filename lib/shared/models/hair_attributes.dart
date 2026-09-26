enum Shape {
  oval,
  round,
  square,
  heart,
  diamond,
  long,
}

enum HairTexture {
  straight,
  wavy,
  curly,
  coily,
}

enum HairLength {
  short,
  medium,
  long,
}

extension FaceShapeDisplay on Shape {
  String get label => name[0].toUpperCase() + name.substring(1);
}

extension HairTextureDisplay on HairTexture {
  String get label => name[0].toUpperCase() + name.substring(1);
}

extension HairLengthDisplay on HairLength {
  String get label => name[0].toUpperCase() + name.substring(1);
}