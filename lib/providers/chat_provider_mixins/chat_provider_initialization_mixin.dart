import 'dart:async';
import 'dart:convert';
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/common/on_message_actions/on_message_action.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/window_listener.dart';
import 'package:fluent_gpt/features/agent_get_message_actions.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_gpt/providers/chat_utils.dart';
import 'package:fluent_ui/fluent_ui.dart';

mixin ChatProviderInitializationMixin on ChangeNotifier, ChatProviderBaseMixin {
  late AgentGetMessageActions agentMessageActions;
  Timer? fetchChatsTimer;

  Future<void> init() async {
    agentMessageActions = AgentGetMessageActions(this as ChatProvider);
    initMessagesListener();
    await initChatModels();
    await initChatsFromDisk();
    initCustomActions();
    initSettingsFromCache();
    initTimers();
    initListeners();
  }

  void initMessagesListener() {
    messages.listen((messagesList) {
      messagesReversedList.clear();
      messagesReversedList.addAll(messagesList.values.toList().reversed);
    });
  }

  void initListeners() {
    if (AppCache.fetchChatsPeriodically.value == true) {
      /// If chats are located in the cloud, we need to fetch them twice
      AppWindowListener.windowVisibilityStream.distinct().listen((isOpen) async {
        if (isOpen) {
          /// This waiting is needed to prevent errors wtih cloud storate
          await Future.delayed(const Duration(milliseconds: 1500));
          log('Window opened. Fetching chats from disk');
          // initChatsFromDisk();
        }
      });
    }
  }

  void initTimers() {
    fetchChatsTimer?.cancel();
    if (AppCache.fetchChatsPeriodically.value == true) {
      fetchChatsTimer = Timer.periodic(Duration(minutes: AppCache.fetchChatsPeriodMin.value ?? 10), (timer) {
        log('Fetching chats from disk. ${timer.tick}');
        if (AppCache.fetchChatsPeriodically.value == false) {
          timer.cancel();
          return;
        }
        initChatsFromDisk();
      });
    }
  }

  Future initSettingsFromCache() async {
    autoScrollSpeed = AppCache.autoScrollSpeed.value!;
  }

  Future initCustomActions() async {
    final actionsJson = await AppCache.customActions.value();
    if (actionsJson.isNotEmpty == true && actionsJson != '[]') {
      final actions = jsonDecode(actionsJson) as List;
      final listActions = actions.map((e) => OnMessageAction.fromJson(e as Map<String, dynamic>)).toList();
      onMessageActions.add(listActions);
    } else {
      onMessageActions.add(defaultCustomActionsList);
    }
  }

  Future<void> initChatsFromDisk() async {
    final path = await FileUtils.getChatRoomsPath();
    final files = FileUtils.getFilesRecursive(path);
    final currentDate = DateTime.now();
    final deleteChatsAfterXDays = AppCache.archiveOldChatsAfter.value;

    for (var file in files) {
      try {
        final fileContent = await file.readAsString();
        final chatRoomRaw = jsonDecode(fileContent) as Map<String, dynamic>;
        final chatRoom = ChatRoom.fromMap(chatRoomRaw);
        chatRooms[chatRoom.id] = chatRoom;
        // delete chat if it's old enough
        if (deleteChatsAfterXDays != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(chatRoom.dateModifiedMilliseconds);
          final difference = currentDate.difference(date).inDays;
          if (difference >= deleteChatsAfterXDays && !chatRoom.isPinned && !chatRoom.isFolder) {
            log('Deleting chat room ${chatRoom.id} because it\'s old enough');
            await deleteChatRoom(chatRoom.id);
            continue;
          }
        }
        // root level check to load messages
        if (chatRoom.id == selectedChatRoomId) {
          loadMessagesFromDisk(selectedChatRoomId);
          totalSentTokens = chatRoom.totalSentTokens ?? 0;
          totalReceivedTokens = chatRoom.totalReceivedTokens ?? 0;
          totalReceivedForCurrentChat.add(totalReceivedTokens);
          totalTokensByMessages = totalSentTokens + totalReceivedTokens;
        } else if (chatRoom.children != null) {
          // We allow only 2 levels deep
          for (var subItem in chatRoom.children!) {
            if (subItem.children != null) {
              // 2 deep level check level check to load mesages
              for (var subSubItem in subItem.children!) {
                if (subSubItem.id == selectedChatRoomId) {
                  selectedChatRoomId = chatRoom.id;
                  loadMessagesFromDisk(selectedChatRoomId);
                }
              }
            } else if (subItem.id == selectedChatRoomId) {
              // 1 deep level check level check to load mesages
              selectedChatRoomId = chatRoom.id;
              loadMessagesFromDisk(selectedChatRoomId);
            }
          }
        }
      } catch (e) {
        log('initChatsFromDisk error: $e');
        chatRooms[file.path] = ChatRoom(
          id: file.path,
          chatRoomName: 'Error ${file.path}',
          model: const ChatModelAi(modelName: 'error', apiKey: ''),
          temp: temp,
          topk: topk,
          promptBatchSize: promptBatchSize,
          topP: topP,
          maxTokenLength: maxTokenLenght,
          repeatPenalty: repeatPenalty,
          systemMessage: '',
          dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
        );
      }
    }
    if (chatRooms.isEmpty) {
      final newChatRoom = generateDefaultChatroom();
      chatRooms[newChatRoom.id] = newChatRoom;
      selectedChatRoomId = newChatRoom.id;
    }
    // safety check if does not contain selected chat room
    if (!chatRooms.containsKey(selectedChatRoomId)) {
      selectedChatRoomId = chatRooms.entries.first.key;
      loadMessagesFromDisk(selectedChatRoomId);
    }
    selectedChatRoomId = selectedChatRoomId;
    if (openAI == null && localModel == null && selectedChatRoom.model.ownedBy != null) {
      initModelsApi();
    }
    // dumb way to notify UI listeners
    notifyRoomsStream();
  }
}

