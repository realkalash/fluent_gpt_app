import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons, SelectableRegion;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:fluent_gpt/widgets/custom_selectable_region.dart';
import 'package:provider/provider.dart';
import 'package:spell_check_on_client/spell_check_on_client.dart';

class ContextMenuBuilders {
  static String? previousClipboardData;
  static String selectedText = '';

  static Widget spellCheckContextMenuBuilder(BuildContext context, EditableTextState editableTextState) {
    final chatProvider = context.read<ChatProvider>();
    final undoController = editableTextState.widget.undoController;
    final correctSpell = AppCache.useLocalSpellCheck.value == true
        ? chatProvider.spellCheck?.isCorrect(editableTextState.textEditingValue.text)
        : null;
    Map<String, String> listSuggestions = {};
    List<String> unknownWords = [];
    if (correctSpell == false) {
      final List<String> words = WordTokenizer.tokenize(editableTextState.textEditingValue.text);

      if (words.isNotEmpty) {
        int currentIndex = 0;

        for (final String word in words) {
          // Find the word's position in the original text
          final int wordStartIndex = editableTextState.textEditingValue.text.indexOf(word, currentIndex);

          if (wordStartIndex == -1) {
            // Word not found, skip
            continue;
          }

          // Check if the word is spelled correctly
          final bool isCorrect = chatProvider.spellCheck?.isCorrect(word.toLowerCase()) ?? false;

          if (!isCorrect) {
            // Get suggestions for the misspelled word
            final List<String> suggestions = chatProvider.spellCheck?.didYouMeanAny(word, maxWords: 5) ?? [];

            if (suggestions.isNotEmpty) {
              unknownWords.add(word);
              // listSuggestions[word] = suggestions.first;
              for (final suggestion in suggestions) {
                listSuggestions['$word -> $suggestion'] = suggestion;
              }
            }
          }

          currentIndex = wordStartIndex + word.length;
        }
      }
    }

    return FluentTextSelectionToolbar(
      buttonItems: [
        if (correctSpell == false)
          ...listSuggestions.entries.map((entry) => ContextMenuButtonItem(
                label: entry.key,
                onPressed: () {
                  editableTextState.hideToolbar(false);
                  final text = editableTextState.textEditingValue.text;
                  final newText = text.replaceAll(entry.key.split(' -> ').first, entry.value);
                  editableTextState.userUpdateTextEditingValue(
                      TextEditingValue(text: newText), SelectionChangedCause.toolbar);
                },
              )),
        ...unknownWords.map((word) => ContextMenuButtonItem(
              label: '${'Add to dictionary'.tr} $word',
              onPressed: () {
                editableTextState.hideToolbar(false);
                chatProvider.addWordToDictionary(word, AppCache.locale.value ?? 'en');
              },
            )),
        ...editableTextState.contextMenuButtonItems,
        if (undoController != null)
          UndoContextMenuButtonItem(
            onPressed: () => undoController.undo(),
          ),
      ],
      anchors: editableTextState.contextMenuAnchors,
    );
  }

  static Widget defaultContextMenuBuilder(BuildContext context, EditableTextState editableTextState) {
    return AdaptiveTextSelectionToolbar.editableText(
      editableTextState: editableTextState,
    );
  }

  static Widget textChatMessageContextMenuBuilder(
    BuildContext context,
    EditableTextState editableTextState, {
    required void Function() onMorePressed,
    required void Function(String text) onShowCommandsPressed,
    required void Function(String text) onImproveSelectedText,
    required void Function(String text) onQuoteSelectedText,
  }) {
    final anchor = editableTextState.contextMenuAnchors.primaryAnchor;
    final fullText = editableTextState.textEditingValue.text;
    selectedText = editableTextState.textEditingValue.selection.textInside(fullText);

    return Stack(
      children: [
        Positioned(
          top: anchor.dy,
          left: anchor.dx,
          child: FlyoutContent(
            useAcrylic: false,
            constraints: BoxConstraints(maxWidth: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (selectedText.isNotEmpty)
                  FlyoutListTile(
                    text: Text('Copy'.tr),
                    icon: Icon(FluentIcons.copy_16_regular),
                    autofocus: true,
                    onPressed: () {
                      editableTextState.copySelection(SelectionChangedCause.tap);
                      editableTextState.hideToolbar();
                    },
                  ),
                FlyoutListTile(
                  text: Text('Select all'.tr),
                  icon: Icon(FluentIcons.select_object_skew_20_regular),
                  onPressed: () {
                    editableTextState.selectAll(SelectionChangedCause.tap);
                    editableTextState.hideToolbar();
                  },
                ),
                if (selectedText.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Divider(),
                  ),
                  FlyoutListTile(
                    text: Text('${'Improve'.tr} "$selectedText"', maxLines: 1, overflow: TextOverflow.ellipsis),
                    icon: Icon(FluentIcons.sparkle_16_regular),
                    onPressed: () {
                      onImproveSelectedText(selectedText);
                      _updateSelectedText(editableTextState, fullText);
                      editableTextState.hideToolbar();
                    },
                  ),
                  FlyoutListTile(
                    text: Text('${'Quote'.tr} "$selectedText"', maxLines: 1, overflow: TextOverflow.ellipsis),
                    icon: Icon(FluentIcons.arrow_reply_16_regular),
                    onPressed: () {
                      onQuoteSelectedText(selectedText);
                      _updateSelectedText(editableTextState, fullText);
                      editableTextState.hideToolbar();
                    },
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Divider(),
                ),
                FlyoutListTile(
                  text: Text('Commands'.tr),
                  trailing: Icon(FluentIcons.more_vertical_20_regular),
                  onPressed: () {
                    onShowCommandsPressed(selectedText);
                    editableTextState.hideToolbar();
                  },
                ),
                FlyoutListTile(
                  text: Text('More'.tr),
                  trailing: Icon(FluentIcons.more_vertical_20_regular),
                  onPressed: () {
                    onMorePressed();
                    editableTextState.hideToolbar();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Divider(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static void _updateSelectedText(EditableTextState editableTextState, String fullText) {
    editableTextState.userUpdateTextEditingValue(TextEditingValue(text: fullText), SelectionChangedCause.toolbar);
  }

  static Widget markdownChatMessageContextMenuBuilder(
    BuildContext context,
    FlyoutController flyoutController,
    CustomSelectableRegionState editableTextState, {
    required void Function() onMorePressed,
    required void Function(String text) onShowCommandsPressed,
    required void Function(String text) onImproveSelectedText,
    required void Function(String text) onQuoteSelectedText,
  }) {
    final anchor = editableTextState.contextMenuAnchors.primaryAnchor;
    selectedText = editableTextState.currentSelectable?.getSelectedContent()?.plainText ?? '';
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned(
          top: anchor.dy,
          left: anchor.dx,
          child: FlyoutContent(
            useAcrylic: false,
            constraints: BoxConstraints(maxWidth: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (editableTextState.copyEnabled)
                  FlyoutListTile(
                    text: Text('Copy'.tr),
                    icon: Icon(FluentIcons.copy_16_regular),
                    autofocus: true,
                    onPressed: () {
                      editableTextState.copySelection(SelectionChangedCause.tap);
                      editableTextState.hideToolbar();
                    },
                  ),
                FlyoutListTile(
                  text: Text('Select all'.tr),
                  icon: Icon(FluentIcons.select_object_skew_20_regular),
                  onPressed: () {
                    editableTextState.selectAll(SelectionChangedCause.tap);
                    editableTextState.hideToolbar();
                  },
                ),
                if (selectedText.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Divider(),
                  ),
                  FlyoutListTile(
                    text: Text('${'Improve'.tr} "$selectedText"', maxLines: 1, overflow: TextOverflow.ellipsis),
                    icon: Icon(FluentIcons.sparkle_16_regular),
                    onPressed: () {
                      onImproveSelectedText(selectedText);

                      editableTextState.hideToolbar();
                    },
                  ),
                  FlyoutListTile(
                    text: Text('${'Quote'.tr} "$selectedText"', maxLines: 1, overflow: TextOverflow.ellipsis),
                    icon: Icon(FluentIcons.arrow_reply_16_regular),
                    onPressed: () {
                      onQuoteSelectedText(selectedText);
                      editableTextState.hideToolbar();
                    },
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Divider(),
                ),
                FlyoutListTile(
                  text: Text('Commands'.tr),
                  trailing: Icon(FluentIcons.chevron_right_20_regular),
                  onPressed: () {
                    onShowCommandsPressed(selectedText);
                    editableTextState.hideToolbar();
                  },
                ),
                FlyoutListTile(
                  text: Text('More'.tr),
                  trailing: Icon(FluentIcons.more_vertical_20_regular),
                  onPressed: () {
                    onMorePressed();
                    editableTextState.hideToolbar();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
    // return flyoutController.showFlyout(
    //   dismissOnPointerMoveAway: true,
    //   dismissWithEsc: true,
    //   barrierDismissible: true,
    //   navigatorKey: navigatorKey.currentState,
    //   position: anchor,
    //   builder: (ctx) {
    //     return MenuFlyout(constraints: BoxConstraints(maxWidth: 200), items: [
    //       if (editableTextState.copyEnabled)
    //         MenuFlyoutItem(
    //           text: Text('Copy'),
    //           leading: Icon(FluentIcons.copy_16_regular),
    //           onPressed: () {
    //             editableTextState.copySelection(SelectionChangedCause.tap);
    //             editableTextState.hideToolbar();
    //           },
    //         ),
    //       MenuFlyoutItem(
    //         text: Text('Select all'),
    //         leading: Icon(FluentIcons.select_object_skew_20_regular),
    //         onPressed: () {
    //           editableTextState.selectAll(SelectionChangedCause.tap);
    //           editableTextState.hideToolbar();
    //         },
    //       ),
    //       if (selectedText.isNotEmpty) ...[
    //         MenuFlyoutSeparator(),
    //         MenuFlyoutItem(
    //           text: Text('Improve "$selectedText"',
    //               maxLines: 1, overflow: TextOverflow.ellipsis),
    //           leading: Icon(FluentIcons.sparkle_16_regular),
    //           onPressed: () {
    //             onImproveSelectedText(selectedText);

    //             editableTextState.hideToolbar();
    //           },
    //         ),
    //         MenuFlyoutItem(
    //           text: Text('Quote "$selectedText"',
    //               maxLines: 1, overflow: TextOverflow.ellipsis),
    //           leading: Icon(FluentIcons.arrow_reply_16_regular),
    //           onPressed: () {
    //             onQuoteSelectedText(selectedText);
    //             editableTextState.hideToolbar();
    //           },
    //         ),
    //       ],
    //       MenuFlyoutSeparator(),
    //       MenuFlyoutItem(
    //         text: Text('Commands'),
    //         trailing: Icon(FluentIcons.chevron_right_20_regular),
    //         onPressed: () {
    //           onShowCommandsPressed(selectedText);
    //           editableTextState.hideToolbar();
    //         },
    //       ),
    //       MenuFlyoutItem(
    //         text: Text('More'),
    //         trailing: Icon(FluentIcons.more_vertical_20_regular),
    //         onPressed: () {
    //           onMorePressed();
    //           editableTextState.hideToolbar();
    //         },
    //       ),
    //     ]);
    //   },
    // );
  }
}
