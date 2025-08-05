import 'package:fluent_gpt/common/llm_model_common.dart';
import 'package:fluent_gpt/dialogs/models_list_dialog.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/widgets/custom_list_tile.dart';
import 'package:fluent_gpt/widgets/text_link.dart';
import 'package:fluent_ui/fluent_ui.dart';

class ChooseHfModelDialog extends StatefulWidget {
  const ChooseHfModelDialog({super.key});

  @override
  State<ChooseHfModelDialog> createState() => _ChooseHfModelDialogState();
}

class _ChooseHfModelDialogState extends State<ChooseHfModelDialog> {
  List<LlmModelCommon> models = [];

  @override
  void initState() {
    super.initState();
    models = LlmModelCommonUtils.getModels();
  }
  String bytesToGB(int bytes) {
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final cardColor = theme.cardColor;
    return ContentDialog(
      title: Text('Choose model'.tr),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('privacy_download_hf_models'.tr, style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(178))),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: models.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(4.0)),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: BasicListTile(
                      color: cardColor,
                      padding: EdgeInsets.all(4),
                      title: Text.rich(TextSpan(children: [
                        TextSpan(text: models[index].modelName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        WidgetSpan(
                            child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 4),
                            if (models[index].imageSupported) IconImagesSupported(),
                            if (models[index].reasoningSupported) IconReasoningSupported(),
                            if (models[index].toolSupported) IconToolsSupported(),
                          ],
                        ))
                      ])),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(models[index].modelDescription, style: TextStyle(fontSize: 12)),
                          if (models[index].minMemoryUsageBytes != null)
                            Text('Min memory usage: ${bytesToGB(models[index].minMemoryUsageBytes!)}', style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(178))),
                          LinkTextButton(models[index].modelUri),
                        ],
                      ),
                      onTap: () => Navigator.of(context).pop(models[index]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        Button(
          child: Text('Cancel'.tr),
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ],
    );
  }
}
