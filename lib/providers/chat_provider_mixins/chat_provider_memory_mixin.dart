import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/dialogs/info_about_user_dialog.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_gpt_tokenizer/flutter_gpt_tokenizer.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';

mixin ChatProviderMemoryMixin on ChangeNotifier, ChatProviderBaseMixin {
  /// returns generated info about user
  Future<String> generateUserKnowladgeBasedOnText(String text) async {
    final userName = AppCache.userName.value;
    final response = await retrieveResponseFromPrompt(
      'Based on this messages/conversation/text give me a short sentence to populate knowladge about $userName:'
      '"$text"',
    );
    log('Generated user knowladge: "$response"');
    final personalKnowladge = await AppCache.userInfo.value();
    // final currentDate = DateTime.now();
    // final stringDate = '${currentDate.year}/${currentDate.month}/${currentDate.day}';
    /// I think it would be better to keep it short...
    final finalString = response;
    // append to the end
    AppCache.userInfo.set('$personalKnowladge\n$finalString');
    return response;
  }

  /// returns generated info about user
  Future<void> generateUserKnowladgeBasedOnConversation() async {
    final userName = AppCache.userName.value!;
    final limitedMessages = await getLastMessagesLimitToTokens(4096);
    final mainPrompt = summarizeConversationToRememberUser.replaceAll('{user}', userName);
    final messagesAsString = await convertMessagesToString(limitedMessages);
    final finalPrompt = '$mainPrompt\n"$messagesAsString"';
    final messageToSend = ChatMessage.humanText(finalPrompt);
    log('prompt: \n"$finalPrompt"');

    final options = ChatOpenAIOptions(
      model: selectedChatRoom.model.modelName,
      maxTokens: 512,
    );
    AIChatMessage response;
    response = await openAI!.call([messageToSend], options: options);

    final personalKnowladge = await AppCache.userInfo.value();
    log('Generated user knowladge: "$response"');
    // final currentDate = DateTime.now();
    // final stringDate = '${currentDate.year}/${currentDate.month}/${currentDate.day}';
    /// I think it would be better to keep it short...
    final newKnowladge = response;
    if (newKnowladge.content == 'No important info' ||
        newKnowladge.content == 'No important info.' ||
        newKnowladge.content == '"No important info"') {
      return;
    }
    final appended = '$personalKnowladge\n${newKnowladge.content}';
    // append to the end
    AppCache.userInfo.set('$personalKnowladge\n${newKnowladge.content}');
    if (context != null) {
      displayInfoBar(
        context!,
        builder: (ctx, close) {
          return InfoBar(
            title: Text('Memory updated'.tr),
            content: Text(newKnowladge.content, maxLines: 2, overflow: TextOverflow.ellipsis),
            severity: InfoBarSeverity.info,
            isLong: true,
            action: Button(
              onPressed: () async {
                close();
                await Future.delayed(const Duration(milliseconds: 400));
                showDialog(
                  context: context!,
                  builder: (ctx) => const InfoAboutUserDialog(),
                  barrierDismissible: true,
                );
              },
              child: Text('Open memory'.tr),
            ),
          );
        },
        alignment: Alignment.topCenter,
        duration: const Duration(seconds: 6),
      );
    }
    // count tokens for personalKnowladge
    final tokensCount = await Tokenizer().count(appended, modelName: 'gpt-4');
    if (tokensCount > AppCache.maxTokensUserInfo.value!) {
      final shorterKnowladge = await retrieveResponseFromPrompt(
        summarizeUserKnowledge.replaceAll('{knowledge}', appended),
      );
      await AppCache.userInfo.set(shorterKnowladge);
    }
  }
}
