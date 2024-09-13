import 'dart:io';

import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:intl/intl.dart';
import 'package:langchain/langchain.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:system_info2/system_info2.dart';

String generateChatID() => nanoid(length: 16);

extension ThemeExtension on BuildContext {
  FluentThemeData get theme => FluentTheme.of(this);
}

extension ChatMessageExtension on ChatMessage {
  Map<String, dynamic> toJson() {
    if (this is HumanChatMessage &&
        (this as HumanChatMessage).content is ChatMessageContentText) {
      final message = this as HumanChatMessage;
      return {
        'prefix': HumanChatMessage.defaultPrefix,
        'content': (message.content as ChatMessageContentText).text,
      };
    }
    if (this is HumanChatMessage &&
        (this as HumanChatMessage).content is ChatMessageContentImage) {
      final message = this as HumanChatMessage;
      return {
        'prefix': HumanChatMessage.defaultPrefix,
        'base64': (message.content as ChatMessageContentImage).data,
      };
    }
    // AI
    if (this is AIChatMessage) {
      final message = this as AIChatMessage;
      return {
        'prefix': AIChatMessage.defaultPrefix,
        'content': message.content,
      };
    }
    if (this is CustomChatMessage) {
      final message = this as CustomChatMessage;
      return {
        'prefix': message.role,
        'content': message.content,
      };
    }
    if (this is SystemChatMessage) {
      final message = this as SystemChatMessage;
      return {
        'prefix': SystemChatMessage.defaultPrefix,
        'content': message.content,
      };
    }

    throw Exception('Invalid content');
  }
}

/// hotkey extension to get string
extension HotKeyExtension on HotKey {
  String get hotkeyString {
    final key = logicalKey;
    final modifiers = <String>[];
    this.modifiers?.forEach((modifier) {
      modifiers.add(modifier.name);
    });
    return '${modifiers.join('+')}+${key.keyLabel}';
  }

  String get hotkeyShortString {
    final key = logicalKey;
    final modifiers = <String>[];
    this.modifiers?.forEach((modifier) {
      if (modifier == HotKeyModifier.control) {
        modifiers.add('Ctr');
      } else if (modifier == HotKeyModifier.shift) {
        modifiers.add('⇧');
      } else if (modifier == HotKeyModifier.meta) {
        modifiers.add('⌘');
      } else if (modifier == HotKeyModifier.alt) {
        modifiers.add(Platform.isMacOS ? '⌥' : 'Alt');
      } else {
        modifiers.add(modifier.name.substring(0, 1).toUpperCase());
      }
    });
    return '${modifiers.join('+')}+${key.keyLabel}';
  }
}

String getSystemInfoString() {
  final dateTime = DateTime.now();
  final formatter = DateFormat('yyyy-MM-dd HH:mm E');
  final formattedDate = formatter.format(dateTime);
  return '''OS: ${SysInfo.operatingSystemName}
Cores: ${SysInfo.cores.length}
kernel: ${SysInfo.rawKernelArchitecture}
KernelName: ${SysInfo.kernelName}
OS version: ${SysInfo.kernelVersion}
User directory: ${SysInfo.userDirectory}
User system id: ${SysInfo.userId}
User name in OS: ${SysInfo.userName}
Current date: $formattedDate
''';
}

Future<String> getFormattedSystemPrompt(
    {required String basicPrompt, String? appendText}) async {
  /// we append them line by line
  final userName = AppCache.userName.value;
  final systemInfo = getSystemInfoString();
  infoAboutUser = await AppCache.userInfo.value() ?? '';
  final userInfo = infoAboutUser;
  String prompt = basicPrompt;
  bool isIncludeAdditionalEnabled = AppCache.includeSysInfoToSysPrompt.value! ||
      AppCache.includeUserNameToSysPrompt.value! ||
      AppCache.includeKnowledgeAboutUserToSysPrompt.value!;
  if (isIncludeAdditionalEnabled) {
    prompt += '\n\nNext will be a contextual information about the user\n"""';
  }

  if (AppCache.includeSysInfoToSysPrompt.value!) {
    prompt += '\nSystem info for current: $systemInfo';
  }
  if (AppCache.includeUserNameToSysPrompt.value!) {
    prompt += '\nUser name: $userName';
  }
  if (AppCache.includeKnowledgeAboutUserToSysPrompt.value!) {
    prompt +=
        '\n\nKnowladge base you remembered from previous dialogs: """$userInfo"""';
  }
  if (isIncludeAdditionalEnabled) {
    prompt += '\n"""';
  }
  if (appendText != null) {
    prompt += '\n\n$appendText';
  }
  return prompt;
}
