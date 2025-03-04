import 'package:fluent_ui/fluent_ui.dart';

/// A widget that applies a zoom animation to its child when hovered.
///
/// This widget detects mouse hover and animates its child with a scaling effect.
/// The animation parameters like scale factor, duration, and curve are configurable.
class ZoomHover extends StatefulWidget {
  /// The widget to be wrapped with the zoom effect.
  final Widget child;

  /// The scale factor when hovered. Default is 1.05 (5% larger).
  final double hoverScale;

  /// Duration for the zoom-in animation when the pointer enters.
  final Duration enterDuration;

  /// Duration for the zoom-out animation when the pointer exits.
  final Duration exitDuration;

  /// The curve to apply to the zoom animation when entering.
  final Curve enterCurve;

  /// The curve to apply to the zoom animation when exiting.
  final Curve exitCurve;

  /// Whether to add a subtle shadow when hovered.
  final bool addShadowOnHover;

  /// Shadow elevation when hovered (if [addShadowOnHover] is true).
  final double hoverElevation;

  const ZoomHover({
    super.key,
    required this.child,
    this.hoverScale = 1.05,
    this.enterDuration = const Duration(milliseconds: 200),
    this.exitDuration = const Duration(milliseconds: 300),
    this.enterCurve = Curves.easeOutCubic,
    this.exitCurve = Curves.easeInCubic,
    this.addShadowOnHover = true,
    this.hoverElevation = 4.0,
  });

  @override
  _ZoomHoverState createState() => _ZoomHoverState();
}

class _ZoomHoverState extends State<ZoomHover> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleHoverChanged(true),
      onExit: (_) => _handleHoverChanged(false),
      child: AnimatedContainer(
        duration: _isHovered ? widget.enterDuration : widget.exitDuration,
        curve: _isHovered ? widget.enterCurve : widget.exitCurve,
        transform: Matrix4.identity()
          ..scale(_isHovered ? widget.hoverScale : 1.0),
        transformAlignment: Alignment.center,
        decoration: widget.addShadowOnHover
            ? BoxDecoration(
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withAlpha(21),
                          blurRadius: widget.hoverElevation,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              )
            : null,
        child: widget.child,
      ),
    );
  }

  void _handleHoverChanged(bool isHovered) {
    if (mounted) {
      setState(() {
        _isHovered = isHovered;
      });
    }
  }
}