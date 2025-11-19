import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/on_message_actions/on_message_action.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/features/image_generator_feature.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_ui/fluent_ui.dart';

mixin ChatProviderImageGenerationMixin on ChangeNotifier, ChatProviderBaseMixin {
  bool isGeneratingImage = false;

  /// Gets the image generator API key, showing an error dialog if none is found.
  /// Returns null if no API key is available.
  String? getImageGeneratorApiKey({bool showError = true}) {
    String? apiKey = AppCache.imageGeneratorApiKey.value;
    if (apiKey == null) {
      final openAiModel = allModels.value.firstWhereOrNull(
        (element) => element.ownedBy == 'openai' && element.apiKey.isNotEmpty,
      );
      if (openAiModel != null) {
        apiKey = openAiModel.apiKey;
      }
    }
    if (apiKey == null && showError) {
      displayErrorInfoBar(
        title: 'Error while generating image'.tr,
        message: 'No API key found for image generation. Please add an **openAI** API key to any model',
      );
    }
    return apiKey;
  }

  /// Generates image from tool and returns either success message for AI or error message for AI to use it in the next iteration
  Future<String> generateImageFromTool({required String prompt, String? size}) async {
    final apiKey = getImageGeneratorApiKey();
    if (apiKey == null) {
      isGeneratingImage = false;
      notifyListeners();
      return 'Error: No API key found in settings for image generation';
    }
    try {
      isGeneratingImage = true;
      notifyListeners();
      final imageChatMessage = await ImageGeneratorFeature.generateImage(
        prompt: prompt,
        apiKey: apiKey,
        n: 1,
        size: size ?? AppCache.imageGeneratorSize.value!,
        quality: AppCache.imageGeneratorQuality.value!,
        style: AppCache.imageGeneratorStyle.value ?? 'natural',
      );
      return 'Successfully generated image: ${imageChatMessage.revisedPrompt ?? prompt}';
    } catch (e) {
      return 'Error generating image: $e';
    } finally {
      isGeneratingImage = false;
      notifyListeners();
    }
  }

  Future<void> onResponseEndGenerateImage(
    FluentChatMessage response,
    OnMessageAction action, {
    String? size,
  }) async {
    try {
      final promptMessage = messages.value.entries.last.value.copyWith();
      // deleteMessage(messagesReversedList.first.id);
      final prompt = response.content.replaceAll(action.regExp, '');

      final apiKey = getImageGeneratorApiKey();
      if (apiKey == null) {
        return;
      }

      isGeneratingImage = true;
      notifyListeners();
      final imageChatMessage = await ImageGeneratorFeature.generateImage(
        prompt: prompt,
        apiKey: apiKey,
        size: size ?? AppCache.imageGeneratorSize.value!,
        quality: AppCache.imageGeneratorQuality.value!,
        style: AppCache.imageGeneratorStyle.value!,
        n: 1,
      );
      final newTimestamp = DateTime.now().millisecondsSinceEpoch;
      addCustomMessageToList(
        FluentChatMessage.imageAi(
          id: '$newTimestamp',
          content: imageChatMessage.content,
          creator: imageChatMessage.generatedBy,
          timestamp: newTimestamp,
          imagePrompt: imageChatMessage.revisedPrompt,
        ),
      );
      final questionAboutImage = await retrieveResponseFromPrompt(
        'You just generated an image. Ask user how they feel about your drawing in "{lang}" language using short 1 sentence'
            .replaceAll('{lang}', I18n.currentLocale.languageCode),
        systemMessage: selectedChatRoom.systemMessage,
        additionalPreMessages: [
          messagesReversedList[0],
          promptMessage,
        ],
      );
      final newTimestamp2 = DateTime.now().millisecondsSinceEpoch;
      final countTokens = await countTokensString(questionAboutImage);
      addBotMessageToList(
        FluentChatMessage.ai(
          id: newTimestamp2.toString(),
          content: questionAboutImage,
          timestamp: newTimestamp2,
          creator: selectedChatRoom.characterName,
          tokens: countTokens,
        ),
      );
      saveToDisk([selectedChatRoom]);
    } catch (e) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      addBotErrorMessageToList(
        FluentChatMessage.ai(
          id: timestamp.toString(),
          content: 'Error while generating image: $e',
          creator: 'error',
          timestamp: timestamp,
        ),
      );
    } finally {
      isGeneratingImage = false;
      notifyListeners();
    }
  }
}
