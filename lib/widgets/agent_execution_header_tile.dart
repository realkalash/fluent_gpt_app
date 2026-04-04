import 'dart:async';
import 'dart:convert';

import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fluent_ui/fluent_ui.dart';

/// Max lines to instantiate in the flyout; keeps memory and build work bounded.
const int _kAgentToolOutputMaxLines = 400;

/// Status line for agent tool execution / completion; hover shows the tool result the model received.
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
    if (!widget.message.hasAgentToolOutputSnapshot) {
      return;
    }
    _openTimer?.cancel();
    _openTimer = Timer(const Duration(milliseconds: 380), () {
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
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 360),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tool output (what the model saw)',
                  style: theme.typography.subtitle,
                ),
                if (widget.message.agentToolName != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.message.agentToolName!,
                    style: theme.typography.caption,
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  height: 280,
                  width: 480,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                      border: Border.all(color: theme.resources.controlStrokeColorDefault),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(3)),
                      child: _AgentToolOutputPreview(
                        raw: widget.message.agentToolResult ?? '',
                        theme: theme,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

    if (!widget.message.hasAgentToolOutputSnapshot) {
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

  @override
  void dispose() {
    _verticalScroll.dispose();
    super.dispose();
  }

  static TextStyle _monoLineStyle(FluentThemeData theme) {
    final base = theme.typography.body;
    return TextStyle(
      inherit: true,
      fontSize: 12,
      height: 1.35,
      color: base?.color,
      // First available: native-looking monospace per platform; web falls through to monospace.
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

    final allLines = const LineSplitter().convert(widget.raw);
    final omitted = allLines.length > _kAgentToolOutputMaxLines ? allLines.length - _kAgentToolOutputMaxLines : 0;
    final displayLines = omitted > 0 ? allLines.take(_kAgentToolOutputMaxLines).toList(growable: false) : allLines;

    final lineCount = displayLines.length;
    final gutterDigits = lineCount.toString().length;
    final gutterW = (8 + gutterDigits * 7.0).clamp(28.0, 52.0);

    final gutterStyle = TextStyle(
      fontSize: 11,
      height: 1.35,
      color: captionColor.withAlpha(180),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final lineRows = <Widget>[
      for (var index = 0; index < lineCount; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: gutterW,
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
              Text(
                displayLines[index],
                style: mono,
                softWrap: false,
              ),
            ],
          ),
        ),
      if (omitted > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
          child: Text(
            '… and $omitted more line${omitted == 1 ? '' : 's'} not shown',
            style: widget.theme.typography.caption?.copyWith(
              color: captionColor.withAlpha(200),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
    ];

    // Vertical scroll for many lines; horizontal scroll moves the whole block together.
    return Scrollbar(
      controller: _verticalScroll,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScroll,
        primary: false,
        scrollDirection: Axis.vertical,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: SingleChildScrollView(
          primary: false,
          scrollDirection: Axis.horizontal,
          child: RepaintBoundary(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: lineRows,
            ),
          ),
        ),
      ),
    );
  }
}
