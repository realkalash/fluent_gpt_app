import 'package:fluent_gpt/dialogs/info_about_user_dialog.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/custom_selectable_region.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/widget/blocks/leaf/code_block.dart';
import 'package:markdown_widget/widget/proxy_rich_text.dart';

class CodeWrapperWidget extends StatefulWidget {
  final String content;
  final String language;
  final PreConfig preConfig;
  final FocusNode? focusNode;
  final TextStyle style;
  final Widget Function(BuildContext, CustomSelectableRegionState)?
      contextMenuBuilder;

  const CodeWrapperWidget({
    super.key,
    required this.content,
    required this.language,
    required this.preConfig,
    required this.style,
    this.contextMenuBuilder,
    required this.focusNode,
  });

  @override
  State<CodeWrapperWidget> createState() => _PreWrapperState();
}

class _PreWrapperState extends State<CodeWrapperWidget> {
  late Widget _switchWidget;
  bool hasCopied = false;
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _switchWidget = Icon(Icons.copy_rounded, key: UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.language == 'func') {
      return ExpansionTile(
        title: Text('function'),
        leading: Icon(Icons.code_rounded),
        dense: true,
        minTileHeight: 10,
        showTrailingIcon: false,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        visualDensity: VisualDensity.compact,
        tilePadding: const EdgeInsets.all(0),
        childrenPadding: const EdgeInsets.all(0),
        expandedAlignment: Alignment.centerLeft,
        children: [
          Text(widget.content),
        ],
      );
    }
    if (widget.language == 'remember') {
      return ExpansionTile(
        title: Text('Saved new info'),
        leading: Icon(FluentIcons.book_32_filled),
        dense: true,
        minTileHeight: 10,
        showTrailingIcon: false,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        visualDensity: VisualDensity.compact,
        tilePadding: const EdgeInsets.all(0),
        childrenPadding: const EdgeInsets.all(0),
        expandedAlignment: Alignment.centerLeft,
        children: [
          fluent.Row(
            children: [
              Expanded(child: Text(widget.content)),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: fluent.Button(
                  onPressed: () {
                    fluent.showDialog(
                      context: context,
                      builder: (ctx) => const InfoAboutUserDialog(),
                      barrierDismissible: true,
                    );
                  },
                  child: Text('Open memory'.tr),
                ),
              )
            ],
          ),
        ],
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final splitContents = widget.content.split(RegExp(r'(\r?\n)|(\r?\t)|(\r)'));
    if (splitContents.last.isEmpty) splitContents.removeLast();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, isDark),
        Container(
          padding: const EdgeInsets.only(left: 8, right: 8),
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            border: Border.all(color: Colors.black),
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8)),
          ),
          child: CustomSelectableRegion(
            contextMenuBuilder: widget.contextMenuBuilder,
            focusNode: widget.focusNode ?? FocusNode(),
            selectionControls: materialTextSelectionHandleControls,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(splitContents.length, (index) {
                final currentContent = splitContents[index];
                return ProxyRichText(
                  TextSpan(
                    children: highLightSpans(
                      currentContent,
                      language: widget.language,
                      theme: widget.preConfig.theme,
                      textStyle: widget.style,
                      styleNotMatched: widget.preConfig.styleNotMatched,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return SelectionContainer.disabled(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: context.theme.accentColor.withAlpha(128),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
        ),
        child: Wrap(
          spacing: 8,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            fluent.Tooltip(
              message:
                  'Run python/shell code (only for python and shell commands!)',
              child: RunCodeButton(
                code: widget.content,
                language: widget.language,
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: fluent.SizedBox.square(
                dimension: 30,
                child: fluent.Button(
                  style: fluent.ButtonStyle(
                    padding:
                        fluent.WidgetStateProperty.all(fluent.EdgeInsets.zero),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _switchWidget,
                  ),
                  onPressed: () async {
                    if (hasCopied) return;
                    await Clipboard.setData(
                        ClipboardData(text: widget.content));
                    displayCopiedToClipboard();
                    _switchWidget = Icon(Icons.check, key: UniqueKey());
                    refresh();
                    Future.delayed(const Duration(seconds: 2), () {
                      hasCopied = false;
                      _switchWidget =
                          Icon(Icons.copy_rounded, key: UniqueKey());
                      refresh();
                    });
                  },
                ),
              ),
            ),
            if (widget.language.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 2),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        width: 0.5,
                        color: isDark ? Colors.white : Colors.black)),
                child: Text(widget.language),
              ),
          ],
        ),
      ),
    );
  }

  void refresh() {
    if (mounted) setState(() {});
  }
}

class SqueareIconButton extends fluent.StatelessWidget {
  const SqueareIconButton(
      {super.key,
      required this.onTap,
      required this.icon,
      required this.tooltip});
  final void Function()? onTap;
  final Widget icon;
  final String tooltip;

  @override
  fluent.Widget build(fluent.BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: fluent.Tooltip(
        message: tooltip,
        child: fluent.SizedBox.square(
          dimension: 30,
          child: fluent.Button(
            onPressed: onTap,
            style: const fluent.ButtonStyle(
              padding: WidgetStatePropertyAll(EdgeInsets.zero),
            ),
            child: icon,
          ),
        ),
      ),
    );
  }
}

class SqueareIconButtonSized extends fluent.StatelessWidget {
  const SqueareIconButtonSized(
      {super.key,
      required this.onTap,
      required this.icon,
      this.width = 30,
      this.height = 30,
      required this.tooltip});
  final void Function()? onTap;
  final Widget icon;
  final String tooltip;
  final double width;
  final double height;

  @override
  fluent.Widget build(fluent.BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: fluent.Tooltip(
        message: tooltip,
        child: fluent.SizedBox(
          width: width,
          height: height,
          child: fluent.Button(
            onPressed: onTap,
            style: const fluent.ButtonStyle(
              padding: WidgetStatePropertyAll(EdgeInsets.zero),
            ),
            child: icon,
          ),
        ),
      ),
    );
  }
}
