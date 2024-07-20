import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

extension ThemeExtension on BuildContext {
  FluentThemeData get theme => FluentTheme.of(this);
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
