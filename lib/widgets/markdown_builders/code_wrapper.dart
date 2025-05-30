import 'dart:io';

import 'package:fluent_gpt/dialogs/info_about_user_dialog.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/shell_driver.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/widget/blocks/leaf/code_block.dart';
import 'package:highlight/highlight.dart' as hi;

class CodeWrapperWidget extends StatefulWidget {
  final String content;
  final String language;
  final PreConfig preConfig;
  final FocusNode? focusNode;
  final TextStyle style;
  final Widget Function(BuildContext, EditableTextState)? contextMenuBuilder;

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
      return Material(
        color: Colors.transparent,
        child: ExpansionTile(
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
        ),
      );
    }
    if (widget.language == 'remember') {
      return Material(
        color: Colors.transparent,
        child: ExpansionTile(
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
        ),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // final splitContents = widget.content.split(RegExp(r'(\r?\n)|(\r?\t)|(\r)'));
    // if (splitContents.last.isEmpty) splitContents.removeLast();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, isDark),
        DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            border: Border.all(color: Colors.black),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SelectableText.rich(
              TextSpan(
                children: convertHiNodes(
                  hi.highlight.parse(widget.content, language: widget.language, autoDetection: false).nodes!,
                  widget.preConfig.theme,
                  widget.style,
                  widget.preConfig.styleNotMatched,
                ),
              ),
              contextMenuBuilder: widget.contextMenuBuilder,
            ),
          ),
          // child: fluent.Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 8.0),
          //   child: CustomSelectableRegion(
          //     contextMenuBuilder: widget.contextMenuBuilder,
          //     focusNode: widget.focusNode ?? FocusNode(),
          //     selectionControls: materialTextSelectionHandleControls,
          //     child: Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: List.generate(splitContents.length, (index) {
          //         final input = splitContents[index];
          //         return ProxyRichText(
          //           TextSpan(
          //               children: convertHiNodes(
          //                   hi.highlight
          //                       .parse(input,
          //                           language: widget.language,
          //                           autoDetection: false)
          //                       .nodes!,
          //                   widget.preConfig.theme,
          //                   widget.style,
          //                   widget.preConfig.styleNotMatched)
          //               // uses trimRight and we don't need trimming here
          //               // children: highLightSpans(
          //               //   currentContent,
          //               //   language: widget.language,
          //               //   theme: widget.preConfig.theme,
          //               //   textStyle: widget.style,
          //               //   styleNotMatched: widget.preConfig.styleNotMatched,
          //               // ),
          //               ),
          //         );
          //       }),
          //     ),
          //   ),
          // ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return SelectionContainer.disabled(
      child: fluent.SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.theme.accentColor.withAlpha(128),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: fluent.Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
            child: Wrap(
              spacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                fluent.Tooltip(
                  message: 'Run python/shell code (only for python and shell commands!)',
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
                        padding: fluent.WidgetStateProperty.all(fluent.EdgeInsets.zero),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _switchWidget,
                      ),
                      onPressed: () async {
                        if (hasCopied) return;
                        await Clipboard.setData(ClipboardData(text: widget.content));
                        displayCopiedToClipboard();
                        _switchWidget = Icon(Icons.check);
                        refresh();
                        Future.delayed(const Duration(seconds: 2), () {
                          hasCopied = false;
                          _switchWidget = Icon(Icons.copy_rounded);
                          refresh();
                        });
                      },
                    ),
                  ),
                ),
                // open in vscode
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: fluent.SizedBox.square(
                    dimension: 30,
                    child: fluent.Button(
                      style: fluent.ButtonStyle(
                        padding: fluent.WidgetStateProperty.all(fluent.EdgeInsets.zero),
                      ),
                      child: Icon(FluentIcons.open_20_filled),
                      onPressed: () => openInVsCode(widget.content),
                    ),
                  ),
                ),
                if (widget.language.isNotEmpty)
                  DecoratedBox(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(width: 0.5, color: isDark ? Colors.white : Colors.black)),
                    child: fluent.Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Text(widget.language, style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  Future<void> openInVsCode(String content) async {
    // Generate a temporary file path with appropriate extension
    final extension = _getFileExtension(widget.language);
    final fileName = "code_${DateTime.now().millisecondsSinceEpoch}$extension";
    final filePath = "${FileUtils.appTemporaryDirectoryPath}/$fileName";

    // Save the content to the temporary file
    await FileUtils.saveFile(filePath, content);
    bool containsVSCode = ShellDriver.containsVScodeInstalled();

    // Open VS Code with the file
    if (containsVSCode) {
      await ShellDriver.runShellCommand("code \"$filePath\"");
    } else {
      // Open in native app based on platform
      if (Platform.isWindows) {
        await ShellDriver.runShellCommand("start \"$filePath\"");
      } else if (Platform.isMacOS) {
        await ShellDriver.runShellCommand("open \"$filePath\"");
      } else if (Platform.isLinux) {
        await ShellDriver.runShellCommand("xdg-open \"$filePath\"");
      }
    }
  }

  // Helper method to determine file extension based on language
  String _getFileExtension(String language) {
    switch (language.toLowerCase()) {
      case 'python':
        return '.py';
      case 'javascript':
      case 'js':
        return '.js';
      case 'typescript':
      case 'ts':
        return '.ts';
      case 'html':
        return '.html';
      case 'css':
        return '.css';
      case 'dart':
        return '.dart';
      case 'java':
        return '.java';
      case 'c':
        return '.c';
      case 'cpp':
      case 'c++':
        return '.cpp';
      case 'csharp':
      case 'c#':
        return '.cs';
      case 'json':
        return '.json';
      case 'xml':
        return '.xml';
      case 'markdown':
      case 'md':
        return '.md';
      case 'shell':
      case 'bash':
      case 'sh':
        return '.sh';
      case 'batch':
      case 'cmd':
        return '.bat';
      case 'powershell':
      case 'ps1':
        return '.ps1';
      default:
        return '.txt';
    }
  }
}

class SqueareIconButton extends fluent.StatelessWidget {
  const SqueareIconButton({super.key, required this.onTap, required this.icon, required this.tooltip});
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
      {super.key, required this.onTap, required this.icon, this.width = 30, this.height = 30, required this.tooltip});
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
