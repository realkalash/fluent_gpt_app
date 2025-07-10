import 'package:fluent_gpt/cities_list.dart';
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/dialogs/models_list_dialog.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/pages/new_settings_page.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/widgets/custom_list_tile.dart';
import 'package:fluent_gpt/widgets/text_link.dart';
import 'package:fluent_ui/fluent_ui.dart'
    show
        Button,
        FlyoutController,
        FlyoutTarget,
        MenuFlyout,
        MenuFlyoutItem,
        AutoSuggestBox,
        TextFormBox,
        AutoSuggestBoxItem,
        FluentTheme;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:widget_and_text_animator/widget_and_text_animator.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';

class WelcomeLLMConfigPage extends StatefulWidget {
  const WelcomeLLMConfigPage({super.key});

  @override
  State<WelcomeLLMConfigPage> createState() => _WelcomePermissionsPageState();
}

class _WelcomePermissionsPageState extends State<WelcomeLLMConfigPage> {
  final cities = CitiesList.getAllCitiesList();

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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    TextAnimator(
                      'Configure your AI'.tr,
                      initialDelay: Duration(milliseconds: 1000),
                      characterDelay: Duration(milliseconds: 15),
                      style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextAnimator(
                      'Configure your AI to work as you want'.tr,
                      initialDelay: const Duration(milliseconds: 1500),
                      characterDelay: const Duration(milliseconds: 5),
                      style: TextStyle(color: Colors.white.withAlpha(178), fontSize: 14),
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
                        const NerdySelectorDropdown(),
                        ListTile(
                          title: Text('Add your models'.tr),
                          trailing: _ChooseModelButton(),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Button(
                            child: Text('Add'.tr),
                            onPressed: () async {
                              final chatProvider = context.read<ChatProvider>();
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
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('Currently supported providers:'.tr,
                            style: TextStyle(color: Colors.white.withAlpha(178), fontSize: 14)),
                        LinkTextButton('https://platform.openai.com/api-keys'),
                        LinkTextButton('https://deepinfra.com/dash/deployments'),
                        const SizedBox(height: 24),
                        Text('You can add info about you to improve AI response'.tr,
                            style: TextStyle(color: Colors.white.withAlpha(178), fontSize: 14)),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              TextFormBox(
                                prefix: BadgePrefix(Text('User name'.tr)),
                                initialValue: AppCache.userName.value,
                                minLines: 1,
                                maxLines: 1,
                                onChanged: (value) {
                                  AppCache.userName.value = value;
                                },
                              ),
                              const SizedBox(height: 8),
                              AutoSuggestBox(
                                leadingIcon: BadgePrefix(Text('User city'.tr)),
                                placeholder: AppCache.userCityName.value,
                                onChanged: (value, reason) {
                                  AppCache.userCityName.value = value;
                                  if (value.isNotEmpty) {
                                    AppCache.includeUserCityNamePrompt.value = true;
                                  } else {
                                    AppCache.includeUserCityNamePrompt.value = false;
                                  }
                                },
                                clearButtonEnabled: false,
                                trailingIcon: IconButton(
                                  icon: Icon(FluentIcons.delete_20_filled, color: Colors.red),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    AppCache.userCityName.value = '';
                                    AppCache.includeUserCityNamePrompt.value = false;
                                    setState(() {});
                                  },
                                ),
                                items: [for (var city in cities) AutoSuggestBoxItem(label: city, value: city)],
                              ),
                            ],
                          ),
                        )
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

enum NerdySelectorType {
  newbie,
  advanced,
  developer,
}

class NerdySelectorDropdown extends StatefulWidget {
  const NerdySelectorDropdown({super.key});

  @override
  State<NerdySelectorDropdown> createState() => _NerdySelectorDropdownState();
}

class _NerdySelectorDropdownState extends State<NerdySelectorDropdown> {
  final FlyoutController flyoutController = FlyoutController();
  final iconToLevel = <NerdySelectorType, Widget>{
    NerdySelectorType.newbie: const Text('🤩'),
    NerdySelectorType.advanced: const Text('😎'),
    NerdySelectorType.developer: const Text('‍💻'),
  };
  @override
  Widget build(BuildContext context) {
    final selectedType = NerdySelectorType.values[AppCache.nerdySelectorType.value!];
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: BasicListTile(
        title: Text('Select your level'.tr, style: FluentTheme.of(context).typography.subtitle),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.symmetric(vertical: 4),
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: iconToLevel[selectedType] is Text
              ? Text(
                  (iconToLevel[selectedType] as Text).data!,
                  style: const TextStyle(fontSize: 24),
                )
              : iconToLevel[selectedType]!,
        ),
        subtitle: Text(selectedType.name.tr),
        onTap: () {
          flyoutController.showFlyout(builder: (ctx) {
            return MenuFlyout(
              items: NerdySelectorType.values
                  .map(
                    (e) => MenuFlyoutItem(
                      text: Text(e.name.tr),
                      leading: iconToLevel[e],
                      selected: e == selectedType,
                      onPressed: () {
                        final chatProvider = context.read<ChatProvider>();
                        chatProvider.setNerdySelectorType(e);
                        setState(() {});
                      },
                    ),
                  )
                  .toList(),
            );
          });
        },
        trailing: FlyoutTarget(
          controller: flyoutController,
          child: Icon(FluentIcons.chevron_down_24_regular),
        ),
      ),
    );
  }
}

class _ChooseModelButton extends StatefulWidget {
  const _ChooseModelButton();

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
    if (selectedModel.modelName == 'Unknown' || allModels.value.isEmpty) {
      return SizedBox.shrink();
    }
    return FlyoutTarget(
      controller: flyoutController,
      child: ElevatedButton.icon(
        onPressed: () => openFlyout(context),
        icon: SizedBox.square(dimension: 24, child: getModelIcon(selectedModel.modelName)),
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
                trailing: e.modelName == selectedModel.modelName ? const Icon(FluentIcons.checkmark_16_filled) : null,
                leading: SizedBox.square(dimension: 24, child: getModelIcon(e.modelName)),
                text: Text(e.modelName),
                onPressed: () => provider.selectNewModel(e),
              ),
            )
            .toList(),
      );
    });
  }
}
