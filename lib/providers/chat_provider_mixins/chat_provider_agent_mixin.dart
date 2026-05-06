import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fluent_gpt/common/agent_mode_enum.dart';
import 'package:fluent_gpt/common/conversaton_style_enum.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/tools/tool_def.dart';
import 'package:fluent_gpt/common/tools/tool_registry.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_image_generation_mixin.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';

AIChatMessage _agentBuildStreamedAiMessage({
  required String fullContent,
  required List<ToolStreamAgg> toolAggs,
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

    final parsed = parseToolArgumentsRaw(raw);
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

    final normalizedRaw = extractFirstJsonObject(raw.trim()) ?? raw.trim();
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
    final toolAggs = <ToolStreamAgg>[];
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
              toolAggs.add(ToolStreamAgg());
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

    // Pull tool list from the central registry, filtered to agent mode and
    // the user's per-tool enable flags.
    final agentTools = toolsForMode(AgentMode.agent).map((t) => t.toSpec()).toList();

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
    final tool = toolByName(toolName);
    if (tool == null || !tool.isAvailableIn(AgentMode.agent) || tool.agentExecute == null) {
      return 'Error: Tool "$toolName" is not allowed in agent mode';
    }
    try {
      return await tool.agentExecute!(this, args);
    } catch (e) {
      logError('Error executing tool $toolName: $e');
      return 'Error: $e';
    }
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
      case '{runtime_mode}':
        final mode = AgentModeUtils.fromValue(AppCache.agentMode.value);
        sb.writeln('Runtime mode: ${mode.runtimeName}');
        break;
    }
  }
}
