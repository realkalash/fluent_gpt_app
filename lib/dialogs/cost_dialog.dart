import 'package:chatgpt_windows_flutter_app/common/cost_calculator.dart';
import 'package:chatgpt_windows_flutter_app/common/prefs/app_cache.dart';
import 'package:fluent_ui/fluent_ui.dart';

class CostDialog extends StatefulWidget {
  const CostDialog({super.key, required this.tokens});
  final int tokens;

  @override
  State<CostDialog> createState() => _CostDialogState();
}

class _CostDialogState extends State<CostDialog> {
  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Cost Calculator'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectionArea(
            selectionControls: fluentTextSelectionControls,
            child: Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cost per token for all models in current Chat:'),
                  ...CostCalculator.calculateCostPerTokenForAllModels(widget.tokens)
                      .entries
                      .map((entry) => Text(
                          '${entry.key}: \$${entry.value.toStringAsFixed(3)}')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total'),
                Text(
                    'Tokens used: ${AppCache.tokensUsedTotal.value ?? 0}'),
                Text('Cost: \$${AppCache.costTotal.value?.toStringAsFixed(3)}'),
                const SizedBox(height: 8),
                Button(
                    child: const Text('Delete total costs cache'),
                    onPressed: () {
                      AppCache.costTotal.value = 0.0;
                      AppCache.tokensUsedTotal.value = 0;
                      setState(() {
                        
                      });
                    }),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expander(
              header: const Text('Costs sheet'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cost per 1K tokens for all models:'),
                  for (final entry
                      in CostCalculator.pricePerThousendPromptToken.entries)
                    Text('${entry.key}: \$${entry.value}'),
                ],
              )),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
