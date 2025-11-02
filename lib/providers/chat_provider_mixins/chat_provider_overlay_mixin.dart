import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/main.dart' show mouseLocalPosition;
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_gpt/widgets/command_request_answer_overlay.dart';
import 'package:fluent_ui/fluent_ui.dart';


mixin ChatProviderOverlayMixin on ChangeNotifier, ChatProviderBaseMixin {
  /// Used to show the container with the answer only to one single message
  OverlayEntry? _overlayEntry;

  void closeQuickOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> sendToQuickOverlay(String title, String prompt) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tokens = await countTokensString(prompt);
    final messageToSend = FluentChatMessage.humanText(
      id: '$timestamp',
      content: prompt,
      timestamp: timestamp,
      creator: AppCache.userName.value!,
      tokens: tokens,
    );
    _overlayEntry?.remove();
    // var posX = mouseLocalPosition.dx;
    var posY = mouseLocalPosition.dy;
    final screen = MediaQuery.sizeOf(context!); // '1920x1080'
    // final screenX = double.parse(screen.first);
    // ensure we don't go out of the screen
    // if (posX + 400 > screenX) {
    //   posX = screenX - 400;
    // }
    if (posY + 200 > screen.height) {
      posY = screen.height - 200;
    }
    final overlay = OverlayEntry(
      builder: (context) => CommandRequestAnswerOverlay(
        message: messageToSend,
        initPosTop: posY,
        // ignore it for now, because it will be near message anyway
        initPosLeft: 64,
        screenSize: MediaQuery.of(context).size,
      ),
    );
    _overlayEntry = overlay;
    Overlay.of(context!).insert(overlay);
  }
}

