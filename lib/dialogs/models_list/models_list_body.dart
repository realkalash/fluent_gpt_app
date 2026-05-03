import 'package:animated_list_plus/animated_list_plus.dart';
import 'package:animated_list_plus/transitions.dart';
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/dialogs/models_list/add_ai_model_dialog.dart';
import 'package:fluent_gpt/dialogs/models_list/widgets/model_row_tile.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/widgets/confirmation_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class ModelsListBody extends StatelessWidget {
  const ModelsListBody({
    super.key,
    required this.chatProvider,
    required this.onAddModel,
  });

  final ChatProvider chatProvider;
  final VoidCallback onAddModel;

  Future<void> _applyEdit(
    BuildContext context,
    ChatModelAi model,
    ChatModelAi? changedModel,
  ) async {
    if (changedModel == null) return;
    final isSelected = modelsListSameLogicalModel(model, selectedModel);
    chatProvider.removeCustomModel(model);
    chatProvider.addNewCustomModel(changedModel);
    if (isSelected) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      chatProvider.selectNewModel(changedModel);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatModelAi>>(
      stream: allModels.stream,
      initialData: allModels.value,
      builder: (context, snap) {
        final models = List<ChatModelAi>.from(snap.data ?? [])
          ..sort((a, b) => a.index.compareTo(b.index));

        if (models.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FluentIcons.bot_24_regular,
                  size: 48,
                  color: FluentTheme.of(context).inactiveColor,
                ),
                const SizedBox(height: 12),
                Text(
                  'No models yet'.tr,
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 6),
                Text(
                  'Add your first model to get started.'.tr,
                  textAlign: TextAlign.center,
                  style: FluentTheme.of(context).typography.caption,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onAddModel,
                  child: Text('Add model'.tr),
                ),
              ],
            ),
          );
        }

        return ImplicitlyAnimatedReorderableList<ChatModelAi>(
          shrinkWrap: true,
          items: models,
          areItemsTheSame: (oldItem, newItem) =>
              oldItem.modelName == newItem.modelName && oldItem.uri == newItem.uri,
          itemBuilder: (context, anim, item, index) {
            final model = models.length <= index ? item : models[index];
            final isActive = modelsListSameLogicalModel(model, selectedModel);
            return Reorderable(
              key: ValueKey('${model.modelName}_${model.index}_${model.uri}'),
              child: Handle(
                child: SizeFadeTransition(
                  animation: anim,
                  curve: Curves.easeInOut,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Icon(
                          FluentIcons.re_order_16_filled,
                          color: FluentTheme.of(context).inactiveColor,
                        ),
                      ),
                      Expanded(
                        child: ModelRowTile(
                          model: model,
                          isActive: isActive,
                          onEdit: () async {
                            final changed = await showDialog<ChatModelAi>(
                              context: context,
                              builder: (context) => AddAiModelDialog(initialModel: model),
                            );
                            if (!context.mounted) return;
                            await _applyEdit(context, model, changed);
                          },
                          onSelect: () {
                            chatProvider.selectNewModel(model);
                            Navigator.of(context).pop();
                          },
                          onDelete: () => showDialog<void>(
                            context: context,
                            builder: (ctx) => ConfirmationDialog(
                              message:
                                  'Delete this model from the list?'.tr,
                              isDelete: true,
                              onAcceptPressed: () => chatProvider.removeCustomModel(model),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          onReorderFinished:
              (ChatModelAi item, int from, int to, List<ChatModelAi> newItems) async {
            final updatedItems = <ChatModelAi>[];
            for (var i = 0; i < newItems.length; i++) {
              updatedItems.add(newItems[i].copyWith(index: i));
            }
            allModels.add(updatedItems);
            await chatProvider.saveModelsToDisk();
          },
        );
      },
    );
  }
}
