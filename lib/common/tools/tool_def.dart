import 'dart:convert';

import 'package:fluent_gpt/common/agent_mode_enum.dart';
import 'package:fluent_gpt/common/prefs/prefs_types.dart';
import 'package:fluent_gpt/log.dart';
import 'package:langchain/langchain.dart';

typedef ChatToolSideEffect = Future<void> Function(
  dynamic provider,
  Map<String, dynamic> args,
  int tokensReceivedInResponse,
);

class ToolDef {
  final String name;
  final String description;
  final Map<String, dynamic> schema;
  final Set<AgentMode> allowedModes;
  final BoolPref? enableFlag;

  /// Side-effect handler for non-agent paths (Ask/Plan/normal). The agent path
  /// has its own dispatch; tools available there are filtered via allowedModes
  /// containing AgentMode.agent. May be null when a tool only exists for the
  /// agent path.
  final ChatToolSideEffect? sideEffect;

  const ToolDef({
    required this.name,
    required this.description,
    required this.schema,
    required this.allowedModes,
    this.enableFlag,
    this.sideEffect,
  });

  bool get isEnabled => enableFlag?.value ?? true;

  bool isAvailableIn(AgentMode m) => allowedModes.contains(m) && isEnabled;

  ToolSpec toSpec() => ToolSpec(
        name: name,
        description: description,
        inputJsonSchema: schema,
      );
}

/// Per-slot accumulator for a single streaming tool call.
class ToolStreamAgg {
  String id = '';
  String name = '';
  final StringBuffer argumentsRaw = StringBuffer();
}

/// End index (exclusive) of a balanced `{...}` starting at [openBraceIndex], or -1.
int _balancedJsonObjectEnd(String s, int openBraceIndex) {
  var depth = 0;
  var inString = false;
  var escape = false;
  for (var j = openBraceIndex; j < s.length; j++) {
    final c = s.codeUnitAt(j);
    if (escape) {
      escape = false;
      continue;
    }
    if (inString) {
      if (c == 0x5C) {
        escape = true;
      } else if (c == 0x22) {
        inString = false;
      }
      continue;
    }
    if (c == 0x22) {
      inString = true;
      continue;
    }
    if (c == 0x7B) {
      depth++;
    } else if (c == 0x7D) {
      depth--;
      if (depth == 0) {
        return j + 1;
      }
    }
  }
  return -1;
}

String? extractFirstJsonObject(String input) {
  final start = input.indexOf('{');
  if (start < 0) return null;
  final end = _balancedJsonObjectEnd(input, start);
  if (end <= start) return null;
  return input.substring(start, end);
}

/// Parses tool `argumentsRaw`; handles models that concatenate multiple JSON
/// objects (one tool's args appended to another's).
({Map<String, dynamic> map, String? warning})? parseToolArgumentsRaw(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return (map: <String, dynamic>{}, warning: null);
  }
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) {
      return (map: decoded, warning: null);
    }
  } catch (_) {}

  final first = extractFirstJsonObject(trimmed);
  if (first == null) return null;
  try {
    final decoded = jsonDecode(first) as Map<String, dynamic>;
    String? warning;
    final rest = trimmed.substring(trimmed.indexOf(first) + first.length).trim();
    if (rest.isNotEmpty) {
      if (rest.startsWith('{')) {
        warning =
            'Tool arguments contained multiple JSON objects; only the first was used. Call one tool per turn, or wait for each tool result before the next tool.';
      } else {
        warning = 'Trailing non-JSON text after tool arguments was ignored.';
      }
    }
    return (map: decoded, warning: warning);
  } catch (_) {
    return null;
  }
}

/// Logs a parse failure consistently across both call paths.
void logToolParseFailure(String toolName, Object error, String raw) {
  logError('Tool "$toolName" args parse failed: $error. Raw: $raw');
}
