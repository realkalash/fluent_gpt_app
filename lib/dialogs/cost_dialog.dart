import 'package:fluent_gpt/common/cost_calculator.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher_string.dart';

class CostDialog extends StatefulWidget {
  const CostDialog(
      {super.key, required this.receivedTokens, required this.sentTokens});
  final int receivedTokens;
  final int sentTokens;

  @override
  State<CostDialog> createState() => _CostDialogState();
}

class _CostDialogState extends State<CostDialog> {
  final pricePer1MSent = 1;
  final TextEditingController _controllerPriceSent = TextEditingController();
  final pricePer1MReceived = 1;
  final TextEditingController _controllerPriceReceived =
      TextEditingController();

  int sentTokens = 0;
  int receivedTokens = 0;

  @override
  void initState() {
    super.initState();
    _controllerPriceSent.text = widget.sentTokens.toString();
    _controllerPriceReceived.text = widget.receivedTokens.toString();
    sentTokens = widget.sentTokens;
    receivedTokens = widget.receivedTokens;
  }

  @override
  Widget build(BuildContext context) {
    final sentCost = CostCalculator.calculateCostPer1MToken(
        widget.sentTokens, int.parse(_controllerPriceSent.text));
    final receivedCost = CostCalculator.calculateCostPer1MToken(
        widget.receivedTokens, int.parse(_controllerPriceReceived.text));
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
                        child: Text('Cost: \$${sentCost.toStringAsFixed(3)}'),
                      ),
                      Expanded(
                        child:
                            Text('Cost: \$${receivedCost.toStringAsFixed(3)}'),
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
                          style:  TextStyle(fontWeight: FontWeight.bold,fontSize: 24, color: Colors.green.basedOnLuminance(
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
          child: const Text('Close'),
        ),
      ],
    );
  }
}
