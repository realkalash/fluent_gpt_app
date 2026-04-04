import 'dart:async';
import 'dart:convert';

import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fluent_ui/fluent_ui.dart';

/// Max lines to instantiate in the flyout; keeps memory and build work bounded.
const int _kAgentToolOutputMaxLines = 400;

String? _prettyFormatToolArgumentsJson(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return raw;
  }
}

TextStyle _monoStyleForFlyout(FluentThemeData theme) {
  final base = theme.typography.body;
  return TextStyle(
    inherit: true,
    fontSize: 12,
    height: 1.35,
    color: base?.color,
    fontFamily: kIsWeb ? null : 'Menlo',
    fontFamilyFallback: const [
      'Menlo',
      'Consolas',
      'Courier New',
      'monospace',
    ],
  );
}

/// Status line for agent tool execution / completion; hover shows stored args + exact tool output string.
class AgentExecutionHeaderTile extends StatefulWidget {
  const AgentExecutionHeaderTile({super.key, required this.message});

  final FluentChatMessage message;

  @override
  State<AgentExecutionHeaderTile> createState() => _AgentExecutionHeaderTileState();
}

class _AgentExecutionHeaderTileState extends State<AgentExecutionHeaderTile> {
  final FlyoutController _flyoutController = FlyoutController();
  Timer? _openTimer;

  @override
  void dispose() {
    _openTimer?.cancel();
    if (_flyoutController.isOpen) {
      _flyoutController.forceClose();
    }
    _flyoutController.dispose();
    super.dispose();
  }

  void _scheduleShowFlyout() {
    if (!widget.message.hasAgentToolFlyoutContent) {
      return;
    }
    _openTimer?.cancel();
    _openTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted || _flyoutController.isOpen) {
        return;
      }
      _flyoutController.showFlyout(
        barrierDismissible: true,
        dismissWithEsc: true,
        dismissOnPointerMoveAway: true,
        builder: (context) {
          final theme = FluentTheme.of(context);
          return FlyoutContent(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 480),
            child: _AgentToolTraceFlyoutContent(message: widget.message, theme: theme),
          );
        },
      );
    });
  }

  void _cancelOpen() {
    _openTimer?.cancel();
    _openTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final baseStyle = TextStyle(
      fontSize: 14,
      color: theme.typography.caption?.color?.withAlpha(127),
    );

    final child = Text(
      widget.message.content,
      textAlign: TextAlign.left,
      style: baseStyle,
    );

    if (!widget.message.hasAgentToolFlyoutContent) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: child,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FlyoutTarget(
        controller: _flyoutController,
        child: MouseRegion(
          cursor: SystemMouseCursors.help,
          onEnter: (_) => _scheduleShowFlyout(),
          onExit: (_) => _cancelOpen(),
          child: child,
        ),
      ),
    );
  }
}

class _AgentToolTraceFlyoutContent extends StatelessWidget {
  const _AgentToolTraceFlyoutContent({
    required this.message,
    required this.theme,
  });

  final FluentChatMessage message;
  final FluentThemeData theme;

  @override
  Widget build(BuildContext context) {
    // final argsFormatted = _prettyFormatToolArgumentsJson(message.agentToolArgumentsJson);
    final rawResult = message.agentToolResult ?? '';
    final hasOutput = rawResult.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Tool trace', style: theme.typography.subtitle),
        if (message.agentToolName != null) ...[
          const SizedBox(height: 4),
          Text(
            message.agentToolName!,
            style: theme.typography.caption,
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Output (what the model saw)',
          style: theme.typography.subtitle,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 220,
          width: 480,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              border: Border.all(color: theme.resources.controlStrokeColorDefault),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(3)),
              child: hasOutput
                  ? _AgentToolOutputPreview(raw: rawResult, theme: theme)
                  : Center(
                      child: Text(
                        'Output pending…',
                        style: theme.typography.caption,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Line list with shared horizontal scroll (one inner scroller for all lines).
class _AgentToolOutputPreview extends StatefulWidget {
  const _AgentToolOutputPreview({
    required this.raw,
    required this.theme,
  });

  final String raw;
  final FluentThemeData theme;

  @override
  State<_AgentToolOutputPreview> createState() => _AgentToolOutputPreviewState();
}

class _AgentToolOutputPreviewState extends State<_AgentToolOutputPreview> {
  final ScrollController _verticalScroll = ScrollController();

  /// Avoid re-splitting [LineSplitter] on every frame while the flyout is open.
  String? _cacheRaw;
  List<String> _displayLines = const [];
  int _omitted = 0;
  double _gutterW = 28;

  @override
  void dispose() {
    _verticalScroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _recomputeLines();
  }

  @override
  void didUpdateWidget(covariant _AgentToolOutputPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.raw != widget.raw) {
      _recomputeLines();
    }
  }

  void _recomputeLines() {
    final raw = widget.raw;
    if (raw == _cacheRaw) {
      return;
    }
    _cacheRaw = raw;
    if (raw.isEmpty) {
      _displayLines = const [];
      _omitted = 0;
      _gutterW = 28;
      return;
    }
    final allLines = const LineSplitter().convert(raw);
    _omitted = allLines.length > _kAgentToolOutputMaxLines ? allLines.length - _kAgentToolOutputMaxLines : 0;
    _displayLines = _omitted > 0 ? allLines.take(_kAgentToolOutputMaxLines).toList(growable: false) : allLines;
    final lineCount = _displayLines.length;
    final gutterDigits = lineCount.toString().length;
    _gutterW = (8 + gutterDigits * 7.0).clamp(28.0, 52.0);
  }

  static TextStyle _monoLineStyle(FluentThemeData theme) {
    final base = theme.typography.body;
    return TextStyle(
      inherit: true,
      fontSize: 12,
      height: 1.35,
      color: base?.color,
      fontFamily: kIsWeb ? null : 'Menlo',
      fontFamilyFallback: const [
        'Menlo',
        'Consolas',
        'Courier New',
        'monospace',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mono = _monoLineStyle(widget.theme);
    final captionColor = widget.theme.typography.caption?.color ?? widget.theme.inactiveColor;
    final dividerColor = widget.theme.resources.controlStrokeColorDefault;

    if (widget.raw.isEmpty) {
      return Center(
        child: Text(
          '(empty)',
          style: widget.theme.typography.caption,
        ),
      );
    }

    final gutterStyle = TextStyle(
      fontSize: 11,
      height: 1.35,
      color: captionColor.withAlpha(180),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final lineCount = _displayLines.length;
    final footerCount = _omitted > 0 ? 1 : 0;

    return Scrollbar(
      controller: _verticalScroll,
      thumbVisibility: true,
      child: RepaintBoundary(
        child: ListView.builder(
          controller: _verticalScroll,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          itemCount: lineCount + footerCount,
          itemBuilder: (context, index) {
            if (index >= lineCount) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                child: Text(
                  '… and $_omitted more line${_omitted == 1 ? '' : 's'} not shown',
                  style: widget.theme.typography.caption?.copyWith(
                    color: captionColor.withAlpha(200),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: _gutterW,
                    padding: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: dividerColor.withAlpha(120)),
                      ),
                    ),
                    child: Text(
                      '${index + 1} ',
                      textAlign: TextAlign.right,
                      style: gutterStyle,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      primary: false,
                      child: Text(
                        _displayLines[index],
                        style: mono,
                        softWrap: false,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
