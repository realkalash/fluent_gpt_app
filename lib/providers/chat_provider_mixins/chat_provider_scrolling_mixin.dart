import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

mixin ChatProviderScrollingMixin on ChangeNotifier, ChatProviderBaseMixin {
  final listItemsScrollController = AutoScrollController();
  String? blinkMessageId;
  bool scrollToBottomOnAnswer = true;

  @override
  Future<void> scrollToEnd({bool withDelay = true}) async {
    try {
      if (withDelay) await Future.delayed(const Duration(milliseconds: 100));
      if (messages.value.isEmpty) return;

      // '_positions.isNotEmpty': ScrollController not attached to any scroll views.
      if (listItemsScrollController.hasClients) {
        // 0 because list is reversed
        listItemsScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error while scrolling to end: $e');
      }
    }
  }

  Future autoScrollToEnd({bool withDelay = true}) async {
    if (scrollToBottomOnAnswer) {
      return scrollToEnd(withDelay: withDelay);
    }
  }

  Future<void> scrollToMessage(String messageKey) async {
    final index = indexOf(messagesReversedList, messages.value[messageKey]);
    blinkMessageId = messageKey;
    await listItemsScrollController.scrollToIndex(index);
    notifyListeners();
  }

  /// Index in reversed list
  Future<void> scrollToIndex(int index) async {
    blinkMessageId = messagesReversedList[index].id;
    await listItemsScrollController.scrollToIndex(index);
    notifyListeners();
  }

  /// custom get index
  int indexOf(List<FluentChatMessage> list, FluentChatMessage? element, [int start = 0]) {
    if (start < 0) start = 0;
    for (int i = start; i < list.length; i++) {
      final first = list[i];
      if (first.content == element?.content) {
        return i;
      }
    }
    return -1;
  }

  /// Finds the last message that is visible for the ai to see
  /// Scrolls up to the last message that is visible for the ai to see
  Future<void> scrollToLastOverflowMessage() async {
    final maxTokens = maxTokenLenght;
    final messagesList = messagesReversedList.toList();
    messagesList.add(FluentChatMessage.system(id: '000', content: selectedChatRoom.systemMessage ?? ''));
    int tokens = 0;
    for (var message in messagesList) {
      tokens += message.tokens == 0 ? await countTokensString(message.content) : message.tokens;
      if (tokens > maxTokens) {
        scrollToMessage(message.id);
        break;
      }
    }
  }
}

