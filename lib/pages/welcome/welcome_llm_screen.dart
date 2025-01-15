import 'package:fluent_gpt/dialogs/models_list_dialog.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_ui/fluent_ui.dart'
    show Button, FlyoutController, FlyoutTarget, MenuFlyout, MenuFlyoutItem;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:widget_and_text_animator/widget_and_text_animator.dart';

class WelcomeLLMConfigPage extends StatefulWidget {
  const WelcomeLLMConfigPage({super.key});

  @override
  State<WelcomeLLMConfigPage> createState() => _WelcomePermissionsPageState();
}

class _WelcomePermissionsPageState extends State<WelcomeLLMConfigPage> {
  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final provider = context.read<ChatProvider>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[900],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const TextAnimator(
                        'LLM',
                        initialDelay: Duration(milliseconds: 500),
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const TextAnimator(
                      'Configure your AI',
                      initialDelay: Duration(milliseconds: 1000),
                      characterDelay: Duration(milliseconds: 15),
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextAnimator(
                      'Configure your AI to work as you want.',
                      initialDelay: const Duration(milliseconds: 1500),
                      characterDelay: const Duration(milliseconds: 5),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 14),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(
                color: Colors.white,
                thickness: 1,
              ),
              Expanded(
                flex: 3,
                child: Card(
                  color: Colors.grey[900],
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ListTile(
                          title: Text('Add your models'),
                          trailing: _ChooseModelButton(),
                        ),
                        const SizedBox(height: 24),
                        Button(
                            child: Text('Add'),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => ModelsListDialog(),
                              );
                            })
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChooseModelButton extends StatefulWidget {
  const _ChooseModelButton({super.key});

  @override
  State<_ChooseModelButton> createState() => _ChooseModelButtonState();
}

class _ChooseModelButtonState extends State<_ChooseModelButton> {
  Widget getModelIcon(String model) {
    if (model.contains('gpt')) {
      return Image.asset(
        'assets/openai_icon.png',
        fit: BoxFit.contain,
      );
    }
    return const Icon(FluentIcons.chat_24_regular);
  }

  final FlyoutController flyoutController = FlyoutController();

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final ChatProvider provider = context.watch<ChatProvider>();
    return FlyoutTarget(
      controller: flyoutController,
      child: ElevatedButton.icon(
        onPressed: () => openFlyout(context),
        icon: SizedBox.square(
            dimension: 24, child: getModelIcon(selectedModel.modelName)),
        label: Text(selectedModel.modelName),
      ),
    );
  }

  void openFlyout(BuildContext context) {
    final provider = context.read<ChatProvider>();
    final models = allModels.value;
    final selectedModel = selectedChatRoom.model;
    flyoutController.showFlyout(builder: (ctx) {
      return MenuFlyout(
        items: models
            .map(
              (e) => MenuFlyoutItem(
                selected: e.modelName == selectedModel.modelName,
                trailing: e.modelName == selectedModel.modelName
                    ? const Icon(FluentIcons.checkmark_16_filled)
                    : null,
                leading: SizedBox.square(
                    dimension: 24, child: getModelIcon(e.modelName)),
                text: Text(e.modelName),
                onPressed: () => provider.selectNewModel(e),
              ),
            )
            .toList(),
      );
    });
  }
}
