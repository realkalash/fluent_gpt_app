import 'package:fluent_gpt/common/cost_calculator.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher_string.dart';

class CostCalcDialog extends StatefulWidget {
  const CostCalcDialog(
      {super.key, required this.receivedTokens, required this.sentTokens});
  final int receivedTokens;
  final int sentTokens;

  @override
  State<CostCalcDialog> createState() => _CostCalcDialogState();
}

class _CostCalcDialogState extends State<CostCalcDialog> {
  final pricePer1MSent = 1;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _controllerPriceSent = TextEditingController();
  final pricePer1MReceived = 1;
  final TextEditingController _controllerPriceReceived =
      TextEditingController();

  int sentTokens = 0;
  int receivedTokens = 0;

  @override
  void initState() {
    super.initState();
    // _controllerPriceSent.text = widget.sentTokens.toString();
    // _controllerPriceReceived.text = widget.receivedTokens.toString();
    _controllerPriceSent.text = AppCache.pricePer1MSent.value!;
    _controllerPriceReceived.text = AppCache.pricePer1MReceived.value!;
    _notesController.text = AppCache.costCalcNotes.value!;
    sentTokens = widget.sentTokens;
    receivedTokens = widget.receivedTokens;
  }

  @override
  Widget build(BuildContext context) {
    final sentCost = CostCalculator.calculateCostPer1MToken(
        widget.sentTokens, double.tryParse(_controllerPriceSent.text) ?? 0);
    final receivedCost = CostCalculator.calculateCostPer1MToken(
        widget.receivedTokens,
        double.tryParse(_controllerPriceReceived.text) ?? 0);
    final totalCost = sentCost + receivedCost;
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
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Price per 1M sent tokens (input):'),
                            TextBox(
                              controller: _controllerPriceSent,
                              placeholder: '1',
                              onChanged: (value) {
                                AppCache.pricePer1MSent.value = value;
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Price per 1M received tokens (output):'),
                            TextBox(
                              controller: _controllerPriceReceived,
                              placeholder: '1',
                              onChanged: (value) {
                                AppCache.pricePer1MReceived.value = value;
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Divider(),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Tokens: $sentTokens'
                            '\nCost: \$${sentCost.toStringAsFixed(3)}'),
                      ),
                      Expanded(
                        child:
                            Text(
                              'Tokens: $receivedTokens'
                              '\nCost: \$${receivedCost.toStringAsFixed(3)}'),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: const Divider(),
                  ),
                  // Text('Total cost for this chat: \$${totalCost.toStringAsFixed(3)}'),
                  Text.rich(
                    TextSpan(
                      text: 'Total cost for this chat: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                          text: '\$${totalCost.toStringAsFixed(3)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Colors.green.basedOnLuminance(
                                darkColor: Colors.green.darker,
                                lightColor: Colors.green.lighter,
                              )),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          spacer,
          TextBox(
            controller: _notesController,
            placeholder: 'Your notes',
            minLines: 1,
            maxLines: 50,
            onChanged: (v) {
              AppCache.costCalcNotes.value = v;
            },
          ),
          spacer,
          StreamBuilder(
            stream: selectedChatRoomIdStream,
            builder: (context, snapshot) {
              final chatModel = selectedModel.getChatModelProviderBase();
              return Text.rich(
                TextSpan(
                  text: 'Price sheet: ',
                  children: [
                    TextSpan(
                      text: chatModel.priceUrl,
                      mouseCursor: SystemMouseCursors.click,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => launchUrlString(chatModel.priceUrl!),
                      style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
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
