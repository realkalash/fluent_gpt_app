import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:langchain/langchain.dart';
import 'package:nanoid2/nanoid2.dart';

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
