import 'dart:async';
import 'dart:ui' as ui;

import 'package:fluent_gpt/common/attachment.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/native_channels.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
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
    super.dispose();
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
      final sx = capture.pxWidth / capture.pointWidth;
      final sy = capture.pxHeight / capture.pointHeight;
      var px = Rect.fromLTRB(
        (selPoints.left * sx).clamp(0, src.width.toDouble()),
        (selPoints.top * sy).clamp(0, src.height.toDouble()),
        (selPoints.right * sx).clamp(0, src.width.toDouble()),
        (selPoints.bottom * sy).clamp(0, src.height.toDouble()),
      );
      final outW = px.width.round();
      final outH = px.height.round();
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
          // Esc clears the selection first, then (on a second press) closes.
          if (_dragStart != null) {
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
          setState(() {
            _selecting = true;
            _dragStart = e.localPosition;
            _dragCurrent = e.localPosition;
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
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final VoidCallback onClose;

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
              // Feature actions — placeholders for now (OCR / translate / search).
              Row(
                children: [
                  _PillChip(icon: ic.FluentIcons.text_grammar_wand_24_regular, label: 'Text'.tr, onTap: () {}),
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
  const _PillChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_PillChip> createState() => _PillChipState();
}

class _PillChipState extends State<_PillChip> {
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x1FFFFFFF) : const Color(0x12FFFFFF),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: const Color(0xDDFFFFFF)),
              const SizedBox(width: 6),
              Text(widget.label, style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 12)),
            ],
          ),
        ),
      ),
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
