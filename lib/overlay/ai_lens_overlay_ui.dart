import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluent_gpt/common/attachment.dart';
import 'package:fluent_gpt/common/language_list.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/native_channels.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/services/ocr_service.dart';
import 'package:fluent_gpt/services/reverse_image_search.dart';
import 'package:fluent_gpt/services/translation_service.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/custom_selectable_region.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
// ignore: unnecessary_import
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
part 'ai_lens_widgets/ai_lens_widgets.dart';

/// Fullscreen frozen-frame "AI Lens".
///
/// The native side has already (a) captured the display under the cursor and
/// (b) expanded + raised this window to cover that display. We paint the frozen
/// frame here: blurred + dimmed everywhere, with a crisp **spotlight** wherever
/// the user drags a selection, plus a one-shot scan-sweep shader on open and a
/// floating action pill that tracks the cursor / selection.
///
/// Features (OCR, crop→AI, translate, search) are intentionally deferred — the
/// action buttons are present but inert for now; ✕ / Esc close the lens.
/// Cached lens fragment program. Warmed once at app startup ([warmLensShader])
/// so opening the lens doesn't pay the shader-compile cost on first use.
ui.FragmentProgram? _lensProgram;

/// Debug: dump the exact bytes sent to OCR (+ an annotated copy with the
/// recognized boxes drawn on it) to the temp dir. Flip to false to disable.
const bool kDumpOcrCrop = false;

/// Loads + caches the lens shader. Safe to call repeatedly; call once early
/// (e.g. on app start) to pre-warm it.
Future<ui.FragmentProgram?> warmLensShader() async {
  if (_lensProgram != null) return _lensProgram;
  try {
    _lensProgram = await ui.FragmentProgram.fromAsset('shaders/lens_scan.frag');
  } catch (e) {
    log('[AiLens] shader warm failed: $e');
  }
  return _lensProgram;
}

class AiLensOverlayUI extends StatefulWidget {
  const AiLensOverlayUI({super.key});

  @override
  State<AiLensOverlayUI> createState() => _AiLensOverlayUIState();
}

class _AiLensOverlayUIState extends State<AiLensOverlayUI> with SingleTickerProviderStateMixin {
  // Selection drag (in display points = this window's local coordinates).
  Offset? _dragStart;
  Offset? _dragCurrent;

  // True while a selection drag is in progress (down started outside the HUD).
  bool _selecting = false;

  // Prompt field shown after a selection is made; auto-focused on selection end.
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocus = FocusNode();

  // Continuous animation clock (seconds) + one-shot open-ripple timing.
  late final Ticker _ticker;
  final ValueNotifier<double> _clock = ValueNotifier<double>(0.0);
  double? _readyTime;

  ui.FragmentShader? _shader;
  ui.Image? _frozen;
  bool _decoding = false; // guards against concurrent decodes (double-leak)

  // With pre-warm, the lens mounts before the capture exists (window revealed
  // immediately so the engine resumes during capture). We listen for the
  // capture to arrive, then decode the frozen frame.
  StreamSubscription<LensCapture?>? _captureSub;

  // OCR (Live Text) state. Recognized text for the current selection; rebuilt
  // each time the Text chip runs and cleared whenever the selection changes.
  OcrResult? _ocr;
  bool _ocrLoading = false;
  final FocusNode _ocrFocus = FocusNode(debugLabel: 'lensOcr');

  // Reverse-image-search: true while the crop is being hosted/launched.
  bool _searchLoading = false;

  // Translate state. [_translation] is aligned 1:1 with [_ocr!.blocks]; null
  // until Translate has run. [_showTranslation] toggles the opaque translated
  // overlay vs. the original frozen frame. [_targetLanguage] defaults to the
  // app's current locale and can be changed via the language picker.
  List<String>? _translation;
  bool _translateLoading = false;
  bool _showTranslation = false;
  String _targetLanguage = _localeToLanguageName(I18n.currentLocale.languageCode);

  /// Maps a locale code (e.g. 'en', 'uk') to a [LanguageList] display name used
  /// in the translate prompt. Falls back to English for unknown codes.
  static String _localeToLanguageName(String code) {
    const byCode = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ar': 'Arabic',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'uk': 'Ukrainian',
      'hi': 'Hindi',
    };
    return byCode[code.toLowerCase()] ?? 'English';
  }

  // Measures the prompt pill's actual rendered bounds. The pill grows when the
  // OCR row / engine picker reveal, so a fixed-height estimate (_hudRect) would
  // wrongly treat taps on the lower chips as "start a new selection".
  final GlobalKey _pillKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Esc handling routed through an app-level keyboard handler (not the focus
    // tree): the lens is a fullscreen modal, and once focus lands on a child
    // (prompt field, OCR region) and that child later unmounts, focus falls to
    // nothing and a focus-scoped onKeyEvent would stop receiving Esc. This is
    // focus-independent for as long as the lens is mounted.
    HardwareKeyboard.instance.addHandler(_onGlobalKey);
    _ticker = createTicker((elapsed) => _clock.value = elapsed.inMicroseconds / 1e6);
    _ticker.start();
    _loadShader();

    if (lensCapture.valueOrNull != null) _decodeFrozenImage();
    _captureSub = lensCapture.listen((capture) {
      if (!mounted) return;
      if (capture != null && _frozen == null) _decodeFrozenImage();
      setState(() {});
    });
  }

  Future<void> _loadShader() async {
    final program = await warmLensShader(); // cached after first call
    if (!mounted || program == null) return;
    // No graceful fallback for the distortion look — if the shader is missing
    // the plain frozen frame is shown instead (still fully usable).
    setState(() => _shader = program.fragmentShader());
  }

  Future<void> _decodeFrozenImage() async {
    final capture = lensCapture.valueOrNull;
    if (capture == null || _decoding || _frozen != null) return;
    _decoding = true;
    try {
      final codec = await ui.instantiateImageCodec(capture.imageBytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _frozen = frame.image);
    } catch (e) {
      log('[AiLens] frozen decode failed: $e');
    } finally {
      _decoding = false;
    }
  }

  /// App-level Esc handler (see [initState]). Returns true to consume Esc so it
  /// doesn't leak to other handlers; lets every other key route normally so
  /// typing in the prompt field still works.
  bool _onGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    _handleEscape();
    return true;
  }

  /// Esc peels back state: translated overlay → recognized text → selection →
  /// (final press) closes the lens.
  void _handleEscape() {
    if (_showTranslation) {
      setState(() => _showTranslation = false);
    } else if (_ocr != null || _ocrLoading || _translation != null || _translateLoading) {
      _clearOcr();
    } else if (_dragStart != null) {
      setState(() {
        _dragStart = null;
        _dragCurrent = null;
      });
    } else {
      _close();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onGlobalKey);
    _captureSub?.cancel();
    _ticker.dispose();
    _clock.dispose();
    _shader?.dispose();
    _frozen?.dispose();
    _promptController.dispose();
    _promptFocus.dispose();
    _ocrFocus.dispose();
    super.dispose();
  }

  /// Runs native OCR over the current selection and shows the Live Text overlay.
  /// On-demand (triggered by the Text chip); reuses the same crop as [_submit].
  Future<void> _runOcr() async {
    final selection = _selection;
    final capture = lensCapture.valueOrNull;
    if (selection == null || capture == null || _ocrLoading) return;
    if (!OcrService.instance.isSupported) {
      log('[AiLens] OCR not supported on this platform');
      return;
    }
    if (kDumpOcrCrop) {
      final mq = MediaQuery.maybeOf(context);
      log(
        '[AiLens] drag start=$_dragStart cur=$_dragCurrent sel=$selection | '
        'view=${mq?.size} dpr=${mq?.devicePixelRatio} | '
        'capturePt=${capture.pointWidth}x${capture.pointHeight}',
      );
    }
    setState(() => _ocrLoading = true);
    try {
      final pngBytes = await _cropSelection(capture, selection);
      if (pngBytes == null) {
        log('[AiLens] OCR crop failed');
        return;
      }
      final result = await OcrService.instance.recognize(pngBytes, fast: false);
      if (!mounted) return;
      // log('[AiLens] OCR: ${result.blocks.length} blocks, ${result.text.length} chars\n${result.text}');
      if (kDumpOcrCrop) await _debugDumpCrop(pngBytes, result);
      setState(() => _ocr = result);
      if (result.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _ocrFocus.requestFocus();
        });
      }
    } catch (e) {
      log('[AiLens] OCR failed: $e');
    } finally {
      if (mounted) setState(() => _ocrLoading = false);
    }
  }

  /// Clears any recognized text (called when the selection changes / is reset).
  /// Translation rides on the OCR blocks, so it's cleared in lockstep.
  void _clearOcr() {
    if (_ocr == null && !_ocrLoading && _translation == null && !_translateLoading) return;
    setState(() {
      _ocr = null;
      _ocrLoading = false;
      _translation = null;
      _translateLoading = false;
      _showTranslation = false;
    });
  }

  /// Translate chip: ensures OCR has run on the selection, then translates every
  /// block in one request and shows the opaque translated overlay. Re-running
  /// (e.g. after switching language) re-translates the same blocks.
  Future<void> _runTranslate() async {
    if (_translateLoading) return;
    setState(() => _translateLoading = true);
    try {
      // Translation needs the OCR blocks; run OCR first if it hasn't been.
      if (_ocr == null) await _runOcr();
      final ocr = _ocr;
      if (ocr == null || ocr.blocks.isEmpty) {
        log('[AiLens] nothing to translate');
        return;
      }
      final translated = await TranslationService.instance.translate(
        ocr.blocks.map((b) => b.text).toList(),
        targetLanguage: _targetLanguage,
      );
      if (!mounted) return;
      setState(() {
        _translation = translated;
        _showTranslation = true;
      });
    } catch (e) {
      log('[AiLens] translate failed: $e');
    } finally {
      if (mounted) setState(() => _translateLoading = false);
    }
  }

  /// Flips between the translated overlay and the original frozen frame (only
  /// meaningful once a translation exists).
  void _toggleTranslation() {
    if (_translation == null) return;
    setState(() => _showTranslation = !_showTranslation);
  }

  /// Switches the target language and re-translates if a translation is showing.
  void _setLanguage(String language) {
    if (language == _targetLanguage) return;
    setState(() => _targetLanguage = language);
    if (_ocr != null) _runTranslate();
  }

  /// Hosts the current selection and opens [engine]'s reverse-image-search page
  /// in the browser, then closes the lens so the results are visible.
  Future<void> _runSearch(ReverseSearchEngine engine) async {
    final selection = _selection;
    final capture = lensCapture.valueOrNull;
    if (selection == null || capture == null || _searchLoading) return;
    setState(() => _searchLoading = true);
    try {
      final pngBytes = await _cropSelection(capture, selection);
      if (pngBytes == null) {
        log('[AiLens] search crop failed');
        displayErrorInfoBar(title: 'Search failed', message: 'Could not crop the selection.');
        return;
      }
      final ok = await ReverseImageSearch.instance.launchSearch(pngBytes, engine);
      if (!mounted) return;
      if (!ok) {
        displayErrorInfoBar(
          title: 'Search failed',
          message: 'Could not upload the image. Check your connection and try again.',
        );
        return;
      }
      // Results opened in the browser — leave the lens so they're visible.
      await NativeChannelUtils.exitLensMode();
      _close();
    } catch (e) {
      log('[AiLens] search failed: $e');
      if (mounted) displayErrorInfoBar(title: 'Search failed', message: '$e');
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  /// Debug aid: writes the exact crop sent to OCR to the temp dir, plus an
  /// annotated copy with the recognized boxes drawn on it (red = each block's
  /// rect mapped to pixels the same way the live overlay maps them). Comparing
  /// the two tells us whether the offset/truncation lives in the crop, in
  /// Vision's boxes, or only in the live display.
  Future<void> _debugDumpCrop(Uint8List pngBytes, OcrResult result) async {
    try {
      final dir = Directory.systemTemp.path;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final rawPath = '$dir/fluent_ocr_${ts}_crop.png';
      await File(rawPath).writeAsBytes(pngBytes);
      log('[AiLens] OCR crop  -> $rawPath');

      if (result.blocks.isEmpty) return;
      final codec = await ui.instantiateImageCodec(pngBytes);
      final img = (await codec.getNextFrame()).image;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImage(img, Offset.zero, Paint());
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFF3B30);
      for (final b in result.blocks) {
        canvas.drawRect(
          Rect.fromLTWH(
            b.rect.left * img.width,
            b.rect.top * img.height,
            b.rect.width * img.width,
            b.rect.height * img.height,
          ),
          stroke,
        );
      }
      final picture = recorder.endRecording();
      final annotated = await picture.toImage(img.width, img.height);
      final data = await annotated.toByteData(format: ui.ImageByteFormat.png);
      final boxPath = '$dir/fluent_ocr_${ts}_boxes.png';
      if (data != null) await File(boxPath).writeAsBytes(data.buffer.asUint8List());
      log('[AiLens] OCR boxes -> $boxPath');
      img.dispose();
      picture.dispose();
      annotated.dispose();
    } catch (e) {
      log('[AiLens] OCR crop dump failed: $e');
    }
  }

  Rect? get _selection {
    if (_dragStart == null || _dragCurrent == null) return null;
    final r = Rect.fromPoints(_dragStart!, _dragCurrent!);
    if (r.width < 4 || r.height < 4) return null;
    return r;
  }

  void _close() => OverlayManager.hideLensOverlay();

  /// Whether [globalPos] (a pointer's global position) falls on the prompt pill.
  /// Uses the pill's actual rendered RenderBox so it stays correct as the pill
  /// grows/shrinks; falls back to the static [_hudRect] estimate before layout.
  bool _pillContains(Offset globalPos, LensCapture capture, Rect selection) {
    final box = _pillKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      return rect.contains(globalPos);
    }
    return _hudRect(capture, selection).contains(globalPos);
  }

  /// Rectangle the floating prompt pill occupies (only meaningful once a
  /// selection exists). Used both to position it and to keep pointer-downs on
  /// it from starting a brand-new selection.
  Rect _hudRect(LensCapture capture, Rect selection) {
    const pillW = 420.0;
    const pillH = 104.0; // field row + feature-chip row
    final w = capture.pointWidth;
    final h = capture.pointHeight;
    final anchor = selection.bottomLeft + const Offset(0, 12);
    final left = anchor.dx.clamp(8.0, (w - pillW - 8).clamp(8.0, w));
    final top = anchor.dy.clamp(8.0, (h - pillH - 8).clamp(8.0, h));
    return Rect.fromLTWH(left, top, pillW, pillH);
  }

  /// Sends the cropped selection + the typed prompt: leaves the lens, opens the
  /// compact chat, attaches the crop, and sends the message. An empty prompt
  /// just sends the attachment (with the source-context line, if any).
  Future<void> _submit() async {
    final selection = _selection;
    final capture = lensCapture.valueOrNull;
    if (selection == null || capture == null) return;

    // Grab the provider before any async gap (the instance persists across the
    // overlay switch; this avoids using a BuildContext after awaiting).
    final chatProvider = context.read<ChatProvider>();
    final prompt = _promptController.text.trim();

    final pngBytes = await _cropSelection(capture, selection);
    if (pngBytes == null) {
      log('[AiLens] crop failed');
      _close();
      return;
    }

    // Publish the source context (same shape Phase 1 expects).
    regionCaptureContext.add(capture.context);

    // Leave fullscreen lens mode (restore window geometry + level) before the
    // compact chat resizes/repositions the window.
    await NativeChannelUtils.exitLensMode();
    // selection is display-local; offset by the display origin so the chat opens
    // on the correct monitor (window_manager positions are global).
    await OverlayManager.showRegionChatOverlay(
      positionX: capture.originX + selection.left,
      positionY: capture.originY + selection.bottom,
    );

    chatProvider.addAttachmentToInput([Attachment.fromInternalScreenshotBytes(pngBytes)]);

    final prefix = capture.context.promptPrefix;
    final fullMessage = prefix.isNotEmpty ? (prompt.isNotEmpty ? '$prefix\n\n$prompt' : prefix) : prompt;
    chatProvider.sendMessage(fullMessage);

    _promptController.clear();
    lensCapture.add(null);
  }

  /// Crops [capture]'s frozen image to [selPoints] (display points) and returns
  /// PNG bytes. Maps points→pixels via the image/point dimension ratio so it's
  /// robust to scale-reporting quirks.
  Future<Uint8List?> _cropSelection(LensCapture capture, Rect selPoints) async {
    // Reuse the frame we already decoded for display; only decode afresh if the
    // crop somehow runs before the display image is ready (which it shouldn't,
    // since a selection requires the frame to be visible). The shared [_frozen]
    // is owned by this State (disposed in [dispose]) — never dispose it here.
    ui.Image? owned;
    // The frozen frame is displayed BoxFit.fill across the Flutter VIEW, whose
    // logical size can be smaller than the captured display (the lens window
    // doesn't cover the menu bar / has chrome). Selection coords live in this
    // view space, so map them to image pixels via the view size — matching
    // exactly how the shader samples the texture (uv = fragCoord / viewSize).
    // Using pointWidth (the full display) under-scales and clips the crop.
    final viewSize = MediaQuery.sizeOf(context);
    try {
      ui.Image src;
      if (_frozen != null) {
        src = _frozen!;
      } else {
        final codec = await ui.instantiateImageCodec(capture.imageBytes);
        final frame = await codec.getNextFrame();
        owned = frame.image;
        src = owned;
      }
      final sx = src.width / viewSize.width;
      final sy = src.height / viewSize.height;
      var px = Rect.fromLTRB(
        (selPoints.left * sx).clamp(0, src.width.toDouble()),
        (selPoints.top * sy).clamp(0, src.height.toDouble()),
        (selPoints.right * sx).clamp(0, src.width.toDouble()),
        (selPoints.bottom * sy).clamp(0, src.height.toDouble()),
      );
      final outW = px.width.round();
      final outH = px.height.round();
      if (kDumpOcrCrop) {
        log(
          '[crop] sel=${selPoints.left.toStringAsFixed(0)},${selPoints.top.toStringAsFixed(0)} '
          '${selPoints.width.toStringAsFixed(0)}x${selPoints.height.toStringAsFixed(0)} | '
          'sx=${sx.toStringAsFixed(3)} sy=${sy.toStringAsFixed(3)} | '
          'src=${src.width}x${src.height} pxW=${capture.pxWidth} ptW=${capture.pointWidth} '
          'scale=${capture.scale} | px=${px.left.toStringAsFixed(0)},${px.top.toStringAsFixed(0)} '
          '${px.width.toStringAsFixed(0)}x${px.height.toStringAsFixed(0)} out=${outW}x$outH',
        );
      }
      if (outW <= 0 || outH <= 0) return null;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(src, px, Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()), Paint());
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(outW, outH);
      final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      cropped.dispose();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      log('[AiLens] crop error: $e');
      return null;
    } finally {
      owned?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final capture = lensCapture.valueOrNull;
    // Esc is handled app-level in [_onGlobalKey] (focus-independent); this Focus
    // only seeds keyboard traversal for the prompt field.
    return Focus(
      autofocus: true,
      // Dark "entering" backdrop until the captured frame arrives. Pre-warm:
      // the window is revealed immediately so the engine resumes during capture.
      child: capture == null ? const ColoredBox(color: Color(0xE6000000)) : _buildLens(capture),
    );
  }

  Widget _buildLens(LensCapture capture) {
    final bytes = capture.imageBytes;
    final selection = _selection;
    // Listener (raw pointer) instead of GestureDetector so the selection drag
    // can't be stolen by the ancestor window-drag recognizer in GlobalPage.
    return Listener(
      onPointerDown: (e) {
        // Don't start a new selection when interacting with the prompt pill.
        // Measure its real bounds (it grows when OCR/engine rows reveal) so taps
        // on the lower chips aren't mistaken for a fresh snip.
        if (selection != null && _pillContains(e.position, capture, selection)) {
          return;
        }
        // While the Live Text overlay is up, taps inside the selection belong
        // to the selectable text region (drag-select), not a brand-new snip.
        if (_ocr != null && selection != null && selection.contains(e.localPosition)) {
          return;
        }
        setState(() {
          _selecting = true;
          _dragStart = e.localPosition;
          _dragCurrent = e.localPosition;
          // Starting a fresh selection invalidates any recognized text and
          // its translation.
          _ocr = null;
          _ocrLoading = false;
          _translation = null;
          _translateLoading = false;
          _showTranslation = false;
        });
      },
      onPointerMove: (e) {
        if (!_selecting) return;
        setState(() => _dragCurrent = e.localPosition);
      },
      onPointerUp: (e) {
        if (!_selecting) return;
        setState(() => _selecting = false);
        // Auto-focus the prompt field once a real selection has been drawn.
        if (_selection != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _promptFocus.requestFocus();
          });
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.precise,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. The whole visual: frozen frame + elastic-glass distortion +
            //    drifting aurora tint + sparkles, with a crisp selection cutout.
            //    Falls back to the plain frozen frame until shader+image load.
            Positioned.fill(
              child: (_shader != null && _frozen != null)
                  ? ValueListenableBuilder<double>(
                      valueListenable: _clock,
                      builder: (context, t, _) {
                        // Anchor the ripple to the first *visible* frame. The
                        // ticker only advances while the window renders, so a
                        // launch from a hidden window still plays the ripple.
                        _readyTime ??= t;
                        final openT = ((t - _readyTime!) / 1.4).clamp(0.0, 1.0);
                        return CustomPaint(
                          painter: _LensShaderPainter(
                            shader: _shader!,
                            image: _frozen!,
                            time: t,
                            openT: openT,
                            selection: selection,
                            cursor: Offset(capture.cursorX, capture.cursorY),
                          ),
                        );
                      },
                    )
                  : Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true),
            ),

            // 2. Selection border + glow.
            if (selection != null)
              Positioned.fromRect(
                rect: selection,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      border: Border.all(color: const Color(0xFFCFEFFF), width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Color(0x6699D6FF), blurRadius: 16, spreadRadius: 1),
                      ],
                    ),
                  ),
                ),
              ),

            // 2.5 Live Text overlay: selectable OCR results laid over the
            //     frozen frame, positioned by each block's normalized rect.
            //     When a translation is toggled on, the opaque translated layer
            //     covers the original text instead.
            if (selection != null && _showTranslation && _translation != null && _ocr != null)
              Positioned.fromRect(
                key: const ValueKey('lens-translated'),
                rect: selection,
                child: _TranslatedTextLayer(
                  blocks: _ocr!.blocks,
                  translations: _translation!,
                  size: selection.size,
                ),
              )
            else if (selection != null && _ocr != null && _ocr!.isNotEmpty)
              Positioned.fromRect(
                key: const ValueKey('lens-livetext'),
                rect: selection,
                child: _LiveTextLayer(
                  result: _ocr!,
                  size: selection.size,
                  focusNode: _ocrFocus,
                ),
              ),

            // 3. Floating prompt pill, anchored under the selection.
            if (selection != null) _buildHud(capture, selection),
          ],
        ),
      ),
    );
  }

  Widget _buildHud(LensCapture capture, Rect selection) {
    final rect = _hudRect(capture, selection);
    return Positioned(
      // Stable key so inserting the Live Text layer above this pill in the
      // Stack doesn't re-index (and thus rebuild) the pill — which would reset
      // the reveal AnimatedSwitcher and skip the OCR-row appear animation.
      key: const ValueKey('lens-hud'),
      left: rect.left,
      top: rect.top,
      width: rect.width,
      child: _LensPromptPill(
        key: _pillKey,
        controller: _promptController,
        focusNode: _promptFocus,
        onSubmit: _submit,
        onClose: _close,
        onText: _runOcr,
        ocrLoading: _ocrLoading,
        ocrText: _ocr?.text,
        onClearText: _clearOcr,
        onSearch: _runSearch,
        searchLoading: _searchLoading,
        onTranslate: _runTranslate,
        onToggleTranslation: _toggleTranslation,
        translateLoading: _translateLoading,
        hasTranslation: _translation != null,
        showingTranslation: _showTranslation,
        targetLanguage: _targetLanguage,
        onPickLanguage: _setLanguage,
      ),
    );
  }
}

/// Selectable "Live Text" overlay laid over the selection. Each OCR block is a
/// transparent, selectable text box positioned by its normalized rect (scaled to
/// the selection size). Wrapping them in a [CustomSelectableRegion] lets the user
/// drag-select across lines and copy (Cmd+C) just like macOS Live Text.
class _LiveTextLayer extends StatelessWidget {
  const _LiveTextLayer({
    required this.result,
    required this.size,
    required this.focusNode,
  });
  final OcrResult result;
  final Size size; // selection size in display points
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    // Reading-order sort so cross-line selection + copy concatenate sanely.
    final blocks = result.blocks.where((b) => b.text.trim().isNotEmpty).toList()
      ..sort((a, b) {
        final dy = a.rect.top.compareTo(b.rect.top);
        return dy != 0 ? dy : a.rect.left.compareTo(b.rect.left);
      });
    // Make the selection highlight clearly visible (the glyphs themselves are
    // transparent — the frozen frame already shows the text underneath).
    return DefaultSelectionStyle(
      selectionColor: const Color(0x6635C4FF),
      child: SizedBox.fromSize(
        size: size,
        child: CustomSelectableRegion(
          focusNode: focusNode,
          selectionControls: fluentTextSelectionControls,
          child: Stack(
            children: [
              for (final block in blocks)
                Positioned(
                  left: block.rect.left * size.width,
                  top: block.rect.top * size.height,
                  width: block.rect.width * size.width,
                  // No height: the line sizes to its font (set from the box
                  // height below), so the highlight hugs the glyphs instead of
                  // being stretched to fill a fixed box.
                  child: _LiveTextBox(
                    text: block.text,
                    fontSize: (block.rect.height * size.height).clamp(6.0, 200.0),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single selectable OCR line, stretched to fill its bounding box so the
/// selection highlight lines up with the text under it on the frozen frame.
/// The glyphs themselves are kept near-transparent (Live-Text style).
class _LiveTextBox extends StatelessWidget {
  const _LiveTextBox({required this.text, required this.fontSize});
  final String text;

  /// Logical-pixel font size, derived from the OCR block's height so the line
  /// box (and thus the selection highlight) matches the text on the frozen frame.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // Transparent glyphs (the frozen frame already shows the text); only the
    // selection highlight is visible. forceStrutHeight pins the line box to
    // exactly [fontSize] so the highlight hugs the glyphs vertically.
    return Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      strutStyle: StrutStyle(
        fontSize: fontSize,
        height: 1.0,
        leading: 0,
        forceStrutHeight: true,
      ),
      style: TextStyle(
        color: const Color(0x00FFFFFF),
        fontSize: fontSize,
        height: 1.0,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );
  }
}

/// Opaque "translated" overlay laid over the selection. Each OCR block becomes
/// an opaque white box (covering the original text on the frozen frame) with the
/// translated text in black, auto-shrunk to fit its box. Positioned by the same
/// normalized rects as [_LiveTextLayer], so it lines up with the source text.
class _TranslatedTextLayer extends StatelessWidget {
  const _TranslatedTextLayer({
    required this.blocks,
    required this.translations,
    required this.size,
  });
  final List<OcrBlock> blocks;
  final List<String> translations; // aligned 1:1 with [blocks]
  final Size size; // selection size in display points

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        children: [
          for (var i = 0; i < blocks.length; i++)
            if (i < translations.length && translations[i].trim().isNotEmpty)
              Positioned(
                left: blocks[i].rect.left * size.width,
                top: blocks[i].rect.top * size.height,
                width: blocks[i].rect.width * size.width,
                height: blocks[i].rect.height * size.height,
                child: _TranslatedBox(text: translations[i]),
              ),
        ],
      ),
    );
  }
}

/// A single translated line: opaque white fill with black text scaled down to
/// fit the original block's box, so longer translations don't overflow.
class _TranslatedBox extends StatelessWidget {
  const _TranslatedBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFFFFF),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(color: Color(0xFF000000), height: 1.0),
        ),
      ),
    );
  }
}

/// Drives the lens fragment shader: feeds the frozen frame as a texture plus
/// the time/open-ripple/selection uniforms, and paints it fullscreen.
class _LensShaderPainter extends CustomPainter {
  _LensShaderPainter({
    required this.shader,
    required this.image,
    required this.time,
    required this.openT,
    required this.selection,
    required this.cursor,
  });
  final ui.FragmentShader shader;
  final ui.Image image;
  final double time;
  final double openT;
  final Rect? selection;
  final Offset cursor; // display-local logical px, top-left origin

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setFloat(3, openT);
    final sel = selection;
    shader.setFloat(4, sel?.left ?? 0);
    shader.setFloat(5, sel?.top ?? 0);
    shader.setFloat(6, sel?.width ?? 0);
    shader.setFloat(7, sel?.height ?? 0);
    shader.setFloat(8, cursor.dx);
    shader.setFloat(9, cursor.dy);
    shader.setImageSampler(0, image);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _LensShaderPainter old) => true;
}

/// Frosted prompt pill shown under the selection. Enter sends (with the crop);
/// an empty prompt still sends the attachment. ✕ closes the lens.
class _LensPromptPill extends StatefulWidget {
  const _LensPromptPill({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onClose,
    required this.onText,
    required this.ocrLoading,
    required this.ocrText,
    required this.onClearText,
    required this.onSearch,
    required this.searchLoading,
    required this.onTranslate,
    required this.onToggleTranslation,
    required this.translateLoading,
    required this.hasTranslation,
    required this.showingTranslation,
    required this.targetLanguage,
    required this.onPickLanguage,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final VoidCallback onClose;

  /// Runs OCR on the current selection (the "Text" chip).
  final VoidCallback onText;

  /// True while OCR is in flight — swaps the Text chip icon for a spinner.
  final bool ocrLoading;

  /// Recognized text once OCR has run (null = not run yet, '' = nothing found).
  final String? ocrText;

  /// Dismisses the Live Text overlay.
  final VoidCallback onClearText;

  /// Reverse-image-search the selection with the chosen engine.
  final ValueChanged<ReverseSearchEngine> onSearch;

  /// True while the crop is being hosted/launched — spinner on the Search chip.
  final bool searchLoading;

  /// Runs OCR (if needed) + translation on the selection (the "Translate" chip).
  final VoidCallback onTranslate;

  /// Flips between the translated overlay and the original frozen frame.
  final VoidCallback onToggleTranslation;

  /// True while translation is in flight — spinner on the Translate chip.
  final bool translateLoading;

  /// Whether a translation result exists (enables the toggle behavior).
  final bool hasTranslation;

  /// Whether the translated overlay is currently shown.
  final bool showingTranslation;

  /// Current target language name (e.g. 'English').
  final String targetLanguage;

  /// Picks a new target language from the language picker.
  final ValueChanged<String> onPickLanguage;

  @override
  State<_LensPromptPill> createState() => _LensPromptPillState();
}

class _LensPromptPillState extends State<_LensPromptPill> {
  // Whether the reverse-image-search engine picker is expanded.
  bool _showEngines = false;

  // Whether the translate target-language picker is expanded.
  bool _showLanguages = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final focusNode = widget.focusNode;
    final onSubmit = widget.onSubmit;
    final onClose = widget.onClose;
    final onText = widget.onText;
    final ocrLoading = widget.ocrLoading;
    final ocrText = widget.ocrText;
    final onClearText = widget.onClearText;
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xCC1E1E1E),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          // AnimatedSize smoothly grows/shrinks the whole card as sections
          // (OCR status, engine picker) reveal or collapse below.
          child: AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(ic.FluentIcons.sparkle_24_regular, size: 18, color: Color(0xFFCFEFFF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextBox(
                        controller: controller,
                        focusNode: focusNode,
                        maxLines: 1,
                        textInputAction: TextInputAction.send,
                        placeholder: 'Ask about the selection… (Enter to send)'.tr,
                        placeholderStyle: const TextStyle(color: Color(0x88FFFFFF)),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        cursorColor: const Color(0xFFCFEFFF),
                        decoration: const WidgetStatePropertyAll(BoxDecoration(color: Colors.transparent)),
                        foregroundDecoration: const WidgetStatePropertyAll(BoxDecoration(color: Colors.transparent)),
                        highlightColor: Colors.transparent,
                        unfocusedColor: Colors.transparent,
                        padding: const EdgeInsets.only(left: 8),
                        onSubmitted: (_) => onSubmit(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _PillIconButton(icon: ic.FluentIcons.send_24_filled, onTap: onSubmit, accent: true),
                    const SizedBox(width: 2),
                    _PillIconButton(icon: ic.FluentIcons.dismiss_24_regular, onTap: onClose),
                  ],
                ),
                const SizedBox(height: 8),
                Container(height: 1, color: const Color(0x14FFFFFF)),
                const SizedBox(height: 8),
                // OCR status / actions, shown once the Text chip has run.
                // Fades + slides in (and the card grows to fit) via [_Reveal].
                _Reveal(
                  child: ocrText != null
                      ? Padding(
                          key: const ValueKey('ocr'),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _OcrStatusRow(ocrText: ocrText, onClear: onClearText),
                        )
                      : const SizedBox(key: ValueKey('ocr-empty'), width: double.infinity),
                ),
                // Reverse-image-search engine picker, shown when Search is tapped.
                _Reveal(
                  child: _showEngines
                      ? Padding(
                          key: const ValueKey('engines'),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _EnginePickerRow(
                            onPick: (engine) {
                              setState(() => _showEngines = false);
                              widget.onSearch(engine);
                            },
                          ),
                        )
                      : const SizedBox(key: ValueKey('engines-empty'), width: double.infinity),
                ),
                // Translate target-language picker, shown when the language chip
                // is tapped.
                _Reveal(
                  child: _showLanguages
                      ? Padding(
                          key: const ValueKey('languages'),
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _LanguagePickerRow(
                            selected: widget.targetLanguage,
                            onPick: (language) {
                              setState(() => _showLanguages = false);
                              widget.onPickLanguage(language);
                            },
                          ),
                        )
                      : const SizedBox(key: ValueKey('languages-empty'), width: double.infinity),
                ),
                // Feature actions. "Text" = native OCR (Live Text overlay);
                // "Search" = reverse image search (engine picker). Translate is
                // still a placeholder.
                Row(
                  children: [
                    _PillChip(
                      icon: ic.FluentIcons.text_grammar_wand_24_regular,
                      label: 'Text'.tr,
                      onTap: onText,
                      loading: ocrLoading,
                      active: ocrText != null && ocrText.isNotEmpty,
                    ),
                    const SizedBox(width: 6),
                    _PillChip(
                      icon: ic.FluentIcons.globe_search_24_regular,
                      label: 'Search'.tr,
                      loading: widget.searchLoading,
                      active: _showEngines,
                      onTap: () => setState(() => _showEngines = !_showEngines),
                    ),
                    const SizedBox(width: 6),
                    _PillChip(
                      icon: widget.showingTranslation
                          ? ic.FluentIcons.arrow_undo_24_regular
                          : ic.FluentIcons.translate_24_regular,
                      label: widget.hasTranslation
                          ? (widget.showingTranslation ? 'Original'.tr : 'Translated'.tr)
                          : 'Translate'.tr,
                      loading: widget.translateLoading,
                      active: widget.showingTranslation,
                      onTap: widget.hasTranslation ? widget.onToggleTranslation : widget.onTranslate,
                      onLongPress: () => setState(() => _showLanguages = !_showLanguages),
                      trailing: // Language selector for the translation target.
                      SqueareIconButtonSized(
                        width: 32,
                        height: 16,
                        icon: const Icon(ic.FluentIcons.chevron_up_24_filled, size: 16, color: Colors.white),
                        onTap: () => setState(() => _showLanguages = !_showLanguages),
                        tooltip: widget.targetLanguage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
