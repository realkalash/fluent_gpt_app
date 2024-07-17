import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/fluent_icons_list.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class OverlaySettingsDialog extends StatefulWidget {
  const OverlaySettingsDialog({super.key});

  @override
  State<OverlaySettingsDialog> createState() => _OverlaySettingsDialogState();
}

class _OverlaySettingsDialogState extends State<OverlaySettingsDialog> {
  bool archivedOpened = false;
  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Custom prompts'),
      constraints: const BoxConstraints(maxWidth: 800),
      actions: [
        Button(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
      ],
      content: StreamBuilder(
          stream: customPrompts,
          builder: (context, snapshot) {
            return ListView(
              children: [
                for (var prompt in customPrompts.value)
                  _PromptListTile(
                    prompt: prompt,
                    isArchived: false,
                    isSubprompt: false,
                  ),
                ListTile(
                  leading: const Icon(FluentIcons.add_24_filled),
                  title: const Text('Add new prompt'),
                  onPressed: () {
                    final newPrompt = CustomPrompt(
                      id: customPrompts.value.length,
                      icon: FluentIcons.info_24_filled,
                      title: 'New prompt ${customPrompts.value.length}',
                      prompt: 'Prompt',
                      index: customPrompts.value.length,
                    );
                    final list = customPrompts.value.toList();
                    list.add(newPrompt);
                    customPrompts.add(list);
                  },
                ),
                Expander(
                  header: const Text('Archived prompts'),
                  initiallyExpanded: archivedOpened,
                  onStateChanged: (value) {
                    archivedOpened = value;
                  },
                  content: StreamBuilder(
                      stream: archivedPrompts,
                      builder: (context, snapshot) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var prompt in archivedPrompts.value)
                              _PromptListTile(
                                prompt: prompt,
                                isArchived: true,
                                isSubprompt: false,
                              ),
                          ],
                        );
                      }),
                ),
              ],
            );
          }),
    );
  }
}

class EditPromptDialog extends StatefulWidget {
  const EditPromptDialog({super.key, required this.prompt});
  final CustomPrompt prompt;
  @override
  State<EditPromptDialog> createState() => _EditPromptDialogState();
}

class _EditPromptDialogState extends State<EditPromptDialog> {
  late CustomPrompt item;
  final promptCtr = TextEditingController();
  final indexCtr = TextEditingController();
  final titleCtr = TextEditingController();
  @override
  void initState() {
    item = widget.prompt;
    promptCtr.text = item.prompt;
    indexCtr.text = item.index.toString();
    titleCtr.text = item.title;
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
                \${input} - the selected text''',
            style: TextStyle(fontSize: 12, color: Colors.blue),
          ),
          const SizedBox(height: 8),
          // icon dropdown
          const Text('Icon:'),
          DropDownButton(
            title: Icon(item.icon),
            items: [
              for (var icon in fluentIconsList)
                MenuFlyoutItem(
                  text: Icon(icon),
                  onPressed: () {
                    final newItem = item.copyWith(icon: icon);
                    updateItem(newItem, context);
                  },
                ),
            ],
          ),
          const Text('Title:'),
          TextBox(
            controller: titleCtr,
            placeholder: 'Title',
            onChanged: (value) {
              final newItem = item.copyWith(title: value);
              updateItem(newItem, context);
            },
          ),
          const Text('Index for sorting:'),
          TextBox(
            controller: indexCtr,
            placeholder: '0',
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final newItem = item.copyWith(index: int.tryParse(value));
              updateItem(newItem, context);
            },
          ),
          const SizedBox(height: 8),
          const Text('Prompt:'),
          TextBox(
            controller: promptCtr,
            placeholder: 'Prompt',
            maxLines: 20,
            minLines: 1,
            onChanged: (value) {
              final newItem = item.copyWith(prompt: value);
              updateItem(newItem, context);
            },
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () {
            Navigator.of(context).pop(widget.prompt);
          },
          child: const Text('Close'),
        ),
        Button(
          onPressed: () {
            final lenght = calcAllPromptsLenght();
            item = item.copyWith(
              children: [
                ...item.children,
                CustomPrompt(
                  id: lenght,
                  icon: FluentIcons.info_24_filled,
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
            Navigator.of(context).pop(item);
          },
          child: const Text('Apply'),
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

class _PromptListTile extends StatelessWidget {
  const _PromptListTile({
    super.key,
    required this.prompt,
    required this.isArchived,
    required this.isSubprompt,
  });
  final CustomPrompt prompt;
  final bool isArchived;
  final bool isSubprompt;
  void updateItem(CustomPrompt item, CustomPrompt oldItem) {
    final list = (isArchived ? archivedPrompts : customPrompts).value.toList();

    if (isSubprompt) {
      final index = list.indexWhere(
          (element) => element.children.any((child) => child.id == oldItem.id));
      if (index != -1) {
        final parentItem = list[index];
        final updatedChildren = parentItem.children
            .where((child) => child.id != oldItem.id)
            .toList()
          ..add(item);
        list[index] = parentItem.copyWith(children: updatedChildren);
      }
    } else {
      list.removeWhere((element) => element.id == oldItem.id);
      list.add(item);
    }

    list.sort((a, b) => a.index.compareTo(b.index));
    (isArchived ? archivedPrompts : customPrompts).add(list);
  }

  showEditItemDialog(CustomPrompt item, BuildContext context) async {
    final prompt = await showDialog<CustomPrompt?>(
      context: context,
      builder: (context) => EditPromptDialog(prompt: item),
    );
    if (prompt != null) {
      // ignore: use_build_context_synchronously
      updateItem(prompt, item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(prompt.icon),
      title: Text(prompt.title),
      onPressed: () => showEditItemDialog(prompt, context),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt.prompt,
            style: FluentTheme.of(context).typography.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (prompt.children.isNotEmpty)
            Expander(
              header: const Text('Sub-prompts'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var child in prompt.children)
                    _PromptListTile(
                      prompt: child,
                      isArchived: isArchived,
                      isSubprompt: true,
                    ),
                  // add new sub-prompt
                  ListTile(
                    leading: const Icon(FluentIcons.add_24_filled),
                    title: const Text('Add new sub-prompt'),
                    onPressed: () {
                      final lenght = calcAllPromptsLenght();
                      final newPrompt = CustomPrompt(
                        id: lenght,
                        icon: FluentIcons.info_24_filled,
                        title: 'New sub-prompt $lenght',
                        prompt: 'Sub-prompt',
                        index: customPrompts.value.length,
                      );
                      final list = customPrompts.value.toList();
                      list.remove(prompt);
                      list.add(prompt.copyWith(
                        children: [...prompt.children, newPrompt],
                      ));
                      customPrompts.add(list);
                    },
                  ),
                ],
              ),
            )
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(
                  checked: prompt.showInChatField,
                  onChanged: (value) {
                    final newPrompt = prompt.copyWith(showInChatField: value!);
                    updateItem(newPrompt, prompt);
                  },
                ),
                const Text('Chat field', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
          SizedBox.square(
            dimension: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(
                  checked: prompt.showInOverlay,
                  onChanged: (value) {
                    final newPrompt = prompt.copyWith(showInOverlay: value!);
                    updateItem(newPrompt, prompt);
                  },
                ),
                const Text('Overlay', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
          Tooltip(
            message: isArchived == false
                ? 'Archive this prompt'
                : 'Unarchive this prompt',
            child: IconButton(
              icon: Icon(FluentIcons.archive_24_filled, color: Colors.red),
              onPressed: () {
                if (isArchived) {
                  final list = archivedPrompts.value.toList();
                  list.remove(prompt);
                  archivedPrompts.add(list);
                  customPrompts.add([...customPrompts.value, prompt]);
                } else {
                  final list = customPrompts.value.toList();
                  list.removeWhere((element) {
                    if (element.children.isNotEmpty) {
                      element.children.removeWhere((element) {
                        return element.id == prompt.id;
                      });
                    }
                    return element.id == prompt.id;
                  });
                  customPrompts.add(list);
                  archivedPrompts.add([...archivedPrompts.value, prompt]);
                }
              },
            ),
          ),
          if (isArchived)
            Tooltip(
              message: 'Delete this prompt',
              child: IconButton(
                icon: Icon(FluentIcons.delete_24_filled, color: Colors.red),
                onPressed: () {
                  final list = archivedPrompts.value.toList();
                  list.remove(prompt);
                  archivedPrompts.add(list);
                },
              ),
            ),
        ],
      ),
    );
  }
}
