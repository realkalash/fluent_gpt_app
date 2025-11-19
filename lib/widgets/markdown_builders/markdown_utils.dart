import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/shell_driver.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/custom_selectable_region.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:markdown_widget/config/all.dart';
import 'package:markdown_widget/widget/all.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher_string.dart';

import 'code_wrapper.dart';

///Tag: [MarkdownTag.em]
///
/// emphasis, Markdown treats asterisks (*) and underscores (_) as indicators of emphasis
class EmCustomNode extends ElementNode {
  @override
  TextStyle get style => parentStyle!.merge(TextStyle(fontStyle: FontStyle.italic, color: Colors.amber));
}

///Custom Think Block Node
///
/// Handles <think> tags for reasoning/thinking process display
/// Usage example: <think>Your reasoning here</think>
class ThinkNode extends ElementNode {
  final String textContent;

  ThinkNode({required this.textContent});

  @override
  InlineSpan build() {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: ThinkBlockWidget(textContent: textContent, style: style),
    );
  }

  @override
  TextStyle get style => parentStyle!.merge(
        TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.orange.shade800,
          fontSize: (parentStyle?.fontSize ?? 16) * 0.9,
          height: 1.4,
        ),
      );
}

///Custom Path/URL Link Node
///
/// Handles [path:...] and [url:...] syntax for clickable file paths and URLs
/// Usage: [path:C:\Users\file.txt] or [url:https://example.com]
class PathLinkNode extends ElementNode {
  final String type; // 'path' or 'url'
  final String content;

  PathLinkNode({required this.type, required this.content});

  @override
  InlineSpan build() {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: PathLinkWidget(type: type, content: content, style: style),
    );
  }

  @override
  TextStyle get style => parentStyle!.merge(
        TextStyle(
          color: type == 'path' ? Colors.blue.shade600 : Colors.purple.shade600,
          fontFamily: 'Consolas',
          fontSize: (parentStyle?.fontSize ?? 16) * 0.9,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
        ),
      );
}

class PathLinkWidget extends StatefulWidget {
  final String type;
  final String content;
  final TextStyle style;

  const PathLinkWidget({
    super.key,
    required this.type,
    required this.content,
    required this.style,
  });

  @override
  State<PathLinkWidget> createState() => _PathLinkWidgetState();
}

class _PathLinkWidgetState extends State<PathLinkWidget> {
  bool _isHovered = false;

  Future<void> _openPath() async {
    try {
      // Convert path to file:// URI
      final uri = Uri.file(widget.content).toString();
      if (await canLaunchUrlString(uri)) {
        await launchUrlString(uri);
      } else {
        // If can't open, show error and copy instead
        await Clipboard.setData(ClipboardData(text: widget.content));
        displayCopiedToClipboard();
      }
    } catch (e) {
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: widget.content));
      displayCopiedToClipboard();
    }
  }

  void openFileDirectory(String filePath) {
    // Open file explorer and select the file
    ShellDriver.openExplorerAndSelectFile(filePath);
  }

  Future<void> _openUrl() async {
    try {
      if (await canLaunchUrlString(widget.content)) {
        await launchUrlString(widget.content);
      } else {
        // If opening fails, copy to clipboard
        await Clipboard.setData(ClipboardData(text: widget.content));
        displayCopiedToClipboard();
      }
    } catch (e) {
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: widget.content));
      displayCopiedToClipboard();
    }
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    displayCopiedToClipboard();
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.type == 'path' 
        ? FluentIcons.folder_20_filled 
        : FluentIcons.link_20_filled;
    
    return SelectionContainer.disabled(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: widget.type == 'path' ? _openPath : _openUrl,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _isHovered
                      ? (widget.type == 'path' 
                          ? Colors.blue.withAlpha(30) 
                          : Colors.purple.withAlpha(30))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: widget.type == 'path' 
                        ? Colors.blue.withAlpha(100) 
                        : Colors.purple.withAlpha(100),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => openFileDirectory(widget.content),
                      child: Icon(
                        icon,
                        size: 12,
                        color: widget.type == 'path' ? Colors.blue : Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.content,
                        style: widget.style,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      FluentIcons.open_20_filled,
                      size: 10,
                      color: widget.type == 'path' ? Colors.blue : Colors.purple,
                    ),
                  ],
                ),
              ),
            ),
            if (widget.type == 'path') ...[
              const SizedBox(width: 2),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _copyToClipboard,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _isHovered ? Colors.blue.withAlpha(30) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      FluentIcons.copy_20_filled,
                      size: 10,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ThinkBlockWidget extends StatefulWidget {
  final String textContent;
  final TextStyle style;
  const ThinkBlockWidget({super.key, required this.textContent, required this.style});

  @override
  State<ThinkBlockWidget> createState() => _ThinkBlockWidgetState();
}

class _ThinkBlockWidgetState extends State<ThinkBlockWidget> {
  bool isExpanded = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            isExpanded = !isExpanded;
          });
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: Colors.orange,
                width: 4,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withAlpha(26),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AnimatedCrossFade(
            duration: Durations.medium3,
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(FluentIcons.brain_sparkle_20_filled, color: Colors.orange, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    'Thinking...'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Icon(FluentIcons.chevron_down_20_filled, color: Colors.orange, size: 18),
                ],
              ),
            ),
            secondChild: Padding(
              key: Key(widget.textContent),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(51),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        FluentIcons.brain_sparkle_20_filled,
                        color: Colors.orange,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thinking...'.tr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(widget.textContent, style: widget.style),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom block syntax to parse <think> tags
///
/// This implementation allows you to use <think> tags in your markdown content
/// for displaying reasoning blocks with custom styling. Unlike inline syntax,
/// this properly handles multi-line content and nested markdown.
///
/// Example usage:
/// ```
/// String content = '''
/// Here's my analysis:
///
/// <think>
/// Let me think through this step by step:
///
/// 1. **First consideration**: User requirements
/// 2. **Second thought**: Technical constraints
/// 3. **Final conclusion**: Best approach
///
/// Based on this analysis, I believe the best approach would be...
/// </think>
///
/// My recommendation is to implement a custom solution.
/// ''';
///
/// buildMarkdown(context, content);
/// ```
///
/// The <think> blocks will be rendered with:
/// - Orange color scheme with left border
/// - Psychology icon and "Thinking..." header
/// - Container with rounded corners and shadow
/// - Support for nested markdown content
class ThinkBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^<think>\s*$', multiLine: true);

  @override
  md.Node? parse(md.BlockParser parser) {
    final startLine = parser.current.content;

    // Check if current line matches opening tag
    if (!pattern.hasMatch(startLine)) {
      return null;
    }

    parser.advance(); // Skip the opening <think> line

    final contentLines = <String>[];

    // Read lines until we find closing tag
    while (!parser.isDone) {
      final line = parser.current.content;
      if (line.trim() == '</think>') {
        parser.advance(); // Skip the closing tag
        break;
      }
      contentLines.add(line);
      parser.advance();
    }

    // Join content and create element
    final content = contentLines.join('\n').trim();
    final element = md.Element('think', [md.Text(content)]);

    return element;
  }
}

/// Custom inline syntax to parse [path:...] and [url:...] tags
///
/// Detects patterns like:
/// - [path:C:\Users\alex\file.txt] - File paths (click to copy)
/// - [url:https://example.com] - URLs (click to open)
class PathLinkSyntax extends md.InlineSyntax {
  PathLinkSyntax() : super(r'\[(path|url):([^\]]+)\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final type = match[1]!; // 'path' or 'url'
    final content = match[2]!; // The actual path or URL
    
    final element = md.Element.text('pathlink', content);
    element.attributes['type'] = type;
    element.attributes['content'] = content;
    
    parser.addNode(element);
    return true;
  }
}

Widget buildMarkdown(
  BuildContext context,
  String data, {
  String? language,
  double? textSize,
  Widget Function(BuildContext, CustomSelectableRegionState)? contextMenuBuilderMarkdown,
  Widget Function(BuildContext, EditableTextState)? contextMenuBuilder,
  void Function(SelectedContent?)? onSelectionChanged,
  FocusNode? focusNode,
  FocusNode? parentFocusNode,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final config = isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;

  return CustomSelectableRegion(
    contextMenuBuilder: contextMenuBuilderMarkdown,
    focusNode: focusNode,
    onSelectionChanged: onSelectionChanged,
    selectionControls: materialTextSelectionHandleControls,
    child: MarkdownWidget(
      data: data,
      shrinkWrap: true,
      selectable: false,
      markdownGenerator: MarkdownGenerator(
        extensionSet: md.ExtensionSet(
          [
            ThinkBlockSyntax(),
            ...md.ExtensionSet.commonMark.blockSyntaxes,
          ],
          [
            PathLinkSyntax(),
            ...md.ExtensionSet.commonMark.inlineSyntaxes,
          ],
        ),
        generators: [
          SpanNodeGeneratorWithTag(
            generator: (e, config, visitor) {
              return EmCustomNode();
            },
            tag: MarkdownTag.em.name,
          ),
          SpanNodeGeneratorWithTag(
            generator: (e, config, visitor) {
              return ThinkNode(textContent: e.textContent);
            },
            tag: 'think',
          ),
          SpanNodeGeneratorWithTag(
            generator: (e, config, visitor) {
              final type = e.attributes['type'] ?? 'path';
              final content = e.attributes['content'] ?? e.textContent;
              return PathLinkNode(type: type, content: content);
            },
            tag: 'pathlink',
          ),
        ],
      ),
      config: config.copy(
        configs: [
          PConfig(textStyle: TextStyle(fontSize: textSize ?? 16)),
          isDark
              ? PreConfig.darkConfig.copy(
                  styleNotMatched: TextStyle(fontSize: textSize, color: Colors.amber, backgroundColor: Colors.black),
                  wrapper: (child, code, lang) => CodeWrapperWidget(
                    content: code,
                    language: lang,
                    preConfig: PreConfig.darkConfig,
                    style: TextStyle(fontSize: textSize),
                    contextMenuBuilder: contextMenuBuilder,
                    focusNode: FocusNode(),
                  ),
                  language: language,
                  textStyle: TextStyle(fontSize: textSize, color: Colors.red),
                  margin: const EdgeInsets.all(0),
                  decoration: BoxDecoration(
                    color: context.theme.cardColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                )
              : const PreConfig().copy(
                  styleNotMatched: TextStyle(fontSize: textSize),
                  wrapper: (child, code, lang) => CodeWrapperWidget(
                    content: code,
                    language: lang,
                    preConfig: PreConfig.darkConfig,
                    style: TextStyle(fontSize: textSize),
                    contextMenuBuilder: contextMenuBuilder,
                    focusNode: FocusNode(),
                  ),
                  language: language,
                  margin: const EdgeInsets.all(0),
                  textStyle: PreConfig.darkConfig.textStyle.copyWith(
                    fontSize: textSize,
                  ),
                  decoration: BoxDecoration(
                    color: context.theme.cardColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                )
        ],
      ),
    ),
  );
}
