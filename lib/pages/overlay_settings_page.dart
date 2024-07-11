import 'package:chatgpt_windows_flutter_app/common/custom_prompt.dart';
import 'package:chatgpt_windows_flutter_app/fluent_icons_list.dart';
import 'package:chatgpt_windows_flutter_app/overlay_manager.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class OverlaySettingsDialog extends StatelessWidget {
  const OverlaySettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Overlay settings'),
      constraints: const BoxConstraints(maxWidth: 800),
      actions: [
        Button(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
      ],
      content: ListView(
        children: [
          for (var prompt in customPrompts.value)
            _PromptListTile(prompt: prompt, isArchived: false),
          ListTile(
            leading: const Icon(FluentIcons.add_24_filled),
            title: const Text('Add new prompt'),
            onPressed: () {
              final newPrompt = CustomPrompt(
                icon: FluentIcons.info_24_filled,
                title: 'New prompt',
                prompt: 'Prompt',
                index: customPrompts.value.length,
              );
              final list = customPrompts.value.toList();
              list.add(newPrompt);
              customPrompts.add(list);
              Navigator.of(context).pop();
              showDialog(
                context: context,
                builder: (ctx) => const OverlaySettingsDialog(),
              );
            },
          ),
          Expander(
            header: const Text('Archived prompts'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var prompt in archivedPrompts.value)
                  _PromptListTile(prompt: prompt, isArchived: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptListTile extends StatelessWidget {
  const _PromptListTile({
    super.key,
    required this.prompt,
    required this.isArchived,
  });
  final CustomPrompt prompt;
  final bool isArchived;
  void updateItem(CustomPrompt item, CustomPrompt oldItem, ctx) {
    final list = customPrompts.value.toList();
    final foundedItem = list.where((e) => e == oldItem);
    if (foundedItem.isNotEmpty) {
      list.remove(foundedItem.first);
      list.add(item);
      list.sort((a, b) => a.index.compareTo(b.index));
      customPrompts.add(list);
    }
  }

  showEditItemDialog(CustomPrompt item, BuildContext context) {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (context) {
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
                        Navigator.of(context).pop();
                        updateItem(newItem, prompt, context);
                        showDialog(
                          context: context,
                          builder: (ctx) => const OverlaySettingsDialog(),
                        );
                      },
                    ),
                ],
              ),
              const Text('Title:'),
              TextBox(
                controller: TextEditingController(text: item.title),
                placeholder: 'Title',
                onChanged: (value) {
                  final newItem = item.copyWith(title: value);
                  updateItem(newItem, prompt, context);
                },
              ),
              const Text('Index for sorting:'),
              TextBox(
                controller: TextEditingController(text: item.index.toString()),
                placeholder: '0',
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final newItem = item.copyWith(index: int.tryParse(value));
                  updateItem(newItem, prompt, context);
                },
              ),
              const SizedBox(height: 8),
              const Text('Prompt:'),
              TextBox(
                controller: TextEditingController(text: item.prompt),
                placeholder: 'Prompt',
                maxLines: 20,
                minLines: 1,
                onChanged: (value) {
                  final newItem = item.copyWith(prompt: value);
                  updateItem(newItem, prompt, context);
                },
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (ctx) => const OverlaySettingsDialog(),
                );
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
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
                    _PromptListTile(prompt: child, isArchived: isArchived),
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
                    updateItem(newPrompt, prompt, context);
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
                    updateItem(newPrompt, prompt, context);
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
                  list.remove(prompt);
                  customPrompts.add(list);
                  archivedPrompts.add([...archivedPrompts.value, prompt]);
                }
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (ctx) => const OverlaySettingsDialog(),
                );
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
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    builder: (ctx) => const OverlaySettingsDialog(),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
