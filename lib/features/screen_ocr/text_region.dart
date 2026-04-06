class TextRegion {
  final double x;
  final double y;
  final double w;
  final double h;
  final double confidence;

  const TextRegion({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.confidence = 1.0,
  });

  factory TextRegion.fromJson(Map<String, dynamic> json) {
    return TextRegion(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      w: (json['w'] as num).toDouble(),
      h: (json['h'] as num).toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'confidence': confidence,
      };

  @override
  String toString() =>
      'TextRegion(x: $x, y: $y, w: $w, h: $h, confidence: $confidence)';
}
