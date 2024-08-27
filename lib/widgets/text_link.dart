import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

class LinkTextButton extends StatelessWidget {
  const LinkTextButton(this.text,{super.key, this.url});
  final String text;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: ()=> launchUrlString(url ?? text),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.blue.withOpacity(0.7),
            fontSize: 14,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}