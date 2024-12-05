import 'dart:async';
import 'dart:math' hide log;

import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/features/notification_service.dart';
import 'package:fluent_gpt/features/text_to_speech.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

class AnnoyFeature {
  static Timer? timer;
  static Duration? chosenRandDuration;
  static Duration? lastChosenRandDuration;

  static DateTime? lastTimeAiAnswered;

  /// Will autostart autonomous mode if enabled in cache settings
  static void init() {
    if (AppCache.enableAutonomousMode.value == true) {
      start(
        Duration(minutes: AppCache.annoyModeTimerMinMinutes.value!),
        Duration(minutes: AppCache.annoyModeTimerMaxMinutes.value!),
      );
    }
  }

  static showConfigureDialog() async {
    final context = appContext!;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AnnoyConfigDialog(),
    );
  }

  static void start(Duration durationMin, Duration durationMax) {
    final range = durationMax.inMilliseconds - durationMin.inMilliseconds;
    // if the time is the same we should use only one value
    final randomDurationInMs = range == 0
        ? durationMin.inMilliseconds
        : Random().nextInt(range) + durationMin.inMilliseconds;
    chosenRandDuration = Duration(milliseconds: randomDurationInMs);
    log('Ai decided to write you in: ${chosenRandDuration!.inMinutes} minutes');
    stop();
    timer = Timer(chosenRandDuration!, () {
      log('Autonomous feature running');
      if (AppCache.enableAutonomousMode.value == true) {
        // restart timer
        triggerActions();
        start(durationMin, durationMax);
      }
    });
  }

  static void stop() {
    if (timer != null && timer!.isActive) {
      log('Autonomous feature stopped');
      timer?.cancel();
    }
  }

  static Future<void> triggerActions() async {
    log('Triggering actions');
    final chatProvider = appContext!.read<ChatProvider>();
    final diff =
        DateTime.now().difference(lastTimeAiAnswered ?? DateTime.now());
    String systemSuffix = '';
    if (messagesReversedList.isNotEmpty) {
      final lastMessages = chatProvider.convertMessagesToString([
        messagesReversedList.first,
        if (messagesReversedList.length > 1) messagesReversedList[1],
      ]);
      final lastChatMessage = messagesReversedList.first;
      systemSuffix = '\nlast messages in your conversation were: $lastMessages';
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
    await chatProvider.simulateAiTyping();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    var aiMessage = FluentChatMessage.ai(
      id: '$timestamp',
      content: aiMessageString,
      timestamp: timestamp,
      creator: selectedChatRoom.characterName,
    );
    final tokens = await chatProvider
        .getTokensFromMessages([aiMessage.toLangChainChatMessage()]);
    aiMessage = aiMessage.copyWith(tokens: tokens);

    chatProvider.addBotMessageToList(aiMessage);
    NotificationService.showNotification(
      'New message from ${aiMessage.creator}',
      aiMessage.content,
      thumbnailFilePath: selectedChatRoom.characterAvatarPath,
    );
    await Future.delayed(Duration(milliseconds: 300));
    if (AppCache.autoPlayMessagesFromAi.value!) {
      if (TextToSpeechService.isValid()) {
        await TextToSpeechService.readAloud(
          aiMessage.content,
          onCompleteReadingAloud: () {},
        );
      }
    }
  }
}

class AnnoyConfigDialog extends StatelessWidget {
  const AnnoyConfigDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text('Autonomous mode configuration'),
      actions: [
        FilledButton(
          onPressed: () {
            AppCache.enableAutonomousMode.value = true;
            AnnoyFeature.start(
              Duration(minutes: AppCache.annoyModeTimerMinMinutes.value!),
              Duration(minutes: AppCache.annoyModeTimerMaxMinutes.value!),
            );
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
          Text(
              'Ai can use your last open chat to generate new messages in random range between X and Y minutes.'),
          spacer,
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('Timer in minutes min: '),
                    SizedBox(
                      width: 100,
                      child: NumberBox(
                        min: 1,
                        max: 60 * 24,
                        mode: SpinButtonPlacementMode.none,
                        onChanged: (value) {
                          AppCache.annoyModeTimerMinMinutes.value = value;
                        },
                        value: AppCache.annoyModeTimerMinMinutes.value,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('Timer in minutes max '),
                    SizedBox(
                      width: 100,
                      child: NumberBox(
                        min: 1,
                        max: 60 * 24,
                        mode: SpinButtonPlacementMode.none,
                        onChanged: (value) {
                          AppCache.annoyModeTimerMaxMinutes.value = value;
                        },
                        value: AppCache.annoyModeTimerMaxMinutes.value,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          spacer,
          if (AnnoyFeature.chosenRandDuration != null) ...[
            Text(
              'Ai decided to write you after: ${AnnoyFeature.chosenRandDuration!.inMinutes} minutes',
            )
          ]
        ],
      ),
    );
  }
}
