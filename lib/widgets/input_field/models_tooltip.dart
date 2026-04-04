import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/widgets/custom_list_tile.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ModelsTooltipContainer extends StatelessWidget {
  const ModelsTooltipContainer({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: selectedChatRoomIdStream,
      builder: (context, snapshot) {
        final models = allModels.value;
        final selectedModel = selectedChatRoom.model;
        return SizedBox(
          width: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: models.length,
                  itemBuilder: (context, index) {
                    final model = models[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        BasicListTile(
                          padding: BasicListTile.defaultPadding,
                          leading: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: SizedBox.square(
                              dimension: 24,
                              child: model.modelIcon,
                            ),
                          ),
                          title: Text(model.customName),
                          // subtitle: Text(model.modelName),
                          trailing: selectedModel == model ? const Icon(ic.FluentIcons.checkmark_16_filled) : null,
                          color: Colors.transparent,
                        ),
                        // if not last element add divider
                        if (index < models.length - 1) const Divider(),
                      ],
                    );
                  },
                ),
              ),
              Icon(LucideIcons.mouse, size: 16),
            ],
          ),
        );
      },
    );
  }
}
