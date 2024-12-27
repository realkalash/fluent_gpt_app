import 'package:fluent_gpt/common/annotation_point.dart';
import 'package:flutter/material.dart';

/// A widget that displays an image with annotation labels at specific coordinates.
///
/// The widget scales coordinates from the original image size to the displayed size.
///
/// Parameters:
/// - [image] - Can be either Image.network or Image.asset widget
/// - [annotations] - List of AnnotationPoint objects containing coordinates and labels
/// - [originalWidth] - The width of the source image (e.g., 1920 for HD image)
/// - [originalHeight] - The height of the source image (e.g., 1080 for HD image)
/// - [labelStyle] - Optional TextStyle for annotation labels
/// - [labelBackground] - Optional Color for label background
class AnnotatedImageOverlay extends StatefulWidget {
  final Widget image;
  final List<AnnotationPoint> annotations;
  final double originalWidth;
  final double originalHeight;
  final TextStyle? labelStyle;
  final Color labelBackground;

  const AnnotatedImageOverlay({
    super.key,
    required this.image,
    required this.annotations,
    required this.originalWidth,
    required this.originalHeight,
    this.labelStyle,
    this.labelBackground = const Color(0xCC000000),
  });

  @override
  State<AnnotatedImageOverlay> createState() => _AnnotatedImageOverlayState();
}

class _AnnotatedImageOverlayState extends State<AnnotatedImageOverlay> {
  String? hoveredLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate aspect ratios
        final originalAspectRatio =
            widget.originalWidth / widget.originalHeight;
        final containerAspectRatio =
            constraints.maxWidth / constraints.maxHeight;

        // Calculate actual display dimensions maintaining aspect ratio
        late final double displayWidth;
        late final double displayHeight;
        late final double offsetX;
        // late final double offsetY;

        if (containerAspectRatio > originalAspectRatio) {
          // Container is wider than image
          displayHeight = constraints.maxHeight;
          displayWidth = displayHeight * originalAspectRatio;
          offsetX = (constraints.maxWidth - displayWidth) / 1;
          // offsetY = 0;
        }
        // else {
        //   // Container is taller than image
        //   displayWidth = constraints.maxWidth;
        //   displayHeight = displayWidth / originalAspectRatio;
        //   offsetX = 0;
        //   offsetY = (constraints.maxHeight - displayHeight) / 2;
        // }

        // Calculate scale factors
        // final scaleX = 1;
        // final scaleY = 1;
        final scaleX = displayWidth / (widget.originalWidth + 48);
        // final scaleY = displayHeight / widget.originalHeight;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Base image
            Positioned.fill(child: widget.image),

            ...widget.annotations.map((point) {
              final scaledX = (point.x * scaleX) + offsetX;
              // final scaledY = (point.y * scaleY) + offsetY;

              // Calculate maximum allowed width for the label
              final remainingWidth = constraints.maxWidth - scaledX;
              final maxLabelWidth =
                  remainingWidth.clamp(0.0, 200.0); // Max 200px

              return Positioned(
                left: scaledX,
                top: point.y,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // blue dot marker
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1,
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxLabelWidth,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.labelBackground,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SelectableText(
                          point.label,
                          minLines: 1,
                          style: widget.labelStyle ??
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}


/* 

import 'package:fluent_gpt/common/annotation_point.dart';
import 'package:flutter/material.dart';

/// A widget that displays an image with annotation labels at specific coordinates.
///
/// The widget scales coordinates from the original image size to the displayed size.
///
/// Parameters:
/// - [image] - Can be either Image.network or Image.asset widget
/// - [annotations] - List of AnnotationPoint objects containing coordinates and labels
/// - [originalWidth] - The width of the source image (e.g., 1920 for HD image)
/// - [originalHeight] - The height of the source image (e.g., 1080 for HD image)
/// - [labelStyle] - Optional TextStyle for annotation labels
/// - [labelBackground] - Optional Color for label background
class AnnotatedImageOverlay extends StatefulWidget {
  final Widget image;
  final List<AnnotationPoint> annotations;
  final double originalWidth;
  final double originalHeight;
  final TextStyle? labelStyle;
  final Color labelBackground;

  const AnnotatedImageOverlay({
    super.key,
    required this.image,
    required this.annotations,
    required this.originalWidth,
    required this.originalHeight,
    this.labelStyle,
    this.labelBackground = const Color(0xCC000000),
  });

  @override
  State<AnnotatedImageOverlay> createState() => _AnnotatedImageOverlayState();
}

class _AnnotatedImageOverlayState extends State<AnnotatedImageOverlay> {
  String? hoveredLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate aspect ratios
        final originalAspectRatio =
            widget.originalWidth / widget.originalHeight;
        final containerAspectRatio =
            constraints.maxWidth / constraints.maxHeight;

        // Calculate actual display dimensions maintaining aspect ratio
        late final double displayWidth;
        late final double displayHeight;
        late final double offsetX;
        late final double offsetY;

        if (containerAspectRatio > originalAspectRatio) {
          // Container is wider than image
          displayHeight = constraints.maxHeight;
          displayWidth = displayHeight * originalAspectRatio;
          offsetX = (constraints.maxWidth - displayWidth) / 2;
          offsetY = 0;
        } else {
          // Container is taller than image
          displayWidth = constraints.maxWidth;
          displayHeight = displayWidth / originalAspectRatio;
          offsetX = 0;
          offsetY = (constraints.maxHeight - displayHeight) / 2;
        }

        // Calculate scale factors
        final scaleX = displayWidth / widget.originalWidth;
        final scaleY = displayHeight / widget.originalHeight;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Base image
            Positioned.fill(child: widget.image),

            // Annotations
            ...widget.annotations.map((point) {
              final scaledX = (point.x * scaleX) + offsetX;
              final scaledY = (point.y * scaleY) + offsetY;

              return Positioned(
                left: scaledX,
                top: scaledY,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // blue dot marker
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.labelBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Listener(
                        onPointerHover: (event) {
                          if (hoveredLabel != point.label) {
                            print('Hovering over ${point.label}');
                            setState(() {
                              hoveredLabel = point.label;
                            });
                          }
                        },
                        child: SelectableText(
                          point.label,
                          style: widget.labelStyle ??
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}

 */