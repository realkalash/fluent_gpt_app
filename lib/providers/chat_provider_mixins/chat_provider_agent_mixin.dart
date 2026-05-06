import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fluent_gpt/common/conversaton_style_enum.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/gpt_tools.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_image_generation_mixin.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:shell/shell.dart';
import 'package:url_launcher/url_launcher_string.dart';

const _agentReadDefaultLineCap = 500;
const _agentReadAbsoluteLineCap = 2500;
const _grepToolMaxOutputChars = 48000;
const _dartGrepMaxBytesPerFile = 512 * 1024;

const _commonIgnoredDirNames = {
  '.git',
  'node_modules',
  '.dart_tool',
  'build',
  'dist',
  '.idea',
  '.gradle',
  'Pods',
  'DerivedData',
  '.svn',
  '__pycache__',
  'target',
};

/// End index (exclusive) of a balanced `{...}` starting at [openBraceIndex], or -1.
int _agentBalancedJsonObjectEnd(String s, int openBraceIndex) {
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

String? _agentExtractFirstJsonObject(String input) {
  final start = input.indexOf('{');
  if (start < 0) {
    return null;
  }
  final end = _agentBalancedJsonObjectEnd(input, start);
  if (end <= start) {
    return null;
  }
  return input.substring(start, end);
}

/// Parses tool `argumentsRaw`; handles models that concatenate multiple JSON objects.
({Map<String, dynamic> map, String? warning})? _agentParseToolArgumentsRaw(String raw) {
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

  final first = _agentExtractFirstJsonObject(trimmed);
  if (first == null) {
    return null;
  }
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

class _AgentStreamingToolAgg {
  String id = '';
  String name = '';
  final StringBuffer argumentsRaw = StringBuffer();
}

AIChatMessage _agentBuildStreamedAiMessage({
  required String fullContent,
  required List<_AgentStreamingToolAgg> toolAggs,
}) {
  if (toolAggs.isEmpty) {
    return AIChatMessage(content: fullContent, toolCalls: const []);
  }

  final warnings = <String>[];
  final builtCalls = <AIChatMessageToolCall>[];
  for (var idx = 0; idx < toolAggs.length; idx++) {
    final a = toolAggs[idx];
    final raw = a.argumentsRaw.toString();
    final name = a.name;
    if (name.isEmpty && raw.trim().isEmpty) {
      continue;
    }
    if (name.isEmpty) {
      warnings.add(
        'A tool call was missing the function name. Raw arguments (truncated): '
        '${raw.length > 220 ? "${raw.substring(0, 220)}…" : raw}',
      );
      continue;
    }

    final parsed = _agentParseToolArgumentsRaw(raw);
    if (parsed == null) {
      warnings.add(
        'Could not parse JSON arguments for tool "$name". Use one tool call per turn with a single JSON object. '
        'Raw (truncated): ${raw.length > 400 ? "${raw.substring(0, 400)}…" : raw}',
      );
      logError('Agent tool parse failed for $name');
      continue;
    }
    if (parsed.warning != null) {
      log('Agent tool call: ${parsed.warning}');
      warnings.add(parsed.warning!);
    }

    final normalizedRaw = _agentExtractFirstJsonObject(raw.trim()) ?? raw.trim();
    builtCalls.add(
      AIChatMessageToolCall(
        id: a.id.isNotEmpty ? a.id : 'tool_${DateTime.now().millisecondsSinceEpoch}_$idx',
        name: name,
        argumentsRaw: normalizedRaw,
        arguments: parsed.map,
      ),
    );
  }

  final contentParts = <String>[];
  final trimmed = fullContent.trim();
  if (trimmed.isNotEmpty) {
    contentParts.add(trimmed);
  }
  if (warnings.isNotEmpty) {
    contentParts.add(warnings.join('\n'));
  }
  final textOut = contentParts.join('\n\n');

  return AIChatMessage(content: textOut, toolCalls: builtCalls);
}

/// Mixin for agent mode functionality
/// Provides autonomous task execution with planning and tool calling
mixin ChatProviderAgentMixin on ChangeNotifier, ChatProviderBaseMixin, ChatProviderImageGenerationMixin {
  // Members required from ChatProvider but not in base mixins
  void addBotHeader(FluentChatMessage message);

  // Stream subscription for cancellation support
  StreamSubscription<ChatResult>? get listenerResponseStream;
  set listenerResponseStream(StreamSubscription<ChatResult>? value);
  void showPlanningStatus() {
    addBotHeader(
      FluentChatMessage.header(
        id: 'planning',
        content: 'Planning next moves...',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        creator: selectedChatRoom.characterName,
      ),
    );
  }

  void removePlanningStatus() {
    removeMessage('planning');
  }

  /// Agent mode: AI plans and executes tasks autonomously
  Future<void> sendAgentMessage(String messageContent) async {
    // Show planning status
    showPlanningStatus();

    isAnswering = true;
    notifyListeners();

    try {
      await _executeAgentLoop(messageContent);
    } catch (e, stack) {
      logError('Error in agent mode: $e', stack);
      final time = DateTime.now().millisecondsSinceEpoch;
      addBotErrorMessageToList(
        FluentChatMessage.ai(
          id: time.toString(),
          content: 'Agent error: $e',
          creator: 'error',
          timestamp: time,
        ),
      );
    } finally {
      isAnswering = false;
      removePlanningStatus();
      removeFilesFromInput();
      await saveToDisk([selectedChatRoom]);
    }
  }

  /// One streamed model turn for the agent loop (shared by tool rounds and step-limit wrap-up).
  Future<
      ({
        AIChatMessage response,
        int responseTokens,
        int usagePromptTokens,
        int? timeToFirstTokenMs,
      })> _agentStreamAssistantTurn(
    List<ChatMessage> messages,
    ChatOpenAIOptions options,
    String messageId,
  ) async {
    String fullContent = '';
    final toolAggs = <_AgentStreamingToolAgg>[];
    var responseTokens = 0;
    var usagePromptTurn = 0;
    int? ttftMs;
    final turnStarted = DateTime.now();
    var hasDisplayedContent = false;
    var toolStreamingActive = false;

    final stream = openAI!.stream(PromptValue.chat(messages), options: options);
    final completer = Completer<AIChatMessage>();

    listenerResponseStream = stream.listen(
      (final chunk) {
        final message = chunk.output;

        // Apply usage first so each streamed row matches this chunk's totals.
        // Streaming often reports usage only on the last chunk; values may stay 0 until then.
        if (chunk.usage.totalTokens != null) {
          totalSentTokens += chunk.usage.promptTokens ?? 0;
          totalReceivedTokens += chunk.usage.responseTokens ?? 0;
          usagePromptTurn += chunk.usage.promptTokens ?? 0;
          responseTokens += chunk.usage.responseTokens ?? 0;
        }

        if (message.toolCalls.isNotEmpty) {
          toolStreamingActive = true;
          for (var i = 0; i < message.toolCalls.length; i++) {
            while (toolAggs.length <= i) {
              toolAggs.add(_AgentStreamingToolAgg());
            }
            final tc = message.toolCalls[i];
            final slot = toolAggs[i];
            if (tc.id.isNotEmpty) {
              slot.id = tc.id;
            }
            if (tc.name.isNotEmpty) {
              slot.name = tc.name;
            }
            slot.argumentsRaw.write(tc.argumentsRaw);
          }

          if (hasDisplayedContent && fullContent.isNotEmpty) {
            removeMessage(messageId);
            hasDisplayedContent = false;
          }
        }

        if (message.content.isNotEmpty) {
          fullContent += message.content;

          if (!toolStreamingActive) {
            hasDisplayedContent = true;
            ttftMs ??= DateTime.now().difference(turnStarted).inMilliseconds;
            addBotMessageToList(
              FluentChatMessage.ai(
                id: messageId,
                content: message.content,
                timestamp: DateTime.now().millisecondsSinceEpoch,
                tokens: responseTokens,
                creator: selectedChatRoom.characterName,
                usagePromptTokens: usagePromptTurn,
                usageCompletionTokens: responseTokens,
                timeToFirstTokenMs: ttftMs,
              ),
            );
          }
        }

        if (chunk.finishReason == FinishReason.stop || chunk.finishReason == FinishReason.toolCalls) {
          completer.complete(
            _agentBuildStreamedAiMessage(
              fullContent: fullContent,
              toolAggs: toolAggs,
            ),
          );
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(
            _agentBuildStreamedAiMessage(
              fullContent: fullContent,
              toolAggs: toolAggs,
            ),
          );
        }
      },
      onError: (e, stack) {
        logError('Error in stream: $e', stack);
        if (!completer.isCompleted) {
          completer.completeError(e, stack);
        }
      },
      cancelOnError: true,
    );

    final response = await completer.future;
    listenerResponseStream = null;
    return (
      response: response,
      responseTokens: responseTokens,
      usagePromptTokens: usagePromptTurn,
      timeToFirstTokenMs: ttftMs,
    );
  }

  /// Execute agent loop with planning and tool execution
  Future<void> _executeAgentLoop(String userRequest) async {
    const maxIterations = 10;
    int iteration = 0;

    // Stream subscription will be stored in listenerResponseStream (from ChatProvider)
    // so it can be cancelled via stopAnswering()
    final _agentSystemPromptWords = agentSystemPrompt.split('\n');
    StringBuffer sb = StringBuffer();
    for (final line in _agentSystemPromptWords) {
      if (line.startsWith('{')) {
        _writeValuesInSystemInfo(sb, line);
      } else {
        sb.writeln(line);
      }
    }

    // Prepare agent messages with custom system prompt and chat history
    final messagesToSend = <ChatMessage>[
      SystemChatMessage(content: sb.toString()),
    ];

    // Include recent chat history for context (excluding headers and system messages)
    final recentMessages = await getLastMessagesLimitToTokens(
      min(2048, selectedChatRoom.maxTokenLength), // Use minimum of 2048 tokens of history
      allowImages: true,
      stripMessage: false,
    );

    // Add recent messages (excluding headers, system messages, and shell proposals)
    // Note: The current user request is already in recentMessages since we added it in sendAgentMessage
    // shellExec is included so AI can see command results from previous interactions
    // shellProposal is excluded since they're just UI suggestions, not executed yet
    for (final msg in recentMessages) {
      if (msg.type != FluentChatMessageType.header &&
          msg.type != FluentChatMessageType.executionHeader &&
          msg.type != FluentChatMessageType.system &&
          msg.type != FluentChatMessageType.shellProposal) {
        messagesToSend.add(
          msg.toLangChainChatMessage(shouldCleanReasoning: selectedModel.reasoningSupported),
        );
      }
    }

    // Define agent-specific tools
    final agentTools = [
      const ToolSpec(
        name: 'read_file_tool',
        description:
            'Read a slice of a text file by line range. Prefer offset+limit on large files; omitting both caps output (~500 lines) to save tokens',
        inputJsonSchema: readFileToolParameters,
      ),
      const ToolSpec(
        name: 'list_directory_tool',
        description: 'List files and/or directories with optional glob filter, excludes, and recursive mode',
        inputJsonSchema: listDirectoryToolParameters,
      ),
      const ToolSpec(
        name: 'search_files_tool',
        description: 'Find files by filename pattern (wildcards * and ?) under a directory',
        inputJsonSchema: searchFilesToolParameters,
      ),
      const ToolSpec(
        name: 'grep_tool',
        description:
            'Search file contents by regex (fast via ripgrep when installed; otherwise scans files). Use after search_files_tool or to locate symbols before read_file_tool',
        inputJsonSchema: grepToolParameters,
      ),
      const ToolSpec(
        name: 'edit_file_tool',
        description:
            'Replace exactly one occurrence of old_string with new_string in an existing file. Prefer this over write_file_tool for small edits',
        inputJsonSchema: editFileToolParameters,
      ),
      const ToolSpec(
        name: 'write_file_tool',
        description:
            'Write or append full file content. Use for new files or full rewrites; prefer edit_file_tool for targeted edits',
        inputJsonSchema: writeFileToolParameters,
      ),
      const ToolSpec(
        name: 'execute_shell_command_tool',
        description: 'Execute a shell/terminal command and return the output',
        inputJsonSchema: executeShellCommandToolParameters,
      ),
      // new tools
      if (AppCache.gptToolCopyToClipboardEnabled.value!)
        const ToolSpec(
          name: 'copy_to_clipboard_tool',
          description: 'Tool to copy text to user clipboard',
          inputJsonSchema: copyToClipboardFunctionParameters,
        ),
      if (AppCache.gptToolAutoOpenUrls.value!)
        const ToolSpec(
          name: 'auto_open_urls_tool',
          description: 'Tool to open urls in the browser',
          inputJsonSchema: autoOpenUrlParameters,
        ),
      if (AppCache.gptToolGenerateImage.value!)
        const ToolSpec(
          name: 'generate_image_tool',
          description:
              'Tool to generate image. Use it to generate images based on a prompt. Requires API key in settings',
          inputJsonSchema: generateImageParameters,
        ),
      if (AppCache.gptToolRememberInfo.value!)
        const ToolSpec(
          name: 'remember_info_tool',
          description: 'Tool to remember info. Use it to store info about user or important notes',
          inputJsonSchema: rememberInfoParameters,
        ),
    ];

    initModelsApi();

    while (iteration < maxIterations && isAnswering) {
      iteration++;

      final options = ChatOpenAIOptions(
        model: selectedChatRoom.model.modelName,
        temperature: 0.7,
        toolChoice: const ChatToolChoiceAuto(),
        tools: agentTools,
        parallelToolCalls: false,
      );

      try {
        final messageId = '${DateTime.now().millisecondsSinceEpoch}_agent';
        final streamResult = await _agentStreamAssistantTurn(messagesToSend, options, messageId);
        final response = streamResult.response;
        var responseTokens = streamResult.responseTokens;
        final usagePromptFromStream = streamResult.usagePromptTokens;
        final ttftFromStream = streamResult.timeToFirstTokenMs;

        // Check if user cancelled
        if (!isAnswering) {
          log('Agent cancelled by user');
          notifyListeners();
          break;
        }

        // Count tool call tokens if present
        int toolTokens = 0;
        if (response.toolCalls.isNotEmpty) {
          for (final toolCall in response.toolCalls) {
            toolTokens += await countTokensString(toolCall.name);
            toolTokens += await countTokensString(jsonEncode(toolCall.arguments));
          }
          totalReceivedTokens += toolTokens;
          responseTokens += toolTokens;
        }

        // If API didn't provide tokens, calculate them locally
        if (responseTokens == 0 && response.content.isNotEmpty) {
          responseTokens = await countTokensString(response.content);
          totalReceivedTokens += responseTokens;
        }

        // Note: Token count is accumulated during streaming via addBotMessageToList
        // Each chunk adds its tokens, so the final message already has the total

        if (kDebugMode) {
          log(
            'Agent iteration $iteration: content: "${response.content}" toolCalls: ${response.toolCalls.length} contentTokens: ${responseTokens - toolTokens} toolsTokens: $toolTokens totalTokens: $responseTokens',
          );
        }

        // Add AI response to conversation history
        messagesToSend.add(response);

        // Check for tool calls
        if (response.toolCalls.isEmpty) {
          // No more tool calls, agent is done
          log('Agent iteration $iteration: No more tool calls, ✅ Task completed');
          // update the message with the end received tokens
          editMessage(
              messageId,
              FluentChatMessage.ai(
                id: messageId,
                content: response.content,
                tokens: responseTokens,
                timestamp: DateTime.now().millisecondsSinceEpoch,
                creator: selectedChatRoom.characterName,
                usagePromptTokens: usagePromptFromStream,
                usageCompletionTokens: responseTokens,
                timeToFirstTokenMs: ttftFromStream,
              ));
          break;
        }

        // Execute tool calls
        for (final toolCall in response.toolCalls) {
          // Check if user cancelled during tool execution
          if (!isAnswering) {
            log('Agent cancelled by user during tool execution');
            notifyListeners();
            break;
          }

          final toolName = toolCall.name;
          final toolArgs = toolCall.arguments;
          if (kDebugMode) {
            log('toolCall: $toolName, args: $toolArgs\n\n');
          }

          // Get key parameter for display (path, directory, or pattern)
          String? keyParam;
          if (toolName == 'grep_tool') {
            keyParam = '${toolArgs['pattern'] ?? ''} @ ${toolArgs['path'] ?? '.'}';
          } else if (toolName == 'search_files_tool') {
            keyParam = '${toolArgs['pattern']} in ${toolArgs['directory'] ?? '.'}';
          } else if (toolArgs.containsKey('path')) {
            keyParam = toolArgs['path']?.toString();
          } else if (toolArgs.containsKey('url')) {
            keyParam = toolArgs['url']?.toString();
          } else if (toolArgs.containsKey('directory')) {
            keyParam = toolArgs['directory']?.toString();
          } else if (toolArgs.containsKey('clipboard')) {
            keyParam = toolArgs['clipboard']?.toString();
          }

          // Show tool execution status with parameter
          final executingMessage = keyParam != null ? '⚙️ Executing: $toolName "$keyParam"' : '⚙️ Executing: $toolName';

          final execTimestamp = DateTime.now().millisecondsSinceEpoch;
          final execId = '${DateTime.now().microsecondsSinceEpoch}_exec';
          final argsJson = jsonEncode(toolArgs);

          addBotHeader(
            FluentChatMessage.executionHeader(
              id: execId,
              content: executingMessage,
              timestamp: execTimestamp,
              creator: selectedChatRoom.characterName,
              agentToolName: toolName,
              agentToolArgumentsJson: argsJson,
            ),
          );
          notifyListeners();

          // Execute the tool
          final toolResult = await _executeAgentTool(toolName, toolArgs);

          // Add tool result to conversation
          messagesToSend.add(
            ToolChatMessage(
              content: toolResult,
              toolCallId: toolCall.id,
            ),
          );

          // Single execution row: replace "Executing" with final status (no duplicate Completed line).
          final isError = toolResult.startsWith('Error:');
          final statusIcon = isError ? '❌' : '✓';
          final statusText = isError ? 'Failed' : 'Completed';
          final doneMessage = keyParam != null
              ? '$statusIcon $statusText: $toolName "$keyParam"'
              : '$statusIcon $statusText: $toolName';

          await editMessage(
            execId,
            FluentChatMessage.executionHeader(
              id: execId,
              content: doneMessage,
              timestamp: execTimestamp,
              creator: selectedChatRoom.characterName,
              agentToolName: toolName,
              agentToolArgumentsJson: argsJson,
              agentToolResult: toolResult,
            ),
          );

          notifyListeners();
        }
      } catch (e) {
        // Clean up listener on error
        listenerResponseStream = null;

        // If it's a cancellation, don't throw
        if (!isAnswering) {
          log('Agent cancelled by user (caught in error handler)');
          notifyListeners();
          break;
        }

        logError('Error in agent loop iteration $iteration: $e');
        rethrow;
      }
    }

    // Clean up
    listenerResponseStream = null;

    final hitStepLimit = iteration >= maxIterations;
    final needsStepLimitWrapUp = hitStepLimit &&
        isAnswering &&
        messagesToSend.isNotEmpty &&
        messagesToSend.last is ToolChatMessage;

    if (needsStepLimitWrapUp) {
      messagesToSend.add(
        HumanChatMessage(
          content: ChatMessageContent.text(
            'System notice: The agent reached its maximum number of tool rounds for this run. '
            'You must not use tools for this reply (tools are disabled). '
            'Based on the user request and every message and tool result above, write a concise, helpful final answer: '
            'summarize what you accomplished and what you found; note what is still unknown, unfinished, or risky; '
            'tell the user they can send another message if they want you to continue exploring or finish the task.',
          ),
        ),
      );

      addBotHeader(
        FluentChatMessage.executionHeader(
          id: '${DateTime.now().millisecondsSinceEpoch}_wrapup',
          content: '⚙️ Wrapping up (step limit reached)',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          creator: selectedChatRoom.characterName,
        ),
      );
      notifyListeners();

      final wrapUpMessageId = '${DateTime.now().millisecondsSinceEpoch}_agent_wrapup';
      final wrapUpOptions = ChatOpenAIOptions(
        model: selectedChatRoom.model.modelName,
        temperature: 0.7,
        toolChoice: const ChatToolChoiceNone(),
      );

      try {
        final streamResult = await _agentStreamAssistantTurn(
          messagesToSend,
          wrapUpOptions,
          wrapUpMessageId,
        );
        var wrapResponse = streamResult.response;
        var wrapResponseTokens = streamResult.responseTokens;

        if (!isAnswering) {
          notifyListeners();
        } else {
          if (wrapResponse.toolCalls.isNotEmpty) {
            log(
              'Agent step-limit wrap-up returned ${wrapResponse.toolCalls.length} tool call(s); using text only',
            );
            wrapResponse = AIChatMessage(content: wrapResponse.content, toolCalls: const []);
          }

          if (wrapResponseTokens == 0 && wrapResponse.content.isNotEmpty) {
            wrapResponseTokens = await countTokensString(wrapResponse.content);
            totalReceivedTokens += wrapResponseTokens;
          }

          await editMessage(
            wrapUpMessageId,
            FluentChatMessage.ai(
              id: wrapUpMessageId,
              content: wrapResponse.content,
              tokens: wrapResponseTokens,
              timestamp: DateTime.now().millisecondsSinceEpoch,
              creator: selectedChatRoom.characterName,
              usagePromptTokens: streamResult.usagePromptTokens,
              usageCompletionTokens: wrapResponseTokens,
              timeToFirstTokenMs: streamResult.timeToFirstTokenMs,
            ),
          );
        }
      } catch (e, stack) {
        listenerResponseStream = null;
        if (!isAnswering) {
          notifyListeners();
        } else {
          logError('Error in agent step-limit wrap-up: $e', stack);
          final time = DateTime.now().millisecondsSinceEpoch;
          addBotErrorMessageToList(
            FluentChatMessage.ai(
              id: '${time}_wrapup_err',
              content:
                  'Reached the agent step limit but could not generate a closing summary: $e',
              creator: 'error',
              timestamp: time,
            ),
          );
          addBotHeader(
            FluentChatMessage.executionHeader(
              id: '${time}_maxiter',
              content: '⚠️ Reached maximum iterations (wrap-up failed)',
              timestamp: time,
              creator: selectedChatRoom.characterName,
            ),
          );
        }
      }
    }
  }

  /// Execute a single agent tool and return the result for AI to use it in the next iteration
  Future<String> _executeAgentTool(String toolName, Map<String, dynamic> args) async {
    log('Executing tool: $toolName, args: $args');
    try {
      switch (toolName) {
        case 'read_file_tool':
          return await _handleReadFileTool(args);
        case 'list_directory_tool':
          return await _handleListDirectoryTool(args);
        case 'search_files_tool':
          return await _handleSearchFilesTool(args);
        case 'grep_tool':
          return await _handleGrepTool(args);
        case 'edit_file_tool':
          return await _handleEditFileTool(args);
        case 'write_file_tool':
          return await _handleWriteFileTool(args);
        case 'execute_shell_command_tool':
          return await _handleExecuteShellCommandTool(args);
        case 'copy_to_clipboard_tool':
          return await _handleCopyToClipboardTool(args);
        case 'auto_open_urls_tool':
          return await _handleAutoOpenUrlsTool(args);
        case 'generate_image_tool':
          return await _handleGenerateImageTool(args);
        case 'remember_info_tool':
          return await _handleRememberInfoTool(args);
        default:
          return 'Error: Unknown tool $toolName';
      }
    } catch (e) {
      logError('Error executing tool $toolName: $e');
      return 'Error: $e';
    }
  }

  Future<String> _handleReadFileTool(Map<String, dynamic> args) async {
    try {
      final path = args['path'];
      if (path is! String || path.isEmpty) {
        return 'Error: path must be a non-empty string';
      }

      final file = File(path);
      if (!await file.exists()) {
        return 'Error: File not found at $path';
      }
      if (FileSystemEntity.typeSync(path) != FileSystemEntityType.file) {
        return 'Error: Not a file: $path';
      }

      final contents = await file.readAsString();
      final lines = const LineSplitter().convert(contents);
      final totalLines = lines.length;
      if (totalLines == 0) {
        return 'File: $path\nTotal lines: 0\n\n(empty file)';
      }

      int? offset = (args['offset'] as num?)?.toInt();
      int? limit = (args['limit'] as num?)?.toInt();

      if (limit != null && limit <= 0) {
        return 'Error: limit must be positive';
      }

      var startIdx = 0;
      if (offset != null) {
        if (offset == 0) {
          return 'Error: offset uses 1-based line numbers (use 1 for first line, or -1 for last line)';
        }
        if (offset < 0) {
          startIdx = totalLines + offset;
          if (startIdx < 0) {
            startIdx = 0;
          }
        } else {
          startIdx = offset - 1;
        }
      }

      if (startIdx < 0) {
        startIdx = 0;
      }
      if (startIdx >= totalLines) {
        return 'File: $path\nTotal lines: $totalLines\n\nError: offset is past end of file';
      }

      final remaining = totalLines - startIdx;
      final int effectiveLimit;
      var truncatedByDefault = false;
      if (limit != null) {
        effectiveLimit = min(min(limit, _agentReadAbsoluteLineCap), remaining);
      } else {
        if (remaining > _agentReadDefaultLineCap) {
          effectiveLimit = _agentReadDefaultLineCap;
          truncatedByDefault = true;
        } else {
          effectiveLimit = remaining;
        }
      }

      final endIdx = startIdx + effectiveLimit;
      final selected = lines.sublist(startIdx, endIdx);
      final buf = StringBuffer();
      buf.writeln('File: $path');
      buf.writeln('Total lines: $totalLines');
      buf.writeln('Showing lines ${startIdx + 1}-$endIdx');
      if (truncatedByDefault) {
        buf.writeln(
          '(Output capped at $_agentReadDefaultLineCap lines; pass offset and limit to read more)',
        );
      } else if (endIdx < totalLines) {
        buf.writeln('(More lines exist; use offset: ${endIdx + 1} to continue)');
      }
      buf.writeln();
      for (var i = 0; i < selected.length; i++) {
        buf.writeln('${startIdx + i + 1}|${selected[i]}');
      }

      return buf.toString();
    } catch (e) {
      return 'Error reading file: $e';
    }
  }

  Future<String> _handleListDirectoryTool(Map<String, dynamic> args) async {
    try {
      final path = args['path'];
      if (path is! String || path.isEmpty) {
        return 'Error: path must be a non-empty string';
      }

      final recursive = args['recursive'] as bool? ?? false;
      final globPattern = args['glob'] as String?;
      final entriesMode = args['entries'] as String? ?? 'all';
      final skipCommon = (args['skipCommonIgnored'] ?? args['skip_common_ignored']) as bool? ?? true;
      final userExclude = args['exclude'] as List<dynamic>?;

      final exclude = _mergeExcludeNames(userExclude, skipCommon);
      RegExp? globRe;
      if (globPattern != null && globPattern.isNotEmpty) {
        globRe = _agentGlobToRegExp(globPattern);
      }

      final dir = Directory(path);
      if (!await dir.exists()) {
        return 'Error: Directory not found at $path';
      }

      final files = <String>[];
      final directories = <String>[];

      void considerEntity(FileSystemEntity entity) {
        if (_pathHasExcludedSegment(entity.path, exclude)) {
          return;
        }
        if (entity is File) {
          if (entriesMode == 'directories') {
            return;
          }
          final name = _agentBasename(entity.path);
          if (globRe != null && !globRe.hasMatch(name)) {
            return;
          }
          files.add(entity.path);
        } else if (entity is Directory) {
          if (entriesMode == 'files') {
            return;
          }
          if (globRe != null) {
            return;
          }
          directories.add(entity.path);
        }
      }

      if (recursive) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          considerEntity(entity);
        }
      } else {
        await for (final entity in dir.list(recursive: false, followLinks: false)) {
          if (_pathHasExcludedSegment(entity.path, exclude)) {
            continue;
          }
          if (entity is File) {
            if (entriesMode == 'directories') {
              continue;
            }
            final name = _agentBasename(entity.path);
            if (globRe != null && !globRe.hasMatch(name)) {
              continue;
            }
            files.add(entity.path);
          } else if (entity is Directory) {
            if (entriesMode == 'files') {
              continue;
            }
            if (globRe != null) {
              continue;
            }
            directories.add(entity.path);
          }
        }
      }

      files.sort();
      directories.sort();

      final buffer = StringBuffer();
      buffer.writeln('Directory: $path');
      if (globRe != null) {
        buffer.writeln('Glob filter: $globPattern');
      }
      buffer.writeln('entries=$entriesMode recursive=$recursive');
      buffer.writeln('Directories (${directories.length}):');
      for (final d in directories.take(50)) {
        buffer.writeln('  📁 $d');
      }
      if (directories.length > 50) {
        buffer.writeln('  ... and ${directories.length - 50} more directories');
      }

      buffer.writeln('\nFiles (${files.length}):');
      for (final f in files.take(100)) {
        buffer.writeln('  📄 $f');
      }
      if (files.length > 100) {
        buffer.writeln('  ... and ${files.length - 100} more files');
      }

      return buffer.toString();
    } catch (e) {
      return 'Error listing directory: $e';
    }
  }

  Future<String> _handleSearchFilesTool(Map<String, dynamic> args) async {
    try {
      final pattern = args['pattern'];
      final directory = args['directory'];
      if (pattern is! String || pattern.isEmpty) {
        return 'Error: pattern must be a non-empty string';
      }
      if (directory is! String || directory.isEmpty) {
        return 'Error: directory must be a non-empty string';
      }

      final maxResults = (args['maxResults'] as num?)?.toInt() ?? 50;
      final skipCommon = (args['skipCommonIgnored'] ?? args['skip_common_ignored']) as bool? ?? true;
      final exclude = _mergeExcludeNames(null, skipCommon);

      final dir = Directory(directory);
      if (!await dir.exists()) {
        return 'Error: Directory not found at $directory';
      }

      final matches = <String>[];
      final regExp = _agentGlobToRegExp(pattern);

      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (_pathHasExcludedSegment(entity.path, exclude)) {
          continue;
        }
        if (entity is File) {
          final fileName = _agentBasename(entity.path);
          if (regExp.hasMatch(fileName)) {
            matches.add(entity.path);
            if (matches.length >= maxResults) {
              break;
            }
          }
        }
      }

      if (matches.isEmpty) {
        return 'No files found matching pattern "$pattern" in $directory';
      }

      final buffer = StringBuffer();
      buffer.writeln('Found ${matches.length} file(s) matching "$pattern":');
      for (final match in matches) {
        buffer.writeln('  📄 $match');
      }

      return buffer.toString();
    } catch (e) {
      return 'Error searching files: $e';
    }
  }

  Future<String> _handleGrepTool(Map<String, dynamic> args) async {
    try {
      final pattern = args['pattern'];
      if (pattern is! String || pattern.isEmpty) {
        return 'Error: pattern must be a non-empty string';
      }

      final searchPath = (args['path'] as String?) ?? '.';
      final glob = args['glob'] as String?;
      final maxResults = ((args['max_results'] ?? args['maxResults']) as num?)?.toInt() ?? 80;
      final contextLines = max(
        0,
        ((args['context_lines'] ?? args['contextLines']) as num?)?.toInt() ?? 2,
      );
      final caseSensitive = (args['case_sensitive'] ?? args['caseSensitive']) as bool? ?? true;
      final skipCommon = (args['skipCommonIgnored'] ?? args['skip_common_ignored']) as bool? ?? true;

      final type = FileSystemEntity.typeSync(searchPath);
      if (type == FileSystemEntityType.notFound) {
        return 'Error: Path not found: $searchPath';
      }

      final rgArgs = <String>[
        '--line-number',
        '--max-columns',
        '800',
        '--max-filesize',
        '2M',
        if (!caseSensitive) '--ignore-case',
        if (contextLines > 0) ...['-C', '$contextLines'],
        if (glob != null && glob.isNotEmpty) ...['--glob', glob],
        pattern,
        searchPath,
      ];

      try {
        final r = await Process.run(
          'rg',
          rgArgs,
          runInShell: false,
          environment: Platform.environment,
        );

        if (r.exitCode == 127) {
          return _grepToolDartFallback(
            pattern: pattern,
            searchPath: searchPath,
            glob: glob,
            maxResults: maxResults,
            caseSensitive: caseSensitive,
            skipCommon: skipCommon,
          );
        }

        if (r.exitCode == 2) {
          final err = (r.stderr as String).trim();
          if (err.isNotEmpty) {
            return 'Error (ripgrep): $err';
          }
        }

        final out = (r.stdout as String).trimRight();
        if (out.isEmpty) {
          return 'No matches found for pattern in $searchPath';
        }

        return _truncateGrepToolOutput(out, maxResults);
      } on ProcessException catch (_) {
        // Ripgrep not installed or not on PATH
      }

      return _grepToolDartFallback(
        pattern: pattern,
        searchPath: searchPath,
        glob: glob,
        maxResults: maxResults,
        caseSensitive: caseSensitive,
        skipCommon: skipCommon,
      );
    } catch (e) {
      return 'Error in grep_tool: $e';
    }
  }

  Future<String> _handleEditFileTool(Map<String, dynamic> args) async {
    try {
      final path = args['path'];
      final oldString = args['old_string'] ?? args['oldString'];
      final newString = args['new_string'] ?? args['newString'];
      if (path is! String || path.isEmpty) {
        return 'Error: path must be a non-empty string';
      }
      if (oldString is! String) {
        return 'Error: old_string is required';
      }
      if (newString is! String) {
        return 'Error: new_string is required';
      }
      if (oldString.isEmpty) {
        return 'Error: old_string must not be empty (use write_file_tool to create a new file)';
      }

      final file = File(path);
      if (!await file.exists()) {
        return 'Error: File not found at $path';
      }
      if (FileSystemEntity.typeSync(path) != FileSystemEntityType.file) {
        return 'Error: Not a file: $path';
      }

      final contents = await file.readAsString();
      final occurrences = _countNonOverlapping(contents, oldString);
      if (occurrences == 0) {
        return 'Error: old_string not found in file (check exact whitespace and line endings)';
      }
      if (occurrences > 1) {
        return 'Error: old_string is not unique (found $occurrences times); include more surrounding context in old_string';
      }

      final updated = contents.replaceFirst(oldString, newString);
      await file.writeAsString(updated);
      return 'Successfully edited $path (single replacement applied)';
    } catch (e) {
      return 'Error editing file: $e';
    }
  }

  Future<String> _handleWriteFileTool(Map<String, dynamic> args) async {
    try {
      final path = args['path'];
      final content = args['content'];
      if (path is! String || path.isEmpty) {
        return 'Error: path must be a non-empty string';
      }
      if (content is! String) {
        return 'Error: content is required';
      }

      final append = args['append'] as bool? ?? false;
      final file = File(path);

      await file.parent.create(recursive: true);

      if (append) {
        await file.writeAsString(content, mode: FileMode.append);
        return 'Successfully appended to file: $path';
      } else {
        await file.writeAsString(content);
        return 'Successfully wrote to file: $path';
      }
    } catch (e) {
      return 'Error writing file: $e';
    }
  }

  Set<String> _mergeExcludeNames(List<dynamic>? userExclude, bool skipCommon) {
    final out = <String>{};
    if (skipCommon) {
      out.addAll(_commonIgnoredDirNames);
    }
    if (userExclude != null) {
      for (final e in userExclude) {
        if (e is String && e.isNotEmpty) {
          out.add(e);
        }
      }
    }
    return out;
  }

  bool _pathHasExcludedSegment(String path, Set<String> exclude) {
    if (exclude.isEmpty) {
      return false;
    }
    for (final part in path.replaceAll('\\', '/').split('/')) {
      if (part.isEmpty) {
        continue;
      }
      if (exclude.contains(part)) {
        return true;
      }
    }
    return false;
  }

  String _agentBasename(String path) {
    final n = path.replaceAll('\\', '/');
    final i = n.lastIndexOf('/');
    return i < 0 ? n : n.substring(i + 1);
  }

  RegExp _agentGlobToRegExp(String pattern) {
    final sb = StringBuffer('^');
    for (var i = 0; i < pattern.length; i++) {
      final c = pattern[i];
      if (c == '*') {
        sb.write('.*');
      } else if (c == '?') {
        sb.write('.');
      } else {
        sb.write(RegExp.escape(c));
      }
    }
    sb.write(r'$');
    return RegExp(sb.toString(), caseSensitive: false);
  }

  int _countNonOverlapping(String haystack, String needle) {
    if (needle.isEmpty) {
      return 0;
    }
    var count = 0;
    var start = 0;
    while (true) {
      final i = haystack.indexOf(needle, start);
      if (i < 0) {
        break;
      }
      count++;
      start = i + needle.length;
    }
    return count;
  }

  String _truncateGrepToolOutput(String stdout, int maxResultLines) {
    var maxLines = max(maxResultLines, 20);
    maxLines = min(maxLines, 500);
    final lines = stdout.split('\n');
    var text = stdout;
    if (lines.length > maxLines) {
      text = '${lines.take(maxLines).join('\n')}\n... (${lines.length - maxLines} lines omitted; refine pattern, path, or glob)';
    }
    if (text.length <= _grepToolMaxOutputChars) {
      return text;
    }
    return '${text.substring(0, _grepToolMaxOutputChars)}\n... (output truncated by size)';
  }

  Future<String> _grepToolDartFallback({
    required String pattern,
    required String searchPath,
    required String? glob,
    required int maxResults,
    required bool caseSensitive,
    required bool skipCommon,
  }) async {
    RegExp re;
    try {
      re = RegExp(pattern, caseSensitive: caseSensitive);
    } catch (e) {
      return 'Error: invalid regular expression: $e';
    }

    final exclude = _mergeExcludeNames(null, skipCommon);
    final globRe = glob != null && glob.isNotEmpty ? _agentGlobToRegExp(glob) : null;

    final results = <String>[];
    final maxLinesOut = max(maxResults, 20).clamp(20, 500);

    Future<void> scanFile(File file) async {
      if (results.length >= maxLinesOut) {
        return;
      }
      try {
        final len = await file.length();
        if (len > _dartGrepMaxBytesPerFile) {
          return;
        }
        final raw = await file.readAsBytes();
        if (raw.contains(0)) {
          return;
        }
        final text = utf8.decode(raw, allowMalformed: true);
        final lines = const LineSplitter().convert(text);
        for (var i = 0; i < lines.length; i++) {
          if (re.hasMatch(lines[i])) {
            results.add('${file.path}:${i + 1}:${lines[i]}');
            if (results.length >= maxLinesOut) {
              return;
            }
          }
        }
      } catch (_) {}
    }

    final rootType = FileSystemEntity.typeSync(searchPath);
    if (rootType == FileSystemEntityType.file) {
      final f = File(searchPath);
      if (globRe != null && !globRe.hasMatch(_agentBasename(f.path))) {
        return 'No matches (file path did not match glob)';
      }
      await scanFile(f);
    } else if (rootType == FileSystemEntityType.directory) {
      await for (final entity in Directory(searchPath).list(recursive: true, followLinks: false)) {
        if (results.length >= maxLinesOut) {
          break;
        }
        if (_pathHasExcludedSegment(entity.path, exclude)) {
          continue;
        }
        if (entity is! File) {
          continue;
        }
        final name = _agentBasename(entity.path);
        if (globRe != null && !globRe.hasMatch(name)) {
          continue;
        }
        await scanFile(entity);
      }
    } else {
      return 'Error: Not a file or directory: $searchPath';
    }

    if (results.isEmpty) {
      return 'No matches found (Dart scan; install ripgrep for faster search)';
    }

    return results.join('\n');
  }

  Future<String> _handleExecuteShellCommandTool(Map<String, dynamic> args) async {
    try {
      final String command = args['command'];
      final String? workingDirectory = args['workingDirectory'];

      // Safety: Block dangerous commands
      final lowerCommand = command.toLowerCase();
      final dangerousPatterns = [
        'rm -rf /',
        'del /f /s /q c:\\',
        'format',
        'mkfs',
        ':(){:|:&};:', // fork bomb
      ];

      for (final pattern in dangerousPatterns) {
        if (lowerCommand.contains(pattern)) {
          return 'Error: Dangerous command blocked for safety: $command';
        }
      }

      var shell = Shell();
      if (workingDirectory != null && workingDirectory.isNotEmpty) {
        shell.navigate(workingDirectory);
      }

      // Parse command and arguments
      final parts = _parseCommand(command);
      if (parts.isEmpty) {
        return 'Error: Empty command';
      }

      final commandName = parts.first;
      final commandArgs = parts.length > 1 ? parts.sublist(1) : <String>[];

      String stdout = '';
      String stderr = '';
      int exitCode = 0;

      try {
        // Execute with timeout
        final process = await shell.start(commandName, arguments: commandArgs).timeout(const Duration(seconds: 30));

        stdout = await process.stdout.readAsString();
        stderr = await process.stderr.readAsString();
        exitCode = await process.exitCode;

        // Limit output size (max 10KB)
        if (stdout.length > 10240) {
          stdout = '${stdout.substring(0, 10240)}\n... (output truncated)';
        }
        if (stderr.length > 10240) {
          stderr = '${stderr.substring(0, 10240)}\n... (output truncated)';
        }
      } on TimeoutException {
        return 'Error: Command timed out after 30 seconds';
      } catch (e) {
        return 'Error executing command: $e';
      }

      // Create shell execution message for UI
      final time = DateTime.now().millisecondsSinceEpoch;
      final shellMessage = FluentChatMessage.shellExec(
        id: '${time}_shell',
        command: command,
        exitCode: exitCode,
        stdout: stdout,
        stderr: stderr,
        timestamp: time,
      );

      // Add to chat
      addCustomMessageToList(shellMessage);

      // Return summary for AI
      final summary = StringBuffer();
      summary.writeln('Command: $command');
      summary.writeln('Exit code: $exitCode');

      if (stdout.isNotEmpty) {
        summary.writeln('Output:');
        summary.writeln(stdout.length > 500 ? '${stdout.substring(0, 500)}...' : stdout);
      } else {
        summary.writeln('Output: (empty)');
      }

      if (stderr.isNotEmpty) {
        summary.writeln('Errors:');
        summary.writeln(stderr.length > 500 ? '${stderr.substring(0, 500)}...' : stderr);
      }

      return summary.toString();
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Parse command string into command and arguments
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

  Future<String> _handleCopyToClipboardTool(Map<String, dynamic> args) async {
    // final text = args['responseMessage'];
    final textToCopy = args['clipboard'];
    await Clipboard.setData(ClipboardData(text: textToCopy));
    displayCopiedToClipboard();
    return 'Successfully copied to clipboard: $textToCopy';
  }

  Future<String> _handleAutoOpenUrlsTool(Map<String, dynamic> args) async {
    final url = args['url'];
    // final text = args['responseMessage'] as String?;
    // we already post agent message in tool use
    // final appendedText = text + '\n```func\n$url\n```';
    // if (text?.isNotEmpty == true) {
    //   final time = DateTime.now().millisecondsSinceEpoch;
    //   final tokens = await countTokensString(text!);
    //   addBotMessageToList(
    //     FluentChatMessage.ai(
    //       id: time.toString(),
    //       content: text,
    //       timestamp: time,
    //       creator: selectedChatRoom.characterName,
    //       tokens: tokens,
    //     ),
    //   );
    //   // User need time to read XD
    //   await Future.delayed(const Duration(milliseconds: 1200));
    // }

    if (await canLaunchUrlString(url)) {
      final res = await launchUrlString(url);
      if (res) {
        return 'Successfully opened url: $url';
      }
    }
    return 'Was not able to open url: $url';
  }

  Future<String> _handleGenerateImageTool(Map<String, dynamic> args) async {
    final prompt = args['prompt'];
    final size = args['size'];
    // final responseMessage = args['responseMessage'];
    // final time = DateTime.now().millisecondsSinceEpoch;
    // final funcText = '```generate_image\n$prompt\n```';
    return generateImageFromTool(prompt: prompt, size: size);
  }

  Future<String> _handleRememberInfoTool(Map<String, dynamic> args) async {
    final info = args['info'];
    final responseMessage = args['responseMessage'];
    final time = DateTime.now().millisecondsSinceEpoch;
    final funcText = '```remember\n$info\n```';
    AppCache.userInfo.saveInfoToFile(info);

    addBotMessageToList(
      FluentChatMessage.ai(
        id: time.toString(),
        content: '$funcText\n$responseMessage',
        timestamp: time,
        creator: selectedChatRoom.characterName,
        tokens: await countTokensString('$funcText\n$responseMessage'),
      ),
    );
    return 'Successfully remembered info: $info';
  }

  void _writeValuesInSystemInfo(StringBuffer sb, String line) {
    switch (line) {
      case '{system_info}':
        sb.writeln('System info: ${getSystemInfoString()}');
        break;
      case '{user_info}':
        sb.writeln(
            '''Background context about the user (DO NOT mention or reference this information unprompted - only use when directly relevant to the user's request): """$infoAboutUser"""''');
        break;
      case '{lang}':
        sb.writeln('Preferable language: ${I18n.currentLocale.languageCode}');
        break;
      case '{conversation_lenght}':
        if (conversationLenghtStyleStream.value != ConversationLengthStyleEnum.normal) {
          sb.writeln('Your answer length should be: ${conversationLenghtStyleStream.value.name}');
        }
        break;
      case '{conversation_style}':
        if (conversationStyleStream.value != ConversationStyleEnum.normal) {
          sb.writeln('YOU SHOULD ANSWER VERY: ${conversationStyleStream.value.name}');
        }
        break;
    }
  }
}
