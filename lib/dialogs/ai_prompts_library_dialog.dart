// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/prompts_templates.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/pages/prompts_settings_page.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/confirmation_dialog.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:nanoid2/nanoid2.dart';

class AiPromptsLibraryDialog extends StatefulWidget {
  /// will return the selected [CustomPrompt] or null if the dialog is dismissed
  const AiPromptsLibraryDialog({super.key});

  @override
  State<AiPromptsLibraryDialog> createState() => _AiPromptsLibraryDialogState();
}

class _AiPromptsLibraryDialogState extends State<AiPromptsLibraryDialog> {
  List<CustomPrompt> prompts = [];
  bool isLoading = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await loadPrompts();
      if (mounted) setState(() {});
    });
  }

  Future loadPrompts() async {
    isLoading = true;
    if (mounted) setState(() {});
    try {
      final fileString = await AppCache.promptsLibrary.value();

      if (fileString.isEmpty) {
        prompts.addAll(promptsLibrary);
      } else {
        final decoded = jsonDecode(fileString) as List;
        prompts = decoded.map((e) => CustomPrompt.fromJson(e)).toList();
      }
      groups = prompts.expand((element) => element.tags).toSet().toList();
    } catch (e) {
      logError('Error loading prompts from file: $e');
    }

    isLoading = false;
    if (mounted) setState(() {});
  }

  Future savePrompts() async {
    final encoded = jsonEncode(prompts);
    await AppCache.promptsLibrary.set(encoded);
  }

  Future<void> resetSearch() async {
    prompts.clear();
    textController.clear();
    selectedGroup = '';
    await loadPrompts();
  }

  void fullResetToDefaultTemplate() async {
    final confirmed = await ConfirmationDialog.show(context: context);
    if (confirmed) {
      prompts.clear();
      prompts.addAll(promptsLibrary);
      await savePrompts();
      await loadPrompts();
    }
  }

  String selectedGroup = '';

  Future<void> searchByGroup(String group) async {
    await loadPrompts();
    prompts = prompts.where((element) => element.tags.contains(group)).toList();
    selectedGroup = group;
    setState(() {});
  }

  final textController = TextEditingController();
  List<String> groups = [];

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 1200),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextBox(
                  controller: textController,
                  expands: false,
                  minLines: 1,
                  maxLines: 1,
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(FluentIcons.search_20_regular, size: 20),
                  ),
                  suffix: IconButton(
                    icon: const Icon(FluentIcons.dismiss_20_regular, size: 20),
                    onPressed: () {
                      resetSearch();
                    },
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      resetSearch();
                    } else {
                      prompts = prompts.where((element) {
                        final isTitleContains = element.title
                            .toLowerCase()
                            .contains(value.toLowerCase());
                        final isPromptContains = element.prompt
                            .toLowerCase()
                            .contains(value.toLowerCase());
                        return isTitleContains || isPromptContains;
                      }).toList();
                    }
                    setState(() {});
                  },
                  placeholder: 'Search for a prompt',
                ),
              ),
              Button(
                onPressed: fullResetToDefaultTemplate,
                child: const Text('Reset to Default'),
              ),
            ],
          ),
          spacer,
          if (isLoading) ProgressBar(),
          Wrap(
            spacing: 4,
            children: groups
                .map(
                  (e) => ToggleButton(
                    checked: selectedGroup == e,
                    onChanged: (enable) {
                      if (enable)
                        searchByGroup(e);
                      else
                        resetSearch();
                    },
                    child: Text(e),
                  ),
                )
                .toList(),
          ),
          spacer,
          Expanded(
            child: ListView.builder(
              itemCount: prompts.length,
              itemBuilder: (context, index) {
                final item = prompts[index];
                return ListTile(
                  title: Text(item.title),
                  subtitle: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.prompt,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: context.theme.typography.caption,
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 4,
                          children: item.tags
                              .map((e) => Button(
                                    style: const ButtonStyle(
                                      padding: WidgetStatePropertyAll(
                                          EdgeInsets.all(4)),
                                    ),
                                    onPressed: () {},
                                    child: Text(e),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  leading: Icon(item.icon, size: 24),
                  trailing: Row(
                    children: [
                      IconButton(
                        icon: const Icon(FluentIcons.edit_20_regular, size: 24),
                        onPressed: () async {
                          final result = await showDialog(
                            context: context,
                            builder: (context) => EditPromptDialog(
                              allowKeybinding: false,
                              allowSubPrompts: false,
                              prompt: item,
                              autocompleteTagsList: groups,
                            ),
                          );
                          if (result is CustomPrompt) {
                            await resetSearch();
                            prompts[index] = result;
                            await savePrompts();
                            setState(() {});
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(FluentIcons.copy_20_regular, size: 24),
                        onPressed: () async {
                          await resetSearch();
                          final newPrompt = item.copyWith(
                            id: int.parse(
                                nanoid(alphabet: Alphabet.numbers, length: 10)),
                            title: '${item.title} 2',
                          );
                          prompts.insert(0, newPrompt);
                          groups = prompts
                              .expand((element) => element.tags)
                              .toSet()
                              .toList();
                          await savePrompts();
                          setState(() {});
                        },
                      ),
                      IconButton(
                        icon: Icon(FluentIcons.delete_20_filled,
                            size: 24, color: Colors.red),
                        onPressed: () => removePrompt(index),
                      ),
                    ],
                  ),
                  onPressed: () async {
                    final isContainsPlaceHolder =
                        placeholdersRegex.hasMatch(item.prompt);
                    // if not empty show new dialog with Wrap and TextBox for each placeholder
                    if (isContainsPlaceHolder) {
                      final newText = await showDialog<String>(
                        context: context,
                        builder: (context) => ReplaceAllPlaceHoldersDialog(
                          originalText: item.prompt,
                        ),
                      );
                      if (newText != null) {
                        final newItem = item.copyWith(prompt: newText);
                        Navigator.of(context).pop(newItem);
                      }
                    } else {
                      Navigator.of(context).pop(item);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => addNewPrompt(context),
          child: const Text('Add new'),
        ),
        Button(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Dismiss'),
        ),
      ],
    );
  }

  Future<void> addNewPrompt(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder: (context) => EditPromptDialog(
        allowKeybinding: false,
        allowSubPrompts: false,
        prompt: CustomPrompt(title: '', prompt: 'You are a helpful ai'),
        autocompleteTagsList: groups,
      ),
    );
    if (result is CustomPrompt && result.title.isNotEmpty) {
      if (textController.text.isNotEmpty || selectedGroup.isNotEmpty) {
        await resetSearch();
      }
      prompts.insert(
        0,
        result.copyWith(
            id: int.parse(nanoid(alphabet: Alphabet.numbers, length: 10))),
      );
      groups = prompts.expand((element) => element.tags).toSet().toList();
      await savePrompts();
      setState(() {});
    }
  }

  void removePrompt(int index) async {
    final confirmed = await ConfirmationDialog.show(context: context);
    if (confirmed) {
      await resetSearch();
      prompts.removeAt(index);
      await savePrompts();
      await loadPrompts();
    }
  }
}

final placeholdersRegex = RegExp(r'{(.*?)}');

class ReplaceAllPlaceHoldersDialog extends StatefulWidget {
  /// dialog with Wrap and TextBox for each placeholder. Will return new String with replaced placeholders
  const ReplaceAllPlaceHoldersDialog({super.key, required this.originalText});
  final String originalText;

  @override
  State<ReplaceAllPlaceHoldersDialog> createState() =>
      _ReplaceAllPlaceHoldersDialogState();
}

class _ReplaceAllPlaceHoldersDialogState
    extends State<ReplaceAllPlaceHoldersDialog> {
  String newText = '';
  @override
  void initState() {
    super.initState();
    newText = widget.originalText;
    for (final match in placeholdersRegex.allMatches(widget.originalText)) {
      final placeholder = match.group(1);
      placeholders[placeholder!] = '';
    }
  }

  /// original, value
  Map<String, String> placeholders = {};

  void submit() {
    for (final entry in placeholders.entries) {
      newText = newText.replaceAll('{${entry.key}}', entry.value);
    }
    Navigator.of(context).pop(newText);
  }

  @override
  Widget build(BuildContext context) {
    final words = newText.split(' ');
    return ContentDialog(
      title: const Text('Replace all placeholders'),
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 1200),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Text:'),
            subtitle: RichText(
                text: TextSpan(children: [
              for (final word in words)
                placeholdersRegex.hasMatch(word)
                    ? TextSpan(
                        text: '$word ',
                        style: TextStyle(
                          color: Colors.yellow,
                        ),
                      )
                    : TextSpan(text: '$word '),
            ])),
          ),
          Wrap(
            spacing: 4,
            children: [
              for (final placeholder in placeholders.keys)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 100,
                      child: TextBox(
                        autofocus: true,
                        minLines: 1,
                        maxLines: 1,
                        placeholder: placeholder,
                        onChanged: (value) {
                          placeholders[placeholder] = value;
                          setState(() {});
                        },
                        onSubmitted: (value) {
                          placeholders[placeholder] = value;
                          submit();
                        },
                      ),
                    ),
                    // tab text
                    Container(
                      width: 44,
                      decoration: BoxDecoration(
                        border: Border.all(color: context.theme.accentColor),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        children: [
                          const SizedBox(width: 4),
                          Text(
                            'tab',
                            style: TextStyle(
                                fontSize: 14, color: context.theme.accentColor),
                          ),
                          Icon(FluentIcons.arrow_right_24_regular,
                              size: 14, color: context.theme.accentColor),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () {
            Navigator.of(context).pop(null);
          },
          child: const Text('Dismiss'),
        ),
      ],
    );
  }
}
