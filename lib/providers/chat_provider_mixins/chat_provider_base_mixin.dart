import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:rxdart/rxdart.dart';

/// Base mixin that declares common dependencies needed by other mixins.
/// All mixins that need these dependencies should extend this mixin.
mixin ChatProviderBaseMixin on ChangeNotifier {
  // Core dependencies
  BuildContext? get context;
  
  // Message controller
  TextEditingController get messageController;
  
  // Message operations
  Future<void> addHumanMessageToList(FluentChatMessage message);
  void addCustomMessageToList(FluentChatMessage message);
  void addBotMessageToList(FluentChatMessage message);
  void addBotErrorMessageToList(FluentChatMessage message);
  Future<void> editMessage(String id, FluentChatMessage message);
  // Token operations
  Future<int> countTokensString(String text);
  
  // Message queries
  Future<String> getLastFewMessagesForContextAsString({int maxTokensLenght = 1024});
  Future<String> retrieveResponseFromPrompt(
    String message, {
    String? systemMessage,
    List<FluentChatMessage> additionalPreMessages = const [],
    int? maxTokens,
  });
  Future<List<FluentChatMessage>> getLastMessagesLimitToTokens(
    int tokens, {
    bool allowOverflow = true,
    bool allowImages = false,
    bool stripMessage = true,
  });
  Future<String> convertMessagesToString(
    List<FluentChatMessage> messages, {
    bool includeSystemMessages = false,
  });
  
  // Storage operations
  Future<void> saveToDisk(List<ChatRoom> rooms);
  
  // Message sending
  Future<void> sendSingleMessage(
    String messageContent, {
    String? systemMessage,
    String? imageBase64,
    bool showPromptInChat = false,
    bool showImageInChat = false,
    bool sendAsStream = true,
  });
  
  // Scrolling
  Future<void> scrollToEnd({bool withDelay = true});
  
  // State
  bool get isAnswering;
  set isAnswering(bool value);
  
  // Initialization-specific dependencies
  Future<void> loadMessagesFromDisk(String id);
  Future<void> deleteChatRoom(String chatRoomId);
  Future<void> initChatModels();
  void initModelsApi();
  
  // Token counters (from TokensMixin)
  double get autoScrollSpeed;
  set autoScrollSpeed(double value);
  int get totalTokensByMessages;
  set totalTokensByMessages(int value);
  int get totalSentTokens;
  set totalSentTokens(int value);
  int get totalReceivedTokens;
  set totalReceivedTokens(int value);
  BehaviorSubject<int> get totalReceivedForCurrentChat;
}

