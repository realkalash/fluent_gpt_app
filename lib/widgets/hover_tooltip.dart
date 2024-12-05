import 'package:entry/entry.dart';
import 'package:fluent_ui/fluent_ui.dart';

class HoverTooltip extends StatefulWidget {
  final Widget child;
  final Widget tooltipContent;
  final double tooltipWidth;
  final double tooltipHeight;
  final Duration showDuration;

  const HoverTooltip({
    super.key,
    required this.child,
    required this.tooltipContent,
    this.tooltipWidth = 200,
    this.tooltipHeight = 100,
    this.showDuration = const Duration(milliseconds: 600),
  });

  @override
  _HoverTooltipState createState() => _HoverTooltipState();
}

class _HoverTooltipState extends State<HoverTooltip> {
  OverlayEntry? _overlayEntry;
  bool _isHovering = false;
  bool _isHoveringOverTooltip = false;

  void _showTooltip(BuildContext context) {
    // Remove any existing overlay
    _overlayEntry?.remove();

    // Get the render box of the child widget
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx,
        top: position.dy + size.height,
        child: MouseRegion(
          onEnter: (_) {
            setState(() {
              _isHoveringOverTooltip = true;
            });
          },
          onExit: (_) {
            setState(() {
              _isHoveringOverTooltip = false;
              _hideTooltip();
            });
          },
          child: Entry.all(
            duration: widget.showDuration,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: widget.tooltipWidth,
                height: widget.tooltipHeight,
                child: widget.tooltipContent,
              ),
            ),
          ),
        ),
      ),
    );

    // Insert the overlay
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideTooltip() {
    if (!_isHovering && !_isHoveringOverTooltip) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovering = true;
        });
        _showTooltip(context);
      },
      onExit: (_) {
        setState(() {
          _isHovering = false;
        });
        _hideTooltip();
      },
      cursor: SystemMouseCursors.click,
      child: widget.child,
    );
  }
}
