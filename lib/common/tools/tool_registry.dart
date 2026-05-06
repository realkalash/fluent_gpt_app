import 'package:fluent_gpt/common/agent_mode_enum.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/tools/agent_tool_handlers.dart';
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
    agentExecute: AgentToolHandlers.copyToClipboard,
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
    agentExecute: AgentToolHandlers.rememberInfo,
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
    agentExecute: AgentToolHandlers.autoOpenUrls,
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
    agentExecute: AgentToolHandlers.generateImage,
  ),
  // Agent-only tools.
  const ToolDef(
    name: 'read_file_tool',
    description:
        'Read a slice of a text file by line range. Prefer offset+limit on large files; omitting both caps output (~500 lines) to save tokens',
    schema: readFileToolParameters,
    allowedModes: {AgentMode.agent},
    agentExecute: AgentToolHandlers.readFile,
  ),
  const ToolDef(
    name: 'list_directory_tool',
    description: 'List files and/or directories with optional glob filter, excludes, and recursive mode',
    schema: listDirectoryToolParameters,
    allowedModes: {AgentMode.agent},
    agentExecute: AgentToolHandlers.listDirectory,
  ),
  const ToolDef(
    name: 'search_files_tool',
    description: 'Find files by filename pattern (wildcards * and ?) under a directory',
    schema: searchFilesToolParameters,
    allowedModes: {AgentMode.agent},
    agentExecute: AgentToolHandlers.searchFiles,
  ),
  const ToolDef(
    name: 'grep_tool',
    description:
        'Search file contents by regex (fast via ripgrep when installed; otherwise scans files). Use after search_files_tool or to locate symbols before read_file_tool',
    schema: grepToolParameters,
    allowedModes: {AgentMode.agent},
    agentExecute: AgentToolHandlers.grep,
  ),
  const ToolDef(
    name: 'edit_file_tool',
    description:
        'Replace exactly one occurrence of old_string with new_string in an existing file. Prefer this over write_file_tool for small edits',
    schema: editFileToolParameters,
    allowedModes: {AgentMode.agent},
    agentExecute: AgentToolHandlers.editFile,
  ),
  const ToolDef(
    name: 'write_file_tool',
    description:
        'Write or append full file content. Use for new files or full rewrites; prefer edit_file_tool for targeted edits',
    schema: writeFileToolParameters,
    allowedModes: {AgentMode.agent},
    agentExecute: AgentToolHandlers.writeFile,
  ),
  const ToolDef(
    name: 'execute_shell_command_tool',
    description: 'Execute a shell/terminal command and return the output',
    schema: executeShellCommandToolParameters,
    allowedModes: {AgentMode.agent},
    agentExecute: AgentToolHandlers.executeShellCommand,
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
