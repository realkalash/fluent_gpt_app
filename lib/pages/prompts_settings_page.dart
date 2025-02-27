import 'package:animated_list_plus/animated_list_plus.dart';
import 'package:animated_list_plus/transitions.dart';
import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/prompts_templates.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/confirmation_dialog.dart';
import 'package:fluent_gpt/widgets/custom_list_tile.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../widgets/custom_buttons.dart';
import 'edit_prompt_dialog.dart';

class CustomPromptsSettingsDialog extends StatelessWidget {
  const CustomPromptsSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Quick prompts'),
      constraints: const BoxConstraints(maxWidth: 800),
      actions: [
        Button(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
      ],
      content: CustomPromptsSettingsContainer(),
    );
  }
}

class CustomPromptsSettingsContainer extends StatelessWidget {
  const CustomPromptsSettingsContainer({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: customPrompts,
        initialData: customPrompts.valueOrNull,
        builder: (context, snap) {
          final customPromptsValue = snap.data ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 200,
                  child: FilledRedButton(
                    child: const Text('Reset to default template'),
                    onPressed: () async {
                      final accept = await ConfirmationDialog.show(
                          context: context, isDelete: true);
                      if (accept) {
                        const customTemplate = basePromptsTemplate;
                        const archivedTemplate = baseArchivedPromptsTemplate;
                        customPrompts.add(customTemplate);
                        archivedPrompts.add(archivedTemplate);
                      }
                    },
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Divider(),
              ),
              Expanded(
                child: ImplicitlyAnimatedReorderableList<CustomPrompt>(
                  items: customPromptsValue,
                  areItemsTheSame: (oldItem, newItem) =>
                      oldItem.index == newItem.index,
                  itemBuilder: (context, anim, item, index) {
                    item = customPromptsValue.length <= index
                        ? item
                        : customPromptsValue[index];
                    return Reorderable(
                      key: ValueKey('${item.id}-reorderable'),
                      child: SizeFadeTransition(
                        animation: anim,
                        curve: Curves.easeInOut,
                        child: Card(
                          backgroundColor:
                              context.theme.inactiveBackgroundColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Handle(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.theme.accentColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('${item.index}'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _PromptListTile(
                                  prompt: item,
                                  isArchived: false,
                                  isSubprompt: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  onReorderFinished: (CustomPrompt item, int from, int to,
                      List<CustomPrompt> newItems) async {
                    for (var i = 0; i < newItems.length; i++) {
                      newItems[i] = newItems[i].copyWith(index: i);
                    }
                    customPrompts.add(newItems);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(FluentIcons.add_24_filled),
                title: const Text('Add new prompt'),
                onPressed: () {
                  final lenght = calcAllPromptsLenght();
                  final newPrompt = CustomPrompt(
                    id: lenght,
                    iconCodePoint: FluentIcons.info_24_filled.codePoint,
                    title: 'New prompt $lenght',
                    prompt: 'Prompt',
                    index: lenght,
                  );
                  final list = customPromptsValue.toList();
                  list.add(newPrompt);
                  customPrompts.add(list);
                },
              ),
              Expander(
                header: const Text('Archived prompts'),
                content: StreamBuilder(
                    stream: archivedPrompts,
                    builder: (context, snapshot) {
                      return SizedBox(
                        height: 400,
                        child: SingleChildScrollView(
                          child: Column(
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
                          ),
                        ),
                      );
                    }),
              ),
            ],
          );
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
      //unbind old hotkey
      if (item.hotkey != null) {
        //// Causes a crash on windows
        final wasRegistered = hotKeyManager.registeredHotKeyList
            .any((element) => element == item.hotkey);
        if (wasRegistered) {
          await hotKeyManager.unregister(item.hotkey!);
        }

        /// wait native channel to finish
        await Future.delayed(const Duration(milliseconds: 200));
      }
      OverlayManager.bindHotkeys(customPrompts.value);
    }
  }

  void moveDown(CustomPrompt item) {
    final newItem = item.copyWith(index: item.index - 1);
    updateItem(newItem, item);
  }

  @override
  Widget build(BuildContext context) {
    return BasicListTile(
      leading:
          Padding(padding: const EdgeInsets.all(8.0), child: Icon(prompt.icon)),
      title: Text(
        prompt.title,
        style: FluentTheme.of(context).typography.bodyLarge,
      ),
      color: Colors.transparent,
      onTap: () => showEditItemDialog(prompt, context),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt.prompt,
            style: FluentTheme.of(context).typography.body,
            maxLines: 2,
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
                        iconCodePoint: FluentIcons.info_24_filled.codePoint,
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
            ),
          if (prompt.hotkey != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: HotKeyVirtualView(hotKey: prompt.hotkey!),
            ),
          Wrap(
            spacing: 4,
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
                        final newPrompt =
                            prompt.copyWith(showInChatField: value!);
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
                        final newPrompt =
                            prompt.copyWith(showInOverlay: value!);
                        updateItem(newPrompt, prompt);
                      },
                    ),
                    const Text('Overlay', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                width: 64,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      checked: prompt.showInContextMenu,
                      onChanged: (value) {
                        final newPrompt =
                            prompt.copyWith(showInContextMenu: value!);
                        updateItem(newPrompt, prompt);
                      },
                    ),
                    const Text('Context menu', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          IconButton(
            icon: const Icon(FluentIcons.arrow_down_24_filled),
            onPressed: () {
              moveDown(prompt);
            },
          ),
        ],
      ),
    );
  }
}
