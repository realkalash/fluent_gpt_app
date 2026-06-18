import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fluent_gpt/common/attachment.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/native_channels.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/services/ocr_service.dart';
import 'package:fluent_gpt/widgets/custom_selectable_region.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
// ignore: unnecessary_import
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
const bool kDumpOcrCrop = true;

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

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
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
      log('[AiLens] drag start=$_dragStart cur=$_dragCurrent sel=$selection | '
          'view=${mq?.size} dpr=${mq?.devicePixelRatio} | '
          'capturePt=${capture.pointWidth}x${capture.pointHeight}');
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
      log('[AiLens] OCR: ${result.blocks.length} blocks, ${result.text.length} chars\n${result.text}');
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
  void _clearOcr() {
    if (_ocr == null && !_ocrLoading) return;
    setState(() {
      _ocr = null;
      _ocrLoading = false;
    });
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
        log('[crop] sel=${selPoints.left.toStringAsFixed(0)},${selPoints.top.toStringAsFixed(0)} '
            '${selPoints.width.toStringAsFixed(0)}x${selPoints.height.toStringAsFixed(0)} | '
            'sx=${sx.toStringAsFixed(3)} sy=${sy.toStringAsFixed(3)} | '
            'src=${src.width}x${src.height} pxW=${capture.pxWidth} ptW=${capture.pointWidth} '
            'scale=${capture.scale} | px=${px.left.toStringAsFixed(0)},${px.top.toStringAsFixed(0)} '
            '${px.width.toStringAsFixed(0)}x${px.height.toStringAsFixed(0)} out=${outW}x$outH');
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
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          // Esc peels back state: recognized text first, then the selection,
          // then (on a final press) closes the lens.
          if (_ocr != null || _ocrLoading) {
            _clearOcr();
          } else if (_dragStart != null) {
            setState(() {
              _dragStart = null;
              _dragCurrent = null;
            });
          } else {
            _close();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
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
        if (selection != null && _hudRect(capture, selection).contains(e.localPosition)) {
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
          // Starting a fresh selection invalidates any recognized text.
          _ocr = null;
          _ocrLoading = false;
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
                      borderRadius: BorderRadius.circular(8),
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
            if (selection != null && _ocr != null && _ocr!.isNotEmpty)
              Positioned.fromRect(
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
      left: rect.left,
      top: rect.top,
      width: rect.width,
      child: _LensPromptPill(
        controller: _promptController,
        focusNode: _promptFocus,
        onSubmit: _submit,
        onClose: _close,
        onText: _runOcr,
        ocrLoading: _ocrLoading,
        ocrText: _ocr?.text,
        onClearText: _clearOcr,
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
class _LensPromptPill extends StatelessWidget {
  const _LensPromptPill({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onClose,
    required this.onText,
    required this.ocrLoading,
    required this.ocrText,
    required this.onClearText,
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

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xCC1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
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
              if (ocrText != null) ...[
                _OcrStatusRow(ocrText: ocrText!, onClear: onClearText),
                const SizedBox(height: 8),
              ],
              // Feature actions. "Text" = native OCR (Live Text overlay); the
              // rest are placeholders for now (translate / search).
              Row(
                children: [
                  _PillChip(
                    icon: ic.FluentIcons.text_grammar_wand_24_regular,
                    label: 'Text'.tr,
                    onTap: onText,
                    loading: ocrLoading,
                    active: ocrText != null && ocrText!.isNotEmpty,
                  ),
                  const SizedBox(width: 6),
                  _PillChip(icon: ic.FluentIcons.translate_24_regular, label: 'Translate'.tr, onTap: () {}),
                  const SizedBox(width: 6),
                  _PillChip(icon: ic.FluentIcons.globe_search_24_regular, label: 'Search'.tr, onTap: () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Labeled feature chip in the bottom row of the prompt pill.
class _PillChip extends StatefulWidget {
  const _PillChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Shows a spinner in place of the icon (action in flight).
  final bool loading;

  /// Highlights the chip when its result is currently displayed.
  final bool active;

  @override
  State<_PillChip> createState() => _PillChipState();
}

class _PillChipState extends State<_PillChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFCFEFFF);
    final Color bg = widget.active
        ? const Color(0x33CFEFFF)
        : (_hover ? const Color(0x1FFFFFFF) : const Color(0x12FFFFFF));
    final Color border = widget.active ? const Color(0x66CFEFFF) : const Color(0x1AFFFFFF);
    final Color fg = widget.active ? accent : const Color(0xDDFFFFFF);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: widget.loading ? const ProgressRing(strokeWidth: 2) : Icon(widget.icon, size: 16, color: fg),
              ),
              const SizedBox(width: 6),
              Text(widget.label, style: TextStyle(color: fg, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status line shown in the pill once OCR has run: a "select text on the image"
/// hint with Copy-all + dismiss actions, or a "no text found" note.
class _OcrStatusRow extends StatelessWidget {
  const _OcrStatusRow({required this.ocrText, required this.onClear});
  final String ocrText;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final empty = ocrText.trim().isEmpty;
    return Row(
      children: [
        Icon(
          empty ? ic.FluentIcons.text_grammar_dismiss_24_regular : ic.FluentIcons.text_grammar_checkmark_24_regular,
          size: 14,
          color: const Color(0xAAFFFFFF),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            empty ? 'No text found'.tr : 'Select text on the image, or copy it all'.tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 11),
          ),
        ),
        if (!empty)
          _PillIconButton(
            icon: ic.FluentIcons.copy_24_regular,
            onTap: () => Clipboard.setData(ClipboardData(text: ocrText)),
          ),
        _PillIconButton(icon: ic.FluentIcons.dismiss_24_regular, onTap: onClear),
      ],
    );
  }
}

class _PillIconButton extends StatefulWidget {
  const _PillIconButton({required this.icon, required this.onTap, this.accent = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  State<_PillIconButton> createState() => _PillIconButtonState();
}

class _PillIconButtonState extends State<_PillIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x22FFFFFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: widget.accent ? const Color(0xFFCFEFFF) : Colors.white,
          ),
        ),
      ),
    );
  }
}
