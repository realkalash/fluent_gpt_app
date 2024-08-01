// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:fluent_ui/fluent_ui.dart';

class FilledRedButton extends StatelessWidget {
  const FilledRedButton({
    super.key,
    this.onPressed,
    required this.child,
    this.onLongPressed,
    this.autofocus = false,
  });
  final void Function()? onPressed;
  final void Function()? onLongPressed;
  final Widget child;
  final bool autofocus;
  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      autofocus: autofocus,
      onLongPress: onLongPressed,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(Colors.white),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.isDisabled) return Colors.red.withOpacity(0.25);
          if (states.isHovered) return Colors.red['lighter'];
          if (states.isFocused) return Colors.red['light'];
          return Colors.red['normal'];
        }),
      ),
      child: child,
    );
  }
}
