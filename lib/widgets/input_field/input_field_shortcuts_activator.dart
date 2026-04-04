import 'dart:io';

import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

class InputFieldShortcutsActivator {
  static Map<SingleActivator, VoidCallback> bindings(
    onShortcutPasteSilently,
    onShortcutPasteToField,
    onShortcutSearchPressed,
    onDigitPressed,
    arrowUpPressed,
    onShortcutCopyToThirdParty,
  ) =>
      {
        if (Platform.isMacOS) ...{
          const SingleActivator(LogicalKeyboardKey.keyU, alt: true): () =>
              onShortcutPasteSilently(FluentChatMessageType.textHuman),
          const SingleActivator(LogicalKeyboardKey.keyI, alt: true): () =>
              onShortcutPasteSilently(FluentChatMessageType.textAi),
          const SingleActivator(LogicalKeyboardKey.keyV, meta: true): onShortcutPasteToField,

          const SingleActivator(LogicalKeyboardKey.keyF, meta: true): onShortcutSearchPressed,
          // digits
          SingleActivator(LogicalKeyboardKey.digit1, meta: true): () => onDigitPressed(1),
          SingleActivator(LogicalKeyboardKey.digit2, meta: true): () => onDigitPressed(2),
          SingleActivator(LogicalKeyboardKey.digit3, meta: true): () => onDigitPressed(3),
          SingleActivator(LogicalKeyboardKey.digit4, meta: true): () => onDigitPressed(4),
          SingleActivator(LogicalKeyboardKey.digit5, meta: true): () => onDigitPressed(5),
          SingleActivator(LogicalKeyboardKey.digit6, meta: true): () => onDigitPressed(6),
          SingleActivator(LogicalKeyboardKey.digit7, meta: true): () => onDigitPressed(7),
          SingleActivator(LogicalKeyboardKey.digit8, meta: true): () => onDigitPressed(8),
          SingleActivator(LogicalKeyboardKey.digit9, meta: true): () => onDigitPressed(9),
          SingleActivator(LogicalKeyboardKey.arrowUp): arrowUpPressed,
        } else ...{
          const SingleActivator(LogicalKeyboardKey.keyU, alt: true): () =>
              onShortcutPasteSilently(FluentChatMessageType.textHuman),
          const SingleActivator(LogicalKeyboardKey.keyI, alt: true): () =>
              onShortcutPasteSilently(FluentChatMessageType.textAi),
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): onShortcutPasteToField,
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): onShortcutSearchPressed,
          // digits
          SingleActivator(LogicalKeyboardKey.digit1, control: true): () => onDigitPressed(1),
          SingleActivator(LogicalKeyboardKey.digit2, control: true): () => onDigitPressed(2),
          SingleActivator(LogicalKeyboardKey.digit3, control: true): () => onDigitPressed(3),
          SingleActivator(LogicalKeyboardKey.digit4, control: true): () => onDigitPressed(4),
          SingleActivator(LogicalKeyboardKey.digit5, control: true): () => onDigitPressed(5),
          SingleActivator(LogicalKeyboardKey.digit6, control: true): () => onDigitPressed(6),
          SingleActivator(LogicalKeyboardKey.digit7, control: true): () => onDigitPressed(7),
          SingleActivator(LogicalKeyboardKey.digit8, control: true): () => onDigitPressed(8),
          SingleActivator(LogicalKeyboardKey.digit9, control: true): () => onDigitPressed(9),
          SingleActivator(LogicalKeyboardKey.arrowUp): arrowUpPressed,
        },
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): onShortcutCopyToThirdParty,
      };
}
