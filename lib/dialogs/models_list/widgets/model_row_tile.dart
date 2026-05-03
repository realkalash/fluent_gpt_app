import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/dialogs/models_list/capability_icons.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

bool modelsListSameLogicalModel(ChatModelAi a, ChatModelAi b) {
  return a.modelName == b.modelName && a.ownedBy == b.ownedBy && a.uri == b.uri;
}

String _truncateUrl(String? uri, {int max = 56}) {
  if (uri == null || uri.isEmpty) return '';
  if (uri.length <= max) return uri;
  return '${uri.substring(0, max - 1)}…';
}

/// One row in the models list: provider, names, truncated URL, capabilities, actions.
class ModelRowTile extends StatelessWidget {
  const ModelRowTile({
    super.key,
    required this.model,
    required this.isActive,
    required this.onEdit,
    required this.onSelect,
    required this.onDelete,
  });

  final ChatModelAi model;
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final providerName = model.getChatModelProviderBase().providerName;
    final uriShort = _truncateUrl(model.uri);
    final tooltipUri = model.uri ?? '';

    return Tooltip(
      message: tooltipUri.isEmpty ? providerName : '$providerName\n$tooltipUri',
      child: ListTile(
        leading: SizedBox.square(dimension: 28, child: model.modelIcon),
        title: Row(
          children: [
            Expanded(
              child: Text.rich(
                // model.customName.isNotEmpty ? model.customName : model.modelName,
                TextSpan(
                  children: [
                    TextSpan(text: model.customName.isNotEmpty ? model.customName : model.modelName),
                    TextSpan(
                      text: ' · $providerName',
                      style: theme.typography.caption?.copyWith(color: theme.inactiveColor),
                    ),
                    if (isActive)
                      WidgetSpan(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: theme.accentColor.withValues(alpha: 0.15),
                            borderRadius: const BorderRadius.all(Radius.circular(4)),
                          ),
                          child: Text(
                            'Active'.tr,
                            style: theme.typography.caption?.copyWith(
                              color: theme.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body?.copyWith(fontWeight: isActive ? FontWeight.w600 : FontWeight.w500),
              ),
            ),
          ],
        ),
        subtitle: Text(model.modelName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.typography.caption),
        onPressed: onEdit,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (model.imageSupported) const IconImagesSupported(),
            if (model.reasoningSupported) const IconReasoningSupported(),
            if (model.toolSupported) const IconToolsSupported(),
            if (model.imageSupported || model.reasoningSupported || model.toolSupported) const SizedBox(width: 6),
            FilledButton(onPressed: onSelect, child: Text('Select'.tr)),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Edit'.tr,
              child: IconButton(icon: const Icon(FluentIcons.edit_20_regular), onPressed: onEdit),
            ),
            Tooltip(
              message: 'Delete'.tr,
              child: IconButton(icon: const Icon(FluentIcons.delete_24_filled), onPressed: onDelete),
            ),
          ],
        ),
      ),
    );
  }
}
