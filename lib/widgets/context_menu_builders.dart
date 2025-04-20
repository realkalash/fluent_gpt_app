import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons, SelectableRegion;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:fluent_gpt/widgets/custom_selectable_region.dart';

class ContextMenuBuilders {
  static String? previousClipboardData;
  static String selectedText = '';

  static Widget defaultContextMenuBuilder(
      BuildContext context, EditableTextState editableTextState) {
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
    selectedText =
        editableTextState.textEditingValue.selection.textInside(fullText);

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
                      editableTextState
                          .copySelection(SelectionChangedCause.tap);
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
                    text: Text('${'Improve'.tr} "$selectedText"',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    icon: Icon(FluentIcons.sparkle_16_regular),
                    onPressed: () {
                      onImproveSelectedText(selectedText);
                      _updateSelectedText(editableTextState, fullText);
                      editableTextState.hideToolbar();
                    },
                  ),
                  FlyoutListTile(
                    text: Text('${'Quote'.tr} "$selectedText"',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
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

  static void _updateSelectedText(
      EditableTextState editableTextState, String fullText) {
    editableTextState.userUpdateTextEditingValue(
        TextEditingValue(text: fullText), SelectionChangedCause.toolbar);
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
    selectedText =
        editableTextState.currentSelectable?.getSelectedContent()?.plainText ?? '';
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
                      editableTextState
                          .copySelection(SelectionChangedCause.tap);
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
                    text: Text('${'Improve'.tr} "$selectedText"',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    icon: Icon(FluentIcons.sparkle_16_regular),
                    onPressed: () {
                      onImproveSelectedText(selectedText);

                      editableTextState.hideToolbar();
                    },
                  ),
                  FlyoutListTile(
                    text: Text('${'Quote'.tr} "$selectedText"',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
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
