import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart';

class ContextMenuBuilders {
  static Widget defaultContextMenuBuilder(
      BuildContext context, EditableTextState editableTextState) {
    return AdaptiveTextSelectionToolbar.editableText(
      editableTextState: editableTextState,
    );
  }

  static Widget textChatMessageContextMenuBuilder(
    BuildContext context,
    EditableTextState editableTextState,
    void Function() onMorePressed,
  ) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: [
        if (editableTextState.copyEnabled)
          ContextMenuButtonItem(
            label: 'Copy',
            type: ContextMenuButtonType.copy,
            onPressed: () {
              editableTextState.copySelection(SelectionChangedCause.tap);
              editableTextState.hideToolbar();
            },
          ),
        ContextMenuButtonItem(
          label: 'Select all',
          type: ContextMenuButtonType.selectAll,
          onPressed: () {
            editableTextState.selectAll(SelectionChangedCause.tap);
            editableTextState.hideToolbar();
          },
        ),
        ContextMenuButtonItem(
          label: 'More',
          type: ContextMenuButtonType.custom,
          onPressed: () {
            onMorePressed();
            editableTextState.hideToolbar();
          },
        ),
      ],
    );
  }

  static Widget markdownChatMessageContextMenuBuilder(
    BuildContext context,
    SelectableRegionState editableTextState,
    void Function() onMorePressed,
  ) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: [
        if (editableTextState.copyEnabled)
          ContextMenuButtonItem(
            label: 'Copy',
            type: ContextMenuButtonType.copy,
            onPressed: () {
              editableTextState.copySelection(SelectionChangedCause.tap);
              editableTextState.hideToolbar();
            },
          ),
        ContextMenuButtonItem(
          label: 'Select all',
          type: ContextMenuButtonType.selectAll,
          onPressed: () {
            editableTextState.selectAll(SelectionChangedCause.tap);
            editableTextState.hideToolbar();
          },
        ),
        ContextMenuButtonItem(
          label: 'More',
          type: ContextMenuButtonType.custom,
          onPressed: () {
            onMorePressed();
            editableTextState.hideToolbar();
          },
        ),
      ],
    );
  }
}
