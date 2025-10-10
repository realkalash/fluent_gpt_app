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
              if (leading != null) leading!,
              if (title != null || subtitle != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null) title!,
                      if (subtitle != null) subtitle!,
                    ],
                  ),
                ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
