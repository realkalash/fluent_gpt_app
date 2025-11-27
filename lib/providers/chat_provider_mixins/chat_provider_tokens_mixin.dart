import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_gpt/widgets/confirmation_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:rxdart/rxdart.dart';

mixin ChatProviderTokensMixin on ChangeNotifier, ChatProviderBaseMixin {
  @Deprecated('Don not use it to set value. Only for StreamBuilder')

  /// Calculated by current messages in the chat.
  final BehaviorSubject<int> totalTokensForCurrentChatByMessages = BehaviorSubject.seeded(0);

  @override
  set totalTokensByMessages(int value) =>
      // ignore: deprecated_member_use_from_same_package
      totalTokensForCurrentChatByMessages.add(value);

  /// Calculated by current messages in the chat.
  // ignore: deprecated_member_use_from_same_package
  @override
  // ignore: deprecated_member_use_from_same_package
  int get totalTokensByMessages => totalTokensForCurrentChatByMessages.value;

  @Deprecated('Don not use it to set value. Only for StreamBuilder')
  final BehaviorSubject<int> totalSentForCurrentChat = BehaviorSubject.seeded(0);

  @override
  set totalSentTokens(int value) {
    // ignore: deprecated_member_use_from_same_package
    totalSentForCurrentChat.add(value);
    selectedChatRoom.totalSentTokens = value;
  }

  // ignore: deprecated_member_use_from_same_package
  @override
  // ignore: deprecated_member_use_from_same_package
  int get totalSentTokens => totalSentForCurrentChat.value;

  @override
  BehaviorSubject<int> totalReceivedForCurrentChat = BehaviorSubject.seeded(0);

  @override
  set totalReceivedTokens(int value) {
    totalReceivedForCurrentChat.add(value);
    selectedChatRoom.totalReceivedTokens = value;
  }

  @override
  int get totalReceivedTokens => totalReceivedForCurrentChat.value;

  @override
  Future<int> countTokensString(String text) async {
    if (text.isEmpty) return 0;
    final options = ChatOpenAIOptions(model: selectedChatRoom.model.modelName);
    return openAI!.countTokens(PromptValue.string(text), options: options);
  }

  Future<int> countTokensFromMessages(List<ChatMessage> messages) async {
    int tokens = 0;
    if (selectedChatRoom.model.ownedBy == 'openai') {
      tokens = await openAI!.countTokens(PromptValue.chat(messages),
          options: ChatOpenAIOptions(
            model: selectedChatRoom.model.modelName,
          ));
    } else {
      tokens = await openAI!.countTokens(PromptValue.chat(messages),
          options: ChatOpenAIOptions(
            // for all unknown models we assume it's gpt 3.5 turbo
            model: 'gpt-3.5-turbo-16k-0613',
          ));
    }
    return tokens;
  }

  /// will calculate tokens for messages using cached tokens in each message.
  ///
  /// If the message has tokens, it will use them. Otherwise, it will use Future to calculate the tokens for the message.
  Future<int> countTokensFromMessagesCached(Iterable<FluentChatMessage> messages) async {
    int tokens = 0;
    for (int i = 0; i < messages.length; i++) {
      var message = messages.elementAt(i);
      if (message.tokens > 0) {
        tokens += message.tokens;
      } else {
        if (message.type == FluentChatMessageType.textAi ||
            message.type == FluentChatMessageType.textHuman ||
            message.type == FluentChatMessageType.system) {
          tokens += await countTokensString(message.content);
        }
      }
    }
    return tokens;
  }

  Future<void> recalculateTokensFromLocalMessages([bool showPromptToOverride = true]) async {
    var _sentTokens = 0;
    var _receivedTokens = 0;
    for (var message in messages.value.values) {
      if (message.type == FluentChatMessageType.textAi) {
        _receivedTokens += message.tokens;
      } else {
        _sentTokens += message.tokens;
      }
    }
    totalTokensByMessages = await countTokensFromMessagesCached([
      //add system message
      if (selectedChatRoom.systemMessage != null)
        FluentChatMessage.system(
          id: '-1',
          content: selectedChatRoom.systemMessage!,
        ),
      ...messages.value.values
    ]);
    notifyListeners();
    if (showPromptToOverride == false) return;
    final shouldOverrideChatTokens = await ConfirmationDialog.show(
      context: context!,
      message: 'Do you want to save and override chat tokens with the new value?',
    );
    if (shouldOverrideChatTokens) {
      selectedChatRoom.totalSentTokens = _sentTokens;
      selectedChatRoom.totalReceivedTokens = _receivedTokens;
      totalReceivedForCurrentChat.add(_receivedTokens);
      totalSentTokens = _sentTokens;
      saveToDisk([selectedChatRoom]);
    }
  }
}
