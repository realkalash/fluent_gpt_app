import 'dart:io';
import 'dart:ui' show Rect;

import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/native_channels.dart';
import 'package:flutter/foundation.dart';

/// One recognized line of text plus where it sits in the image.
@immutable
class OcrBlock {
  const OcrBlock({
    required this.text,
    required this.rect,
    required this.confidence,
  });

  final String text;

  /// Bounding box normalized to 0..1, **top-left** origin, relative to the
  /// image that was OCR'd (i.e. multiply by the rendered image size to place it).
  final Rect rect;

  /// Recognizer confidence 0..1 (1 = most confident).
  final double confidence;
}

/// Result of an OCR pass: the full joined text and the per-line blocks.
@immutable
class OcrResult {
  const OcrResult({required this.text, required this.blocks});

  final String text;
  final List<OcrBlock> blocks;

  bool get isEmpty => blocks.isEmpty || text.trim().isEmpty;
  bool get isNotEmpty => !isEmpty;

  static const OcrResult empty = OcrResult(text: '', blocks: []);
}

/// Platform-agnostic on-device text recognition.
///
/// macOS uses the native Vision framework via the method channel. Other
/// platforms return an empty result for now (Windows could use
/// `Windows.Media.Ocr`, Linux Tesseract — both behind this same interface).
abstract class OcrService {
  /// Whether OCR is actually implemented on the current platform.
  bool get isSupported;

  /// Recognizes text in [imageBytes] (encoded PNG/JPEG).
  ///
  /// [languages] optionally constrains/hints the recognizer (e.g. `['en','uk']`);
  /// when null the recognizer auto-detects. [fast] trades accuracy for speed.
  Future<OcrResult> recognize(
    Uint8List imageBytes, {
    List<String>? languages,
    bool fast = false,
  });

  static final OcrService instance = _create();

  static OcrService _create() {
    if (Platform.isMacOS) return _MacOsOcrService();
    return const _UnsupportedOcrService();
  }
}

class _MacOsOcrService implements OcrService {
  @override
  bool get isSupported => true;

  @override
  Future<OcrResult> recognize(
    Uint8List imageBytes, {
    List<String>? languages,
    bool fast = false,
  }) async {
    final map = await NativeChannelUtils.recognizeText(
      imageBytes,
      languages: languages,
      fast: fast,
    );
    if (map == null) return OcrResult.empty;
    return _parse(map);
  }

  OcrResult _parse(Map<String, dynamic> map) {
    final text = (map['text'] as String?) ?? '';
    final rawBlocks = (map['blocks'] as List?) ?? const [];
    final blocks = <OcrBlock>[];
    for (final raw in rawBlocks) {
      try {
        final m = Map<String, dynamic>.from(raw as Map);
        final x = (m['x'] as num).toDouble();
        final y = (m['y'] as num).toDouble();
        final w = (m['w'] as num).toDouble();
        final h = (m['h'] as num).toDouble();
        blocks.add(OcrBlock(
          text: (m['text'] as String?) ?? '',
          rect: Rect.fromLTWH(x, y, w, h),
          confidence: (m['confidence'] as num?)?.toDouble() ?? 0,
        ));
      } catch (e) {
        log('[OCR] failed to parse block: $e');
      }
    }
    return OcrResult(text: text, blocks: blocks);
  }
}

class _UnsupportedOcrService implements OcrService {
  const _UnsupportedOcrService();

  @override
  bool get isSupported => false;

  @override
  Future<OcrResult> recognize(
    Uint8List imageBytes, {
    List<String>? languages,
    bool fast = false,
  }) async {
    // Placeholder until Windows (Windows.Media.Ocr) / Linux (Tesseract) land.
    return OcrResult.empty;
  }
}
