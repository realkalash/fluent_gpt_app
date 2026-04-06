import 'dart:async';
import 'dart:ui' as ui;

import 'package:fluent_gpt/features/screen_ocr/click_to_read_tool.dart';
import 'package:fluent_gpt/features/screen_ocr/text_region.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

class ClickToReadOverlayUI extends StatefulWidget {
  const ClickToReadOverlayUI({super.key});

  @override
  State<ClickToReadOverlayUI> createState() => _ClickToReadOverlayUIState();
}

class _ClickToReadOverlayUIState extends State<ClickToReadOverlayUI> {
  ui.Image? _decodedImage;
  StreamSubscription<Uint8List?>? _screenshotSub;

  @override
  void initState() {
    super.initState();
    _screenshotSub = ClickToReadTool.screenshotData.listen(_onScreenshotData);
    final current = ClickToReadTool.screenshotData.valueOrNull;
    if (current != null) {
      _decodeImage(current);
    }
  }

  void _onScreenshotData(Uint8List? data) {
    if (data != null) {
      _decodeImage(data);
    }
  }

  Future<void> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() => _decodedImage = frame.image);
    }
    codec.dispose();
  }

  @override
  void dispose() {
    _screenshotSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        LogicalKeySet(LogicalKeyboardKey.escape): () {
          ClickToReadTool.dismiss();
        },
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Screenshot image
            if (_decodedImage != null)
              Positioned.fill(
                child: RawImage(
                  image: _decodedImage,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),

            // Layer 2: Click-outside-to-dismiss
            Positioned.fill(
              child: GestureDetector(
                onTap: () => ClickToReadTool.dismiss(),
                behavior: HitTestBehavior.translucent,
              ),
            ),

            // Layer 3: Detected text region highlights
            if (_decodedImage != null)
              StreamBuilder<List<TextRegion>>(
                stream: ClickToReadTool.detectedRegions,
                initialData: ClickToReadTool.detectedRegions.valueOrNull ?? [],
                builder: (context, snapshot) {
                  final regions = snapshot.data ?? [];
                  if (regions.isEmpty) return const SizedBox.shrink();
                  return _RegionOverlay(
                    regions: regions,
                    imageWidth: _decodedImage!.width.toDouble(),
                    imageHeight: _decodedImage!.height.toDouble(),
                  );
                },
              ),

            // Layer 4: Status / loading / error indicator
            StreamBuilder<String?>(
              stream: ClickToReadTool.statusMessage,
              initialData: ClickToReadTool.statusMessage.valueOrNull,
              builder: (context, statusSnap) {
                return StreamBuilder<bool>(
                  stream: ClickToReadTool.isDetecting,
                  initialData: ClickToReadTool.isDetecting.valueOrNull ?? false,
                  builder: (context, detectingSnap) {
                    final isDetecting = detectingSnap.data == true;
                    final status = statusSnap.data;
                    if (!isDetecting && status == null) return const SizedBox.shrink();
                    final isError = !isDetecting && status != null;
                    return Positioned(
                      bottom: 32,
                      left: 40,
                      right: 40,
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 600),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: isError ? const Color(0xDD442222) : Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: isError ? Border.all(color: const Color(0xFFCC4444), width: 1) : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isDetecting) ...[
                                const ProgressRing(strokeWidth: 2),
                                const SizedBox(width: 12),
                              ],
                              if (isError)
                                const Padding(
                                  padding: EdgeInsets.only(right: 10),
                                  child: Icon(FluentIcons.error_badge, color: Color(0xFFFF6666), size: 20),
                                ),
                              Flexible(
                                child: SelectableText(
                                  status ?? 'Detecting text regions...',
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  maxLines: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // Layer 5: Close button
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(FluentIcons.chrome_close, color: Colors.white, size: 16),
                ),
                onPressed: () => ClickToReadTool.dismiss(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionOverlay extends StatelessWidget {
  final List<TextRegion> regions;
  final double imageWidth;
  final double imageHeight;

  const _RegionOverlay({
    required this.regions,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleX = constraints.maxWidth / imageWidth;
        final scaleY = constraints.maxHeight / imageHeight;
        return Stack(
          children: regions.map((region) {
            return Positioned(
              left: region.x * scaleX,
              top: region.y * scaleY,
              width: region.w * scaleX,
              height: region.h * scaleY,
              child: _TextRegionHighlight(region: region),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TextRegionHighlight extends StatefulWidget {
  final TextRegion region;

  const _TextRegionHighlight({required this.region});

  @override
  State<_TextRegionHighlight> createState() => _TextRegionHighlightState();
}

class _TextRegionHighlightState extends State<_TextRegionHighlight> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final r = widget.region;
          log('[TextDetection] Clicked region: {x: ${r.x}, y: ${r.y}, w: ${r.w}, h: ${r.h}, confidence: ${r.confidence}}');
          log('[TextDetection] Crop coordinates: left=${r.x.toInt()}, top=${r.y.toInt()}, right=${(r.x + r.w).toInt()}, bottom=${(r.y + r.h).toInt()}');
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isHovered ? Colors.white.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.3),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
