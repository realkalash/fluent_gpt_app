class AnnotationPoint {
  final double x;
  final double y;
  final String label;

  AnnotationPoint({required this.x, required this.y, required this.label});

  factory AnnotationPoint.fromJson(Map<String, dynamic> json) {
    final x = json['x'] is String ? double.parse(json['x']) : json['x'];
    final y = json['y'] is String ? double.parse(json['y']) : json['y'];
    return AnnotationPoint(
      x: x,
      y: y,
      label: json['label'] as String? ?? '',
    );
  }
}