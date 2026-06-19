part of '../ai_lens_overlay_ui.dart';

/// Reveals [child] with a combined fade + vertical-size transition (and the
/// parent card grows/shrinks to fit). Swap [child] between real content and a
/// zero-height [SizedBox] (with differing keys) to animate it in/out.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Horizontal picker of reverse-image-search engines, revealed by the Search
/// chip. Tapping an engine fires [onPick] and collapses the picker.
class _EnginePickerRow extends StatelessWidget {
  const _EnginePickerRow({required this.onPick});
  final ValueChanged<ReverseSearchEngine> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final engine in ReverseSearchEngine.values)
          _PillChip(
            leading: Image.asset(engine.assetLogo, width: 16, height: 16, filterQuality: FilterQuality.medium),
            label: engine.label,
            onTap: () => onPick(engine),
          ),
      ],
    );
  }
}

/// Horizontal picker of translation target languages, revealed by the language
/// chip. Tapping a language fires [onPick] and collapses the picker. The
/// currently selected language is highlighted.
class _LanguagePickerRow extends StatelessWidget {
  const _LanguagePickerRow({required this.selected, required this.onPick});
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final language in LanguageList.languages)
          _PillChip(
            icon: ic.FluentIcons.local_language_24_regular,
            label: language,
            active: language == selected,
            onTap: () => onPick(language),
          ),
      ],
    );
  }
}

/// Labeled feature chip in the bottom row of the prompt pill.
class _PillChip extends StatefulWidget {
  const _PillChip({
    this.icon,
    this.trailing,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.active = false,
    this.leading,
    this.onLongPress,
  }) : assert(icon != null || leading != null, 'provide an icon or a leading widget');
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Custom leading widget (e.g. a brand logo) shown instead of [icon].
  final Widget? leading;
  final Widget? trailing;

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
        onLongPress: widget.onLongPress,
        onSecondaryTap: widget.onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.all(Radius.circular(9)),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: widget.loading
                    ? const ProgressRing(strokeWidth: 2)
                    : (widget.leading ?? Icon(widget.icon, size: 16, color: fg)),
              ),
              const SizedBox(width: 6),
              Text(widget.label, style: TextStyle(color: fg, fontSize: 12)),
              if (widget.trailing != null) ...[
                const SizedBox(width: 6),
                widget.trailing!,
              ],
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
            borderRadius: const BorderRadius.all(Radius.circular(9)),
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
