import 'package:chatgpt_windows_flutter_app/common/cost_calculator.dart';
import 'package:fluent_ui/fluent_ui.dart';

class CostDialog extends StatelessWidget {
  const CostDialog({super.key, required this.tokens});
  final int tokens;
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
                  ...CostCalculator.calculateCostPerTokenForAllModels(tokens)
                      .entries
                      .map((entry) => Text(
                          '${entry.key}: \$${entry.value.toStringAsFixed(3)}')),
                ],
              ),
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
