import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/dialogs/models_list/models_list_body.dart';
import 'package:fluent_gpt/dialogs/models_list/add_ai_model_dialog.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';

class ModelsListDialog extends StatefulWidget {
  const ModelsListDialog({super.key});

  @override
  State<ModelsListDialog> createState() => _ModelsListDialogState();
}

class _ModelsListDialogState extends State<ModelsListDialog> {
  Future<void> _openAddDialog(
    BuildContext context,
    ChatProvider chatProvider,
  ) async {
    final isListWasEmpty = allModels.value.isEmpty;
    final model = await showDialog<ChatModelAi>(
      context: context,
      builder: (context) => const AddAiModelDialog(),
    );
    if (model != null) {
      await chatProvider.addNewCustomModel(model);
      if (isListWasEmpty) {
        chatProvider.selectNewModel(model);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    return ContentDialog(
      title: Row(
        children: [
          Text('Models List'.tr),
          const Spacer(),
          SqueareIconButton(
            onTap: () => _openAddDialog(context, chatProvider),
            icon: Icon(FluentIcons.add_24_filled),
            tooltip: 'Add'.tr,
          ),
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 640),
      content: ModelsListBody(
        chatProvider: chatProvider,
        onAddModel: () => _openAddDialog(context, chatProvider),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'.tr),
        ),
      ],
    );
  }
}
