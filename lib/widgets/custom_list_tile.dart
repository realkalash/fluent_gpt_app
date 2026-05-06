import 'package:flutter/material.dart';

class BasicListTile extends StatelessWidget {
  /// Creates a basic list tile using basic Row and Column widgets.
  /// It uses Container so you can specify the color, padding, margin, etc.
  const BasicListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding,
    this.margin,
    this.color,
    this.onTap,
    this.onLongPress,
  });
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final void Function()? onTap;
  final void Function()? onLongPress;

  static EdgeInsetsGeometry? defaultPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          color: color ?? Theme.of(context).cardColor,
          padding: padding,
          margin: margin,
          child: Row(
            children: [
              ?leading,
              if (title != null || subtitle != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ?title,
                      ?subtitle,
                    ],
                  ),
                ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class HoverBasicListTile extends StatefulWidget {
  /// Same as [BasicListTile] but with hover effect
  const HoverBasicListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding,
    this.margin,
    this.color,
    this.onTap,
    this.onLongPress,
  });
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final void Function()? onTap;
  final void Function()? onLongPress;

  static EdgeInsetsGeometry? defaultPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4);

  @override
  State<HoverBasicListTile> createState() => _HoverBasicListTileState();
}

class _HoverBasicListTileState extends State<HoverBasicListTile> {
  bool isHoveringOrFocused = false;
  final focusNode = FocusNode();

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      onTap: widget.onTap,
      onFocus: () {
        if (isHoveringOrFocused) return;
        setState(() {
          isHoveringOrFocused = true;
        });
      },

      onLongPress: widget.onLongPress,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (isHoveringOrFocused) return;
          setState(() {
            isHoveringOrFocused = true;
          });
        },
        onExit: (_) {
          if (!isHoveringOrFocused) return;
          setState(() {
            isHoveringOrFocused = false;
          });
        },
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Container(
            padding: widget.padding,
            margin: widget.margin,
            decoration: BoxDecoration(
              color: isHoveringOrFocused ? widget.color?.withAlpha(127) : widget.color ?? Theme.of(context).cardColor,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
            child: Row(
              children: [
                ?widget.leading,
                if (widget.title != null || widget.subtitle != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ?widget.title,
                        ?widget.subtitle,
                      ],
                    ),
                  ),
                ?widget.trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
