import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/dialogs/icon_chooser_dialog.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/keybinding_dialog.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class EditPromptDialog extends StatefulWidget {
  const EditPromptDialog({
    super.key,
    required this.prompt,
    this.allowKeybinding = true,
    this.allowSubPrompts = true,
    this.autocompleteTagsList = const [],
  });
  final CustomPrompt prompt;
  final bool allowKeybinding;
  final bool allowSubPrompts;
  final List<String> autocompleteTagsList;
  @override
  State<EditPromptDialog> createState() => _EditPromptDialogState();
}

class _EditPromptDialogState extends State<EditPromptDialog> {
  late CustomPrompt item;
  final promptCtr = TextEditingController();
  final indexCtr = TextEditingController();
  final titleCtr = TextEditingController();
  final tagsCtr = TextEditingController();
  final List<String> tags = [];
  final autoSuggestOverlayController = GlobalKey<AutoSuggestBoxState>();
  @override
  void initState() {
    item = widget.prompt;
    promptCtr.text = item.prompt;
    indexCtr.text = item.index.toString();
    titleCtr.text = item.title;
    tags.addAll(item.tags);
    tagsCtr.text = tags.join(';');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Edit prompt'),
      constraints: const BoxConstraints(maxWidth: 600),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '''Helpers:
\${lang} - the language of the selected text
\${clipboardAccess} - if you want to enable the clipboard access for LLM
\${input} - the selected text''',
            style: TextStyle(fontSize: 12, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          // icon dropdown
          const Text('Icon:'),
          Button(
            child: Icon(item.icon),
            onPressed: () async {
              final icon = await IconChooserDialog.show(context);
              if (icon != null) {
                final newItem = item.copyWith(iconCodePoint: icon.codePoint);
                // ignore: use_build_context_synchronously
                updateItem(newItem, context);
              }
            },
          ),
          const Text('Title:'),
          TextBox(
            controller: titleCtr,
            placeholder: 'Title',
            suffix: ImproveTextSparkleButton(
              onTextImproved: (newText) {
                final clearText = newText.removeWrappedQuotes;
                titleCtr.text = clearText;
                final newItem = item.copyWith(title: clearText);
                updateItem(newItem, context);
              },
              input: () => promptCtr.text,
              customPromptToImprove:
                  'Generate a 3-5 words title based on this prompt: "{{input}}"',
            ),
            onChanged: (value) {
              final newItem = item.copyWith(title: value);
              updateItem(newItem, context);
            },
          ),
          const SizedBox(height: 8),
          const Text('Prompt:'),
          TextBox(
            controller: promptCtr,
            placeholder: 'Prompt',
            suffix: ImproveTextSparkleButton(
              input: () => promptCtr.text,
              onTextImproved: (improvedText) {
                promptCtr.text = improvedText;
                final newItem = item.copyWith(prompt: improvedText);
                updateItem(newItem, context);
              },
            ),
            maxLines: 20,
            minLines: 1,
            onChanged: (value) {
              final newItem = item.copyWith(prompt: value);
              updateItem(newItem, context);
            },
          ),
          const Text('Add data to prompt:'),
          Wrap(
            spacing: 4,
            children: [
              Button(
                child: const Text('User input'),
                onPressed: () {
                  final textCntr = promptCtr.text;
                  promptCtr.text = '''$textCntr\${input} ''';
                },
              ),
              Button(
                child: const Text('Current language'),
                onPressed: () {
                  final textCntr = promptCtr.text;
                  promptCtr.text = '''$textCntr\${lang} ''';
                },
              ),
              Button(
                child: const Text('Clipboard access'),
                onPressed: () {
                  final textCntr = promptCtr.text;
                  promptCtr.text = '''$textCntr\${clipboardAccess} ''';
                },
              ),
              Button(
                child: const Text('Info about user'),
                onPressed: () {
                  final textCntr = promptCtr.text;
                  promptCtr.text = '''$textCntr\${userInfo} ''';
                },
              ),
              Button(
                child: const Text('Timestamp'),
                onPressed: () {
                  final textCntr = promptCtr.text;
                  promptCtr.text = '''$textCntr\${timestamp} ''';
                },
              ),
              Button(
                child: const Text('System info'),
                onPressed: () {
                  final textCntr = promptCtr.text;
                  promptCtr.text = '''$textCntr\${systemInfo} ''';
                },
              ),
            ],
          ),
          spacer,
          Text('Tags (Use ; to separate tags)'),
          TextBox(
            controller: tagsCtr,
            placeholder: 'Tags',
            onChanged: (value) {
              final newTags = value.split(';');
              final newItem = item.copyWith(tags: newTags);
              updateItem(newItem, context);
            },
          ),
          SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var tag in widget.autocompleteTagsList)
                Button(
                  child: Text(tag),
                  onPressed: () {
                    final text = tagsCtr.text;
                    tagsCtr.text = text.isEmpty ? tag : '$text;$tag';
                    final newTags = tagsCtr.text.split(';');
                    final newItem = item.copyWith(tags: newTags);
                    updateItem(newItem, context);
                  },
                ),
            ],
          ),
          spacer,
          Wrap(
            children: [
              Tooltip(
                message:
                    'Do not show the main window after the prompt is run. The result will be shown in a push notification.\nUseful when you just want to copy the result to clipboard',
                child: CheckBoxTile(
                  isChecked: item.silentHideWindowsAfterRun,
                  onChanged: (p0) {
                    final newItem = item.copyWith(
                      silentHideWindowsAfterRun: p0 ?? true,
                    );
                    updateItem(newItem, context);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Silent'),
                      const SizedBox(width: 8),
                      const Icon(FluentIcons.info_24_filled),
                    ],
                  ),
                ),
              ),
              Tooltip(
                message:
                    'If checked, the prompt will include system prompt with each activation',
                child: CheckBoxTile(
                  isChecked: item.includeSystemPrompt,
                  onChanged: (p0) {
                    final newItem = item.copyWith(
                      includeSystemPrompt: p0 ?? true,
                    );
                    updateItem(newItem, context);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Include System Prompt'),
                      const SizedBox(width: 8),
                      const Icon(FluentIcons.info_24_filled),
                    ],
                  ),
                ),
              ),
              Tooltip(
                message:
                    'If checked, the prompt will include ALL messages from the conversation with each activation',
                child: CheckBoxTile(
                  isChecked: item.includeConversation,
                  onChanged: (p0) {
                    final newItem = item.copyWith(
                      includeConversation: p0 ?? true,
                    );
                    updateItem(newItem, context);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Include Conversation'),
                      const SizedBox(width: 8),
                      const Icon(FluentIcons.info_24_filled),
                    ],
                  ),
                ),
              ),
              CheckBoxTile(
                isChecked: item.showInChatField,
                onChanged: (p0) {
                  final newItem = item.copyWith(
                    showInChatField: p0 ?? true,
                  );
                  updateItem(newItem, context);
                },
                child: Text('Show in chat field'),
              ),
              CheckBoxTile(
                isChecked: item.showInContextMenu,
                onChanged: (p0) {
                  final newItem = item.copyWith(
                    showInContextMenu: p0 ?? true,
                  );
                  updateItem(newItem, context);
                },
                child: Text('Show in context menu'),
              ),
              CheckBoxTile(
                isChecked: item.showInHomePage,
                onChanged: (p0) {
                  final newItem = item.copyWith(
                    showInHomePage: p0 ?? true,
                  );
                  updateItem(newItem, context);
                },
                child: Text('Show in home page'),
              ),
              CheckBoxTile(
                isChecked: item.showInOverlay,
                onChanged: (p0) {
                  final newItem = item.copyWith(
                    showInOverlay: p0 ?? true,
                  );
                  updateItem(newItem, context);
                },
                child: Text('Show in overlay'),
              ),
            ],
          ),
          biggerSpacer,
          if (widget.allowKeybinding)
            Row(
              children: [
                const Text('Keybinding:'),
                const SizedBox(width: 8),
                Button(
                  onPressed: () async {
                    final hotkey = await KeybindingDialog.show(context);
                    final newItem = item.copyWith(hotkey: hotkey);
                    // ignore: use_build_context_synchronously
                    updateItem(newItem, context);
                  },
                  child: item.hotkey == null
                      ? const Text('Set keybinding')
                      : HotKeyVirtualView(hotKey: item.hotkey!),
                ),
                IconButton(
                  icon: const Icon(FluentIcons.delete_24_filled),
                  onPressed: () {
                    final newItem = item.copyWith(hotkey: null);
                    final wasRegistered = hotKeyManager.registeredHotKeyList
                        .any((element) => element == item.hotkey);
                    if (wasRegistered) {
                      hotKeyManager.unregister(item.hotkey!);
                    }

                    updateItem(newItem, context);
                  },
                ),
              ],
            ),
        ],
      ),
      actions: [
        Button(
          onPressed: () {
            Navigator.of(context).pop(item);
          },
          child: const Text('Apply'),
        ),
        if (widget.allowSubPrompts)
          Button(
            onPressed: () {
              final lenght = calcAllPromptsLenght();
              item = item.copyWith(
                children: [
                  ...item.children,
                  CustomPrompt(
                    id: lenght,
                    iconCodePoint: FluentIcons.info_24_filled.codePoint,
                    title: 'New sub-prompt $lenght',
                    prompt: 'Sub-prompt',
                    index: customPrompts.value.length,
                  ),
                ],
              );
              Navigator.of(context).pop(item);
            },
            child: const Text('Add sub-prompt list'),
          ),
        Button(
          onPressed: () {
            Navigator.of(context).pop(widget.prompt);
          },
          child: const Text('Close'),
        ),
      ],
    );
  }

  void updateItem(CustomPrompt newItem, BuildContext context) {
    setState(() {
      item = newItem;
    });
  }
}
