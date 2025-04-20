import 'package:fluent_gpt/dialogs/ai_lens_dialog.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/widgets/confirmation_dialog.dart';
import 'package:fluent_gpt/widgets/custom_list_tile.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

class PinnedMessagesDialog extends StatelessWidget {
  const PinnedMessagesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final pinnedIndexes = pinnedMessagesIndexes;
    return ContentDialog(
      title: Text('Pinned Messages'.tr),
      constraints: const BoxConstraints(minWidth: 200,maxWidth: 800),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text('AI have access to pinned messages'.tr),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: pinnedIndexes.length,
              itemBuilder: (context, index) {
                final message = messagesReversedList[pinnedIndexes[index]];
                return HoverListTile(
                  cursor: SystemMouseCursors.click,
                  child: BasicListTile(
                    title: Text(message.content, style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold)),
                    color: Colors.transparent,
                    onTap: () async {
                      await Navigator.maybePop(context);
                      provider.scrollToMessage(message.id);
                    },
                    subtitle: Text(message.formatDate()),
                    trailing: IconButton(
                      icon: const Icon(FluentIcons.delete),
                      onPressed: () async {
                        final conf = await ConfirmationDialog.show(
                            context: context, isDelete: true);
                        if (conf == true) {
                          provider.unpinMessage(message.id);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        Button(
          child: Text('Close'.tr),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
