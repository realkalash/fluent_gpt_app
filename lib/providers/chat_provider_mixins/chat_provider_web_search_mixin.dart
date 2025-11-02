import 'dart:convert';
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/scrapper/web_scrapper.dart';
import 'package:fluent_gpt/common/scrapper/web_search_result.dart';
import 'package:fluent_gpt/features/open_ai_features.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_gpt/providers/chat_utils.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_ui/fluent_ui.dart';

mixin ChatProviderWebSearchMixin on ChangeNotifier, ChatProviderBaseMixin {
  bool isWebSearchEnabled = false;

  void toggleWebSearch() {
    isWebSearchEnabled = !isWebSearchEnabled;
    notifyListeners();
  }

  void addWebResultsToMessages(List<WebSearchResult> webpage) {
    final values = messages.value;
    final dateTime = DateTime.now();
    final id = dateTime.toIso8601String();
    values[id] = FluentChatMessage(
      id: id,
      content: '',
      creator: 'search',
      timestamp: dateTime.millisecondsSinceEpoch,
      type: FluentChatMessageType.webResult,
      webResults: webpage,
    );
    messages.add(values);
    saveToDisk([selectedChatRoom]);
    scrollToEnd();
  }

  Future<void> _sendMessageWebSearch(String messageContent) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await addHumanMessageToList(
      FluentChatMessage.humanText(
        id: '$timestamp',
        content: messageContent,
        creator: AppCache.userName.value!,
        timestamp: timestamp,
        tokens: await countTokensString(messageContent),
      ),
    );
    if (selectedModel.ownedBy == OwnedByEnum.openai.name) {
      isAnswering = true;
      notifyListeners();
      try {
        final messageResult = await OpenAiFeatures.webSearch(
          messageContent,
          apiKey: selectedChatRoom.model.apiKey,
          city: AppCache.userCityName.value,
        );
        addCustomMessageToList(messageResult);
      } catch (e) {
        displayErrorInfoBar(
          title: 'Error while searching',
          message: '$e',
        );
        logError('Error while searching: $e');
      } finally {
        isAnswering = false;
        notifyListeners();
      }
      return;
    }
    final lastMessages = await getLastFewMessagesForContextAsString();
    String searchPrompt = await retrieveResponseFromPrompt(
      '$webSearchPrompt """$lastMessages"""\n GIVE ME RESULT ONLY IN THIS FORMAT. DON\'T ADD ANYTHING ELSE'
      '{"query":"<your response>"}',
    );
    isAnswering = true;
    notifyListeners();
    final scrapper = WebScraper();
    try {
      final decoded = jsonDecode(searchPrompt);
      searchPrompt = decoded['query'];
    } catch (e) {
      // do nothing
    }
    try {
      final results = await scrapper.search(searchPrompt);
      if (AppCache.scrapOnlyDecription.value!) {
        final List<WebSearchResult> shortResults = results.take(15).map((e) => e).toList();
        addWebResultsToMessages(shortResults);
        await _answerBasedOnWebResults(
            shortResults, 'User asked: $messageContent. Search prompt from search Agent: "$searchPrompt"');
      } else {
        final threeRessults = results.take(3).map((e) => e).toList();
        addWebResultsToMessages(threeRessults);
        await _answerBasedOnWebResults(threeRessults, messageContent);
      }
    } catch (e) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      addBotErrorMessageToList(FluentChatMessage.ai(
        id: '$timestamp',
        content: 'Error while searching: $e',
        creator: 'system',
        timestamp: timestamp,
      ));
    }

    isAnswering = false;
    notifyListeners();
  }

  Future _answerBasedOnWebResults(
    List<WebSearchResult> results,
    String userMessage,
  ) async {
    String urlContent = '';
    for (var result in results) {
      final url = result.url;
      final title = result.title;
      final text = AppCache.scrapOnlyDecription.value!
          ? WebScraper.clearTextFromTags(result.description)
          : await WebScraper().extractFormattedContent(url);
      final characters = text.characters;
      final tokenCount = characters.length / 4;
      // print('[scrapper] Token count: $tokenCount');
      // print('[scrapper] Char count: ${characters.length}');
      // print('[scrapper] URL: $url');
      // print('[scrapper] Title: $title');
      // print('[scrapper] Text: $text');
      if (tokenCount > 6500) {
        urlContent += '[SYSTEM:Char count exceeded 3500. Stop the search]';
        break;
      }
      // if char count is more than 2000, append and skip the rest
      if (tokenCount > 2000) {
        // append the first 2000 chars
        urlContent += characters.take(2000).join('');
        urlContent += '[SYSTEM:Char count exceeded 500. Skip the rest of the page]';
        continue;
      }

      urlContent += 'Page Title:$title\nBody:```$text```\n\n';
    }
    userMessage = modifyMessageStyle(userMessage);

    return sendSingleMessage(
      'You are an agent of LLM model that scraps the internet. Answer to the message based only on this search results from these web pages: $urlContent.\n'
      'In the end add a caption where did you find this info.'
      '''E.g. "I found this information on: 
      - [page1](link1) 
      - [page2](link2)
      "'''
      '.Answer in markdown with links. ALWAYS USE SOURCE NAMES AND LINKS!'
      'User message: $userMessage',
    );
  }
}

