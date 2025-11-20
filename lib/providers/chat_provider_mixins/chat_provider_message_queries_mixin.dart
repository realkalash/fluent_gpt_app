import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

mixin ChatProviderMessageQueriesMixin on ChangeNotifier, ChatProviderBaseMixin {
  /// Do not use it often because we don't know how many tokens it will consume
  Future<List<FluentChatMessage>> getLastFewMessages({int count = 15}) async {
    final values = messages.value;
    final list = <FluentChatMessage>[];
    // Start from end to get last messages
    final messagesIterator = values.values.toList().reversed;
    int countAdded = 0;
    for (var message in messagesIterator) {
      if (countAdded >= count) break;
      if (message.type != FluentChatMessageType.webResult) {
        // map custom messages to human messages because openAi doesn't support them
        if (message.type == FluentChatMessageType.file) {
          // insert at start to maintain order
          list.insert(0, message);
        } else if (message.type == FluentChatMessageType.image || message.type == FluentChatMessageType.imageAi) {
          if (selectedChatRoom.model.imageSupported) list.insert(0, message);
        } else {
          // insert at start to maintain order
          list.insert(0, message);
        }
        countAdded++;
      }
    }
    // append current global system message to the very beginning
    if (selectedChatRoom.systemMessage?.isNotEmpty == true) {
      // if we exceed the limit, put the system message at the start
      // and add system message "Previous messages were trimmed"
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      list.insert(
        0,
        FluentChatMessage(
          id: '$timestamp',
          content: selectedChatRoom.systemMessage ?? defaultGlobalSystemMessage,
          creator: 'system',
          timestamp: timestamp,
          type: FluentChatMessageType.system,
        ),
      );
      if (values.length > count) {
        list.insert(
          1,
          FluentChatMessage(
            id: '_$timestamp',
            content: '(Previous messages were trimmed)',
            creator: 'system',
            timestamp: timestamp,
            type: FluentChatMessageType.system,
          ),
        );
      }
    }

    return list;
  }

  /// Retrieves the last messages from the chat limited by the specified token count.
  ///
  /// This method iterates through the messages and accumulates their token counts
  /// until the specified token limit is reached. It supports different types of
  /// messages including `AIChatMessage`, `HumanChatMessage`, `SystemChatMessage`, and
  /// `TextFileCustomMessage`. If the `allowOverflow` parameter is set to true and no
  /// messages have been added to the result, the last message will be added regardless
  /// of the token limit.
  /// if [stripMessage] is true, it will strip the message from new lines and double spaces
  @override
  Future<List<FluentChatMessage>> getLastMessagesLimitToTokens(
    int tokens, {
    bool allowOverflow = true,
    bool allowImages = false,
    bool stripMessage = true,
  }) async {
    int currentTokens = 0;
    // for debug purposes
    // int currentTokensRaw = 0;
    // int currentTokensStripped = 0;
    final result = <FluentChatMessage>[];
    final chatModel = selectedChatRoom.model;
    bool isImageAdded = false;

    /// We need to count from the bottom to the top. We cant use messagesReversedList because it takes time to populate it
    for (var message in messages.value.values.toList().reversed) {
      if (message.type == FluentChatMessageType.textAi ||
          message.type == FluentChatMessageType.textHuman ||
          message.type == FluentChatMessageType.system ||
          message.type == FluentChatMessageType.executionHeader ||
          message.type == FluentChatMessageType.shellExec ||
          message.type == FluentChatMessageType.file) {
        var tokensCount = message.tokens;
        // await modelCounter.countTokens(PromptValue.string(message.content));
        if ((currentTokens + tokensCount) > tokens) {
          if (kDebugMode) {
            print('[BREAK beacuse of limit] Tokens: $tokensCount; message: ${message.content.split('\n').first} ');
          }
          break;
        }
        // currentTokensRaw += message.tokens;
        if (stripMessage) {
          final countNewLines = message.content.split('\n\n').length;
          if (countNewLines > 1) {
            final newContent = message.content.replaceAll('\n\n', ' ').replaceAll('  ', ' ');
            // rough estimation of tokens because each model can count them differently
            tokensCount = message.tokens - countNewLines + 1;
            message = message.copyWith(content: newContent, tokens: tokensCount);
          }
        }
        currentTokens += tokensCount;
        // print(
        //     '${message.timestamp} Tokens stripped: $currentTokens; Tokens raw: $currentTokensRaw;');
        result.add(message);
      } else if (allowImages &&
          (message.type == FluentChatMessageType.image || message.type == FluentChatMessageType.imageAi)) {
        if (chatModel.imageSupported) {
          if (supportsMultipleHighresImages(chatModel.modelName))
            result.add(message);
          else {
            if (!isImageAdded) {
              result.add(message);
              isImageAdded = true;
            } else {
              result.add(message.imageToHiddenText());
            }
          }
        }
      }
    }
    // if allowOverflow is true and we didn't add any element, add only the last one
    final messagesOriginal = messages.value.values;
    final lastElement = messagesOriginal.last;
    if (result.length == 1 && allowOverflow) {
      if (lastElement.type == FluentChatMessageType.textHuman) {
        final indexLast = messagesOriginal.length - 1;
        final beforeLast = indexLast == 0 ? null : messagesOriginal.elementAtOrNull(indexLast - 1);

        /// The last message can be human message, so we need to add it and the previous one
        if (beforeLast != null) result.add(beforeLast);
      }
    } else if (result.isEmpty && allowOverflow) {
      result.add(lastElement);
    }
    // print(
    //     'SUM Tokens stripped: $currentTokensStripped; Tokens raw: $currentTokensRaw;');

    /// because we counted from the bottom to top we need to invert it to original order
    return result.reversed.toList();
  }

  @override
  Future<String> getLastFewMessagesForContextAsString({int maxTokensLenght = 1024}) async {
    final lastMessages = await getLastMessagesLimitToTokens(maxTokensLenght);
    final userName = AppCache.userName.value ?? 'User';
    final characterName = selectedChatRoom.characterName;
    return lastMessages.map((e) {
      if (e.type == FluentChatMessageType.textHuman) {
        return '$userName: ${e.content}';
      }
      if (e.type == FluentChatMessageType.textAi) {
        return '$characterName: ${e.content}';
      }
      if (e.type == FluentChatMessageType.shellExec) {
        return 'Shell execution: ${e.content}';
      }
      if (e.type == FluentChatMessageType.webResult) {
        final results = e.webResults;
        return 'Web search results: ${results?.map((e) => '${e.title}->${e.description}').join(';')}';
      }
      return '';
    }).join('\n');
  }

  @override
  Future<String> convertMessagesToString(
    List<FluentChatMessage> messages, {
    bool includeSystemMessages = false,
  }) async {
    final aiName = selectedChatRoom.characterName;
    final userName = AppCache.userName.value ?? 'User';
    final result = messages.map((e) {
      if (e.type == FluentChatMessageType.textAi) {
        return '$aiName: ${e.content}';
      }
      if (e.type == FluentChatMessageType.textHuman) {
        return '$userName: ${e.content}';
      }
      if (e.type == FluentChatMessageType.webResult) {
        final results = e.webResults;
        return 'Web search results: ${results!.map((e) => '${e.title}->${e.description}').join(';')}';
      }
      if (includeSystemMessages && e.type == FluentChatMessageType.system) {
        return 'System: ${e.content}';
      }
      if (e.type == FluentChatMessageType.shellExec) {
        return 'Shell execution: ${e.content}';
      }
      return '';
    }).join('\n');
    return result;
  }

  Future<String> convertMessagesToStringWithTimestamp(
    List<FluentChatMessage> messages, {
    bool includeSystemMessages = false,
  }) async {
    final aiName = selectedChatRoom.characterName;
    final userName = AppCache.userName.value ?? 'User';
    final dateFormatter = DateFormat('EEE M/d HH:mm');
    final result = messages.map((e) {
      final date = dateFormatter.format(DateTime.fromMillisecondsSinceEpoch(e.timestamp));
      if (e.type == FluentChatMessageType.textAi) {
        return '$date $aiName: ${e.content}';
      }
      if (e.type == FluentChatMessageType.textHuman) {
        return '$date $userName: ${e.content}';
      }
      if (e.type == FluentChatMessageType.webResult) {
        final results = e.webResults;
        return 'Web search results: ${results?.map((e) => '${e.title}->${e.description}').join(';')}';
      }
      if (e.type == FluentChatMessageType.shellExec) {
        return '$date: Shell execution: ${e.content}';
      }
      if (includeSystemMessages && e.type == FluentChatMessageType.system) {
        return 'System: ${e.content}';
      }
      return '';
    }).join('\n');
    return result;
  }

  bool supportsMultipleHighresImages(String modelName) {
    if (modelName == 'google/gemini-2.5-flash') return false;
    if (modelName == 'gemini-2.5-flash') return false;
    return true;
  }
}
