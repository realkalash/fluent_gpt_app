import 'dart:convert';
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:langchain_openai/langchain_openai.dart';

mixin ChatProviderModelsMixin on ChangeNotifier, ChatProviderBaseMixin {
  @override
  Future<void> initChatModels() async {
    final listModelsJsonString = await AppCache.savedModels.value();
    if (listModelsJsonString.isNotEmpty == true) {
      final listModelsJson = jsonDecode(listModelsJsonString) as List;
      var listModels = listModelsJson.map((e) => ChatModelAi.fromJson(e as Map<String, dynamic>)).toList();
      // Sort by index and reassign sequential indices
      listModels.sort((a, b) => a.index.compareTo(b.index));
      for (int i = 0; i < listModels.length; i++) {
        listModels[i] = listModels[i].copyWith(index: i);
      }
      allModels.add(listModels);
    }
  }

  Future<void> addNewCustomModel(ChatModelAi model) async {
    final allModelsList = allModels.value;
    final maxIndex = allModelsList.isEmpty 
        ? -1 
        : allModelsList.map((e) => e.index).reduce((a, b) => a > b ? a : b);
    final newModel = model.copyWith(index: maxIndex + 1);
    allModelsList.add(newModel);
    allModels.add(allModelsList);
    await saveModelsToDisk();
  }

  Future removeCustomModel(ChatModelAi model) async {
    final allModelsList = allModels.value;
    allModelsList.remove(model);
    // Reassign indices sequentially after removal
    allModelsList.sort((a, b) => a.index.compareTo(b.index));
    for (int i = 0; i < allModelsList.length; i++) {
      allModelsList[i] = allModelsList[i].copyWith(index: i);
    }
    allModels.add(allModelsList);
    await saveModelsToDisk();
  }

  Future<void> reorderModels(int oldIndex, int newIndex) async {
    final allModelsList = List<ChatModelAi>.from(allModels.value);
    // Sort by index first to ensure correct order
    allModelsList.sort((a, b) => a.index.compareTo(b.index));
    
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = allModelsList.removeAt(oldIndex);
    allModelsList.insert(newIndex, item);
    
    // Update indices to match new positions
    for (int i = 0; i < allModelsList.length; i++) {
      allModelsList[i] = allModelsList[i].copyWith(index: i);
    }
    
    allModels.add(allModelsList);
    await saveModelsToDisk();
  }

  Future<void> saveModelsToDisk() async {
    final allModelsList = allModels.value;
    final listModelsJson = allModelsList.map((e) => e.toJson()).toList();
    await AppCache.savedModels.set(jsonEncode(listModelsJson));
  }

  /// Should be called after we load all chat rooms
  @override
  void initModelsApi() {
    openAI = ChatOpenAI(apiKey: selectedModel.apiKey);
    if (selectedModel.uri != null && selectedModel.uri!.isNotEmpty)
      localModel = ChatOpenAI(
        baseUrl: selectedModel.uri!,
        apiKey: selectedModel.apiKey,
      );
  }
}

