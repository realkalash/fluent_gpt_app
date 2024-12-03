import 'dart:async';
import 'dart:developer';

import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/features/notification_service.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

class AutonomousFeature {
  static Timer? timer;
  static DateTime? lastTimeAiAnswered;

  static void init() {
    if (AppCache.enableAutonomousMode.value == true) {
      start(
          Duration(minutes: AppCache.enableAutonomousModeTimerMinutes.value!));
    }
  }

  static showConfigureDialog() async {
    final context = appContext!;
    await showDialog(
        context: context, builder: (context) => AutonomousConfigDialog());
  }

  static void start(Duration duration) {
    log('Autonomous feature started with duration: ${duration.inMinutes} minutes');
    timer = Timer.periodic(duration, (timer) {
      log('Autonomous feature running');
      if (AppCache.enableAutonomousMode.value == false) {
        timer.cancel();
      }
      triggerActions();
    });
  }

  static void stop() {
    log('Autonomous feature stopped');
    timer?.cancel();
  }

  static Future<void> triggerActions() async {
    log('Triggering actions');
    final chatProvider = appContext!.read<ChatProvider>();
    final diff =
        DateTime.now().difference(lastTimeAiAnswered ?? DateTime.now());
    String systemSuffix = '';
    if (messagesReversedList.isNotEmpty) {
      final lastChatMessage = messagesReversedList.first;
      systemSuffix = lastChatMessage.type == FluentChatMessageType.textHuman
          ? '\nlast message from User: ${lastChatMessage.content}'
          : '\nlast message from You: ${lastChatMessage.content}';
      lastTimeAiAnswered =
          DateTime.fromMillisecondsSinceEpoch(lastChatMessage.timestamp);
    }

    final baseSystemMessage =
        (selectedChatRoom.systemMessage ?? '') + systemSuffix;
    final additionalSuffix =
        '(You are messaging to user via phone after ${diff.inMinutes} minutes. Write short 1 sentence message. You can be bored/excited/angry/questioning/neutral/want to talk. Act as a person)';
    final aiMessageString = await chatProvider.retrieveResponseFromPrompt(
      additionalSuffix,
      systemMessage: baseSystemMessage,
    );
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    var aiMessage = FluentChatMessage.ai(
        id: '$timestamp', content: aiMessageString, timestamp: timestamp);
    final tokens = await chatProvider
        .getTokensFromMessages([aiMessage.toLangChainChatMessage()]);
    aiMessage = aiMessage.copyWith(tokens: tokens);

    chatProvider.addBotMessageToList(aiMessage);
    NotificationService.showNotification('New message', aiMessage.content);
  }
}

class AutonomousConfigDialog extends StatelessWidget {
  const AutonomousConfigDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text('Autonomous mode configuration'),
      actions: [
        FilledButton(
          onPressed: () {
            AppCache.enableAutonomousMode.value = true;
            AutonomousFeature.start(Duration(
                minutes: AppCache.enableAutonomousModeTimerMinutes.value!));
            Navigator.of(context).pop();
          },
          child: Text('Start'),
        ),
        Button(
          onPressed: () {
            AppCache.enableAutonomousMode.value = false;
            Navigator.of(context).pop();
          },
          child: Text('Close'),
        ),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ai can use your last open chat to generate new messages each X minutes'),
          spacer,
          Text('Timer in minutes: '),
          SizedBox(
            width: 100,
            child: NumberBox(
              min: 1,
              max: 60 * 24,
              mode: SpinButtonPlacementMode.none,
              onChanged: (value) {
                AppCache.enableAutonomousModeTimerMinutes.value = value;
              },
              value: AppCache.enableAutonomousModeTimerMinutes.value,
            ),
          ),
        ],
      ),
    );
  }
}
