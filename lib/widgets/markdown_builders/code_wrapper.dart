import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeWrapperWidget extends StatefulWidget {
  final Widget child;
  final String text;
  final String language;

  const CodeWrapperWidget(this.child, this.text, this.language, {super.key});

  @override
  State<CodeWrapperWidget> createState() => _PreWrapperState();
}

class _PreWrapperState extends State<CodeWrapperWidget> {
  late Widget _switchWidget;
  bool hasCopied = false;

  @override
  void initState() {
    super.initState();
    _switchWidget = Icon(Icons.copy_rounded, key: UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: context.theme.accentColor.withOpacity(0.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.language.isNotEmpty)
                SelectionContainer.disabled(
                    child: Container(
                  margin: const EdgeInsets.only(right: 2),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          width: 0.5,
                          color: isDark ? Colors.white : Colors.black)),
                  child: Text(widget.language),
                )),
              InkWell(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _switchWidget,
                ),
                onTap: () async {
                  if (hasCopied) return;
                  await Clipboard.setData(ClipboardData(text: widget.text));
                  _switchWidget = Icon(Icons.check, key: UniqueKey());
                  refresh();
                  Future.delayed(const Duration(seconds: 2), () {
                    hasCopied = false;
                    _switchWidget = Icon(Icons.copy_rounded, key: UniqueKey());
                    refresh();
                  });
                },
              ),
            ],
          ),
        ),
        widget.child,
      ],
    );
  }

  void refresh() {
    if (mounted) setState(() {});
  }
}
