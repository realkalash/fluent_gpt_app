import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as m;
import 'package:url_launcher/url_launcher_string.dart';

class LinkTextButton extends StatelessWidget {
  const LinkTextButton(this.text, {super.key, this.url, this.onPressed});
  final String text;
  final String? url;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final brightness = FluentTheme.of(context).brightness;
    return m.Material(
      color: Colors.transparent,
      child: m.InkWell(
        onTap: onPressed ?? () => launchUrlString(url ?? text),
        child: Text(
          text,
          style: TextStyle(
            color: brightness == m.Brightness.dark ? Colors.blue.light : Colors.blue.dark,
            fontSize: 14,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
