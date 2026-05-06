import 'package:fluent_gpt/common/agent_mode_enum.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/tools/tool_def.dart';
import 'package:fluent_gpt/gpt_tools.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';

/// Single source of truth for tool definitions across both the agent loop and
/// the non-agent (Ask/Plan/normal) path.
///
/// Each tool declares the modes in which it is exposed to the model, an
/// optional [BoolPref] kill switch, and (for non-agent paths) a side-effect
/// closure. The agent path keeps its own internal dispatch — the registry
/// gates which tools it advertises and validates that an executed tool is
/// allowed in agent mode.
final List<ToolDef> allTools = <ToolDef>[
  ToolDef(
    name: 'copy_to_clipboard_tool',
    description: 'Tool to copy text to user clipboard',
    schema: copyToClipboardFunctionParameters,
    allowedModes: const {AgentMode.agent, AgentMode.ask, AgentMode.plan},
    enableFlag: AppCache.gptToolCopyToClipboardEnabled,
    sideEffect: (p, args, _) async {
      await (p as ChatProvider).runCopyToClipboardSideEffect(args);
    },
  ),
  ToolDef(
    name: 'remember_info_tool',
    description: 'Tool to remember info. Use it to store info about user or important notes',
    schema: rememberInfoParameters,
    allowedModes: const {AgentMode.agent, AgentMode.ask, AgentMode.plan},
    enableFlag: AppCache.gptToolRememberInfo,
    sideEffect: (p, args, _) async {
      await (p as ChatProvider).runRememberInfoSideEffect(args);
    },
  ),
  ToolDef(
    name: 'auto_open_urls_tool',
    description: 'Open a URL in the user\'s default browser',
    schema: autoOpenUrlParameters,
    allowedModes: const {AgentMode.agent},
    enableFlag: AppCache.gptToolAutoOpenUrls,
    sideEffect: (p, args, tokensReceived) async {
      await (p as ChatProvider).runAutoOpenUrlsSideEffect(args, tokensReceived);
    },
  ),
  ToolDef(
    name: 'generate_image_tool',
    description: 'Generate an image from a text prompt',
    schema: generateImageParameters,
    allowedModes: const {AgentMode.agent},
    enableFlag: AppCache.gptToolGenerateImage,
    sideEffect: (p, args, _) async {
      await (p as ChatProvider).runGenerateImageSideEffect(args);
    },
  ),
  // Agent-only tools (no side-effect closure — the agent path dispatches them
  // through its own internal switch).
  const ToolDef(
    name: 'read_file_tool',
    description:
        'Read a file from the user\'s filesystem by line range. Use offset+limit (1-based lines) to chunk large files.',
    schema: readFileToolParameters,
    allowedModes: {AgentMode.agent},
  ),
  const ToolDef(
    name: 'list_directory_tool',
    description: 'List directory contents. Supports glob filtering and skipping common heavy folders.',
    schema: listDirectoryToolParameters,
    allowedModes: {AgentMode.agent},
  ),
  const ToolDef(
    name: 'search_files_tool',
    description: 'Find files by filename pattern under a directory tree.',
    schema: searchFilesToolParameters,
    allowedModes: {AgentMode.agent},
  ),
  const ToolDef(
    name: 'grep_tool',
    description: 'Search file contents by regex. Uses ripgrep when available.',
    schema: grepToolParameters,
    allowedModes: {AgentMode.agent},
  ),
  const ToolDef(
    name: 'edit_file_tool',
    description: 'Replace one unique old_string with new_string in a file.',
    schema: editFileToolParameters,
    allowedModes: {AgentMode.agent},
  ),
  const ToolDef(
    name: 'write_file_tool',
    description: 'Write or append full content to a file. Use for new files or complete rewrites.',
    schema: writeFileToolParameters,
    allowedModes: {AgentMode.agent},
  ),
  const ToolDef(
    name: 'execute_shell_command_tool',
    description: 'Run a shell command. 30s timeout, 10KB output cap. Always check exit codes.',
    schema: executeShellCommandToolParameters,
    allowedModes: {AgentMode.agent},
  ),
];

/// Tools available in [mode], filtered by their [BoolPref] enable flags.
List<ToolDef> toolsForMode(AgentMode mode) =>
    allTools.where((t) => t.isAvailableIn(mode)).toList(growable: false);

ToolDef? toolByName(String name) {
  for (final t in allTools) {
    if (t.name == name) return t;
  }
  return null;
}

/// Comma-separated list of tool names available in [mode]. Empty string when
/// no tools are exposed (e.g. all flags off).
String toolsAvailableLine(AgentMode mode) =>
    toolsForMode(mode).map((t) => t.name).join(', ');
