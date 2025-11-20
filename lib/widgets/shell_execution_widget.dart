import 'dart:async';
import 'dart:convert';

import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shell/shell.dart';

/// Terminal-style widget for displaying shell command execution results
class ShellExecutionWidget extends StatefulWidget {
  final FluentChatMessage message;

  const ShellExecutionWidget({
    super.key,
    required this.message,
  });

  @override
  State<ShellExecutionWidget> createState() => _ShellExecutionWidgetState();
}

class _ShellExecutionWidgetState extends State<ShellExecutionWidget> {
  bool _isExpanded = true;
  bool _isExecuting = false;

  Future<void> _runCommand(String command) async {
    if (_isExecuting) return;

    setState(() {
      _isExecuting = true;
    });

    try {
      var shell = Shell();
      final parts = _parseCommand(command);
      
      if (parts.isEmpty) {
        throw Exception('Empty command');
      }

      final commandName = parts.first;
      final commandArgs = parts.length > 1 ? parts.sublist(1) : <String>[];

      String stdout = '';
      String stderr = '';
      int exitCode = 0;

      try {
        final process = await shell.start(commandName, arguments: commandArgs)
            .timeout(const Duration(seconds: 30));
        
        stdout = await process.stdout.readAsString();
        stderr = await process.stderr.readAsString();
        exitCode = await process.exitCode;
        
        // Limit output size
        if (stdout.length > 10240) {
          stdout = '${stdout.substring(0, 10240)}\n... (output truncated)';
        }
        if (stderr.length > 10240) {
          stderr = '${stderr.substring(0, 10240)}\n... (output truncated)';
        }
      } on TimeoutException {
        stderr = 'Command timed out after 30 seconds';
        exitCode = -1;
      } catch (e) {
        stderr = 'Error: $e';
        exitCode = -1;
      }

      // Update message to shellExec type with results
      final provider = context.read<ChatProvider>();
      final updatedMessage = FluentChatMessage.shellExec(
        id: widget.message.id,
        command: command,
        exitCode: exitCode,
        stdout: stdout,
        stderr: stderr,
        creator: widget.message.creator,
        timestamp: widget.message.timestamp,
      );

      provider.updateMessage(updatedMessage);
    } catch (e) {
      logError('Error running shell command: $e');
      if (mounted) {
        displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: Text('Error executing command: $e'),
            severity: InfoBarSeverity.error,
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExecuting = false;
        });
      }
    }
  }

  List<String> _parseCommand(String command) {
    final parts = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    bool escape = false;

    for (int i = 0; i < command.length; i++) {
      final char = command[i];

      if (escape) {
        buffer.write(char);
        escape = false;
        continue;
      }

      if (char == '\\') {
        escape = true;
        continue;
      }

      if (char == '"' || char == "'") {
        inQuotes = !inQuotes;
        continue;
      }

      if (char == ' ' && !inQuotes) {
        if (buffer.isNotEmpty) {
          parts.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }

      buffer.write(char);
    }

    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }

    return parts;
  }

  @override
  Widget build(BuildContext context) {
    // Parse the JSON content
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(widget.message.content) as Map<String, dynamic>;
    } catch (e) {
      return Text('Error parsing shell execution data: $e');
    }

    final command = data['command'] as String? ?? '';
    final description = data['description'] as String?;
    final exitCode = data['exitCode'] as int?;
    final stdout = data['stdout'] as String? ?? '';
    final stderr = data['stderr'] as String? ?? '';

    final theme = FluentTheme.of(context);
    final isProposal = widget.message.type == FluentChatMessageType.shellProposal || exitCode == null;
    final isSuccess = exitCode == 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF1E1E1E) : const Color(0xFF2D2D30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.brightness == Brightness.dark ? const Color(0xFF3E3E42) : const Color(0xFF4E4E50),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Command header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark ? const Color(0xFF252526) : const Color(0xFF3C3C3C),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Row(
              children: [
                // Terminal prompt
                Text(
                  '\$ ',
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 13,
                    color: isProposal 
                        ? Colors.orange 
                        : (isSuccess ? Colors.green : Colors.red),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Command
                Expanded(
                  child: Text(
                    command,
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Run button (for proposals only)
                if (isProposal)
                  FilledButton(
                    onPressed: _isExecuting ? null : () => _runCommand(command),
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                    ),
                    child: _isExecuting
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: ProgressRing(strokeWidth: 2),
                          )
                        : const Text('Run', style: TextStyle(fontSize: 12)),
                  ),
                // Copy button (for executed commands)
                if (!isProposal)
                  IconButton(
                    icon: const Icon(FluentIcons.copy, size: 14),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: stdout.isNotEmpty ? stdout : stderr));
                      displayInfoBar(context, builder: (context, close) {
                        return InfoBar(
                          title: const Text('Copied to clipboard'),
                          severity: InfoBarSeverity.success,
                        );
                      });
                    },
                  ),
                const SizedBox(width: 4),
                // Expand/collapse button
                IconButton(
                  icon: Icon(
                    _isExpanded ? FluentIcons.chevron_up : FluentIcons.chevron_down,
                    size: 14,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ],
            ),
          ),

          // Output area (collapsible)
          if (_isExpanded) ...[
            // Show description for proposals
            if (isProposal && description != null && description.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark 
                      ? const Color(0xFF2B2B2B) 
                      : const Color(0xFF353535),
                ),
                child: Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFCCCCCC),
                    height: 1.4,
                  ),
                ),
              ),

            // Show "Click Run to execute" for proposals
            if (isProposal)
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.info,
                      size: 12,
                      color: Colors.orange.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Click "Run" to execute this command',
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 11,
                          color: Color(0xFF808080),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // stdout (for executed commands)
            if (!isProposal && stdout.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  stdout,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                    color: Color(0xFFCCCCCC),
                    height: 1.4,
                  ),
                ),
              ),

            // stderr (for executed commands)
            if (!isProposal && stderr.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF3F1F1F),
                ),
                child: SelectableText(
                  stderr,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                    color: Color(0xFFF48771),
                    height: 1.4,
                  ),
                ),
              ),

            // Empty output message (for executed commands)
            if (!isProposal && stdout.isEmpty && stderr.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                child: const Text(
                  '(no output)',
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                    color: Color(0xFF808080),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // Exit code footer (for executed commands only)
            if (!isProposal)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark ? const Color(0xFF252526) : const Color(0xFF3C3C3C),
                  border: const Border(
                    top: BorderSide(
                      color: Color(0xFF3E3E42),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSuccess ? FluentIcons.check_mark : FluentIcons.error_badge,
                      size: 12,
                      color: isSuccess ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Exit code: $exitCode',
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 11,
                        color: isSuccess ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
