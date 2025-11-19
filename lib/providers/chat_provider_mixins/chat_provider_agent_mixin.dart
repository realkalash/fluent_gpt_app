import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/gpt_tools.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:shell/shell.dart';

/// Mixin for agent mode functionality
/// Provides autonomous task execution with planning and tool calling
mixin ChatProviderAgentMixin on ChangeNotifier, ChatProviderBaseMixin {
  // Members required from ChatProvider but not in base mixins
  void addBotHeader(FluentChatMessage message);

  // Stream subscription for cancellation support
  StreamSubscription<ChatResult>? get listenerResponseStream;
  set listenerResponseStream(StreamSubscription<ChatResult>? value);

  // Note: The following are already available through parent classes:
  // - initModelsApi() from ChatProviderBaseMixin
  // - isAnswering from ChatProvider
  // - totalSentTokens / totalReceivedTokens from ChatProviderTokensMixin
  // - messages from ChatProvider
  // - editMessage from ChatProvider
  // - deleteMessage from ChatProvider
  // - getLastMessagesLimitToTokens from ChatProviderMessageQueriesMixin
  // - getSystemInfoString from ChatProviderSystemInfoMixin

  /// Agent mode: AI plans and executes tasks autonomously
  Future<void> sendAgentMessage(String messageContent) async {
    // Add user message to chat
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await addHumanMessageToList(
      FluentChatMessage.humanText(
        id: '$timestamp',
        content: messageContent,
        creator: 'User',
        timestamp: timestamp,
      ),
    );

    // Show planning status
    addBotHeader(
      FluentChatMessage.header(
        id: '${timestamp}_planning',
        content: 'Planning next moves...',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        creator: selectedChatRoom.characterName,
      ),
    );

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
      notifyListeners();
      await saveToDisk([selectedChatRoom]);
    }
  }

  /// Execute agent loop with planning and tool execution
  Future<void> _executeAgentLoop(String userRequest) async {
    const maxIterations = 10;
    int iteration = 0;
    String systemInfo = getSystemInfoString();

    // Stream subscription will be stored in listenerResponseStream (from ChatProvider)
    // so it can be cancelled via stopAnswering()

    // Prepare agent messages with custom system prompt and chat history
    final messagesToSend = <ChatMessage>[
      SystemChatMessage(content: '$agentSystemPrompt\n\nSystem info: $systemInfo'),
    ];

    // Include recent chat history for context (excluding headers and system messages)
    final recentMessages = await getLastMessagesLimitToTokens(
      8196, // Use 8196 tokens of history
      allowImages: false,
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
      ToolSpec(
        name: 'read_file_tool',
        description: 'Read contents of a file at the specified path',
        inputJsonSchema: readFileToolParameters,
      ),
      ToolSpec(
        name: 'list_directory_tool',
        description: 'List files and directories in the specified path',
        inputJsonSchema: listDirectoryToolParameters,
      ),
      ToolSpec(
        name: 'search_files_tool',
        description: 'Search for files by pattern in a directory tree',
        inputJsonSchema: searchFilesToolParameters,
      ),
      ToolSpec(
        name: 'write_file_tool',
        description: 'Write or update contents of a file',
        inputJsonSchema: writeFileToolParameters,
      ),
      ToolSpec(
        name: 'execute_shell_command_tool',
        description: 'Execute a shell/terminal command and return the output',
        inputJsonSchema: executeShellCommandToolParameters,
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
      );

      try {
        // Stream the response using .listen() for better performance
        final messageId = '${DateTime.now().millisecondsSinceEpoch}_agent';
        String fullContent = '';
        String toolCallString = '';
        String toolCallName = '';
        String toolCallId = '';
        int responseTokens = 0; // Track tokens for this response

        final Stream<ChatResult> stream;
        if (selectedChatRoom.model.ownedBy == OwnedByEnum.openai.name) {
          stream = openAI!.stream(PromptValue.chat(messagesToSend), options: options);
        } else {
          stream = localModel!.stream(PromptValue.chat(messagesToSend), options: options);
        }

        // Use Completer to wait for stream completion
        final completer = Completer<AIChatMessage>();

        listenerResponseStream = stream.listen(
          (final chunk) {
            final message = chunk.output;

            // Handle content streaming (when AI responds with text)
            if (message.content.isNotEmpty) {
              fullContent += message.content;

              // Add/update message (addBotMessageToList auto-concatenates by ID)
              // Pass accumulated responseTokens for accurate total
              addBotMessageToList(
                FluentChatMessage.ai(
                  id: messageId,
                  content: message.content,
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                  tokens: responseTokens, // Use accumulated total, not per-chunk
                  creator: selectedChatRoom.characterName,
                ),
              );
            }

            // Handle tool calls streaming (when AI wants to use tools)
            if (message.toolCalls.isNotEmpty) {
              final toolCall = message.toolCalls.first;
              toolCallString += toolCall.argumentsRaw;
              if (toolCall.name.isNotEmpty) {
                toolCallName = toolCall.name;
              }
              if (toolCall.id.isNotEmpty) {
                toolCallId = toolCall.id;
              }
            }

            // Track tokens
            if (chunk.usage.totalTokens != null) {
              totalSentTokens += chunk.usage.promptTokens ?? 0;
              totalReceivedTokens += chunk.usage.responseTokens ?? 0;
              responseTokens += chunk.usage.responseTokens ?? 0;
            }

            // Check for finish reasons
            if (chunk.finishReason == FinishReason.stop || chunk.finishReason == FinishReason.toolCalls) {
              // Build final response with accumulated tool calls
              AIChatMessage response;
              if (toolCallString.isNotEmpty && toolCallName.isNotEmpty) {
                try {
                  // Parse the complete tool call arguments
                  final toolCallArgs = jsonDecode(toolCallString) as Map<String, dynamic>;
                  final toolCall = AIChatMessageToolCall(
                    id: toolCallId.isNotEmpty ? toolCallId : 'tool_${DateTime.now().millisecondsSinceEpoch}',
                    name: toolCallName,
                    argumentsRaw: toolCallString,
                    arguments: toolCallArgs,
                  );
                  response = AIChatMessage(
                    content: fullContent,
                    toolCalls: [toolCall],
                  );
                } catch (e) {
                  logError('Error parsing tool call: $e');
                  response = AIChatMessage(content: fullContent);
                }
              } else {
                response = AIChatMessage(content: fullContent);
              }
              completer.complete(response);
            }
          },
          onDone: () {
            // If not already completed, complete with content-only response
            if (!completer.isCompleted) {
              completer.complete(AIChatMessage(content: fullContent));
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

        // Wait for stream to complete
        final response = await completer.future;

        // Clean up listener after completion
        listenerResponseStream = null;

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
        if (responseTokens == 0 && fullContent.isNotEmpty) {
          responseTokens = await countTokensString(fullContent);
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
          if (toolArgs.containsKey('path')) {
            keyParam = toolArgs['path'];
          } else if (toolArgs.containsKey('directory')) {
            keyParam = toolArgs['directory'];
          } else if (toolArgs.containsKey('pattern')) {
            keyParam = '${toolArgs['pattern']} in ${toolArgs['directory'] ?? '.'}';
          }

          // Show tool execution status with parameter
          final executingMessage = keyParam != null ? '⚙️ Executing: $toolName "$keyParam"' : '⚙️ Executing: $toolName';

          addBotHeader(
            FluentChatMessage.executionHeader(
              id: '${DateTime.now().millisecondsSinceEpoch}_exec',
              content: executingMessage,
              timestamp: DateTime.now().millisecondsSinceEpoch,
              creator: selectedChatRoom.characterName,
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

          // Show completion status (check if it was an error)
          final isError = toolResult.startsWith('Error:');
          final statusIcon = isError ? '❌' : '✓';
          final statusText = isError ? 'Failed' : 'Completed';

          addBotHeader(
            FluentChatMessage.executionHeader(
              id: '${DateTime.now().millisecondsSinceEpoch}_done',
              content: '$statusIcon $statusText: $toolName',
              timestamp: DateTime.now().millisecondsSinceEpoch,
              creator: selectedChatRoom.characterName,
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
        throw e;
      }
    }

    // Clean up
    listenerResponseStream = null;

    if (iteration >= maxIterations) {
      addBotHeader(
        FluentChatMessage.executionHeader(
          id: '${DateTime.now().millisecondsSinceEpoch}_maxiter',
          content: '⚠️ Reached maximum iterations',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          creator: selectedChatRoom.characterName,
        ),
      );
    }
  }

  /// Execute a single agent tool and return the result
  Future<String> _executeAgentTool(String toolName, Map<String, dynamic> args) async {
    try {
      switch (toolName) {
        case 'read_file_tool':
          return await _handleReadFileTool(args);
        case 'list_directory_tool':
          return await _handleListDirectoryTool(args);
        case 'search_files_tool':
          return await _handleSearchFilesTool(args);
        case 'write_file_tool':
          return await _handleWriteFileTool(args);
        case 'execute_shell_command_tool':
          return await _handleExecuteShellCommandTool(args);
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
      final String path = args['path'];
      final file = File(path);

      if (!await file.exists()) {
        return 'Error: File not found at $path';
      }

      final contents = await file.readAsString();
      final lineCount = contents.split('\n').length;

      return 'File: $path\nLines: $lineCount\n\nContents:\n$contents';
    } catch (e) {
      return 'Error reading file: $e';
    }
  }

  Future<String> _handleListDirectoryTool(Map<String, dynamic> args) async {
    try {
      final String path = args['path'];
      final bool recursive = args['recursive'] ?? false;
      final dir = Directory(path);

      if (!await dir.exists()) {
        return 'Error: Directory not found at $path';
      }

      final List<String> files = [];
      final List<String> directories = [];

      if (recursive) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            files.add(entity.path);
          } else if (entity is Directory) {
            directories.add(entity.path);
          }
        }
      } else {
        await for (final entity in dir.list(recursive: false, followLinks: false)) {
          if (entity is File) {
            files.add(entity.path);
          } else if (entity is Directory) {
            directories.add(entity.path);
          }
        }
      }

      final buffer = StringBuffer();
      buffer.writeln('Directory: $path');
      buffer.writeln('Directories (${directories.length}):');
      for (final dir in directories.take(50)) {
        buffer.writeln('  📁 $dir');
      }
      if (directories.length > 50) {
        buffer.writeln('  ... and ${directories.length - 50} more directories');
      }

      buffer.writeln('\nFiles (${files.length}):');
      for (final file in files.take(100)) {
        buffer.writeln('  📄 $file');
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
      final String pattern = args['pattern'];
      final String directory = args['directory'];
      final int maxResults = args['maxResults'] ?? 50;

      final dir = Directory(directory);
      if (!await dir.exists()) {
        return 'Error: Directory not found at $directory';
      }

      final List<String> matches = [];
      final regExp = RegExp(
        pattern.replaceAll('*', '.*').replaceAll('?', '.'),
        caseSensitive: false,
      );

      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final fileName = entity.uri.pathSegments.last;
          if (regExp.hasMatch(fileName)) {
            matches.add(entity.path);
            if (matches.length >= maxResults) break;
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

  Future<String> _handleWriteFileTool(Map<String, dynamic> args) async {
    try {
      final String path = args['path'];
      final String content = args['content'];
      final bool append = args['append'] ?? false;

      final file = File(path);

      // Create parent directories if they don't exist
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
}
