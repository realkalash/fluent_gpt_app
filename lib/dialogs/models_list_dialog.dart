import 'dart:convert';

import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/widgets/confirmation_dialog.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_gpt/widgets/text_link.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class ModelsListDialog extends StatefulWidget {
  const ModelsListDialog({super.key});

  @override
  State<ModelsListDialog> createState() => _ModelsListDialog();
}

class _ModelsListDialog extends State<ModelsListDialog> {
  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    return ContentDialog(
      title: Row(
        children: [
          const Text('Models List'),
          Spacer(),
          SqueareIconButton(
            onTap: () async {
              final model = await showDialog<ChatModelAi>(
                context: context,
                builder: (context) => const AddAiModelDialog(),
              );
              if (model != null) {
                chatProvider.addNewCustomModel(model);
              }
            },
            icon: Icon(FluentIcons.add_24_filled),
            tooltip: 'Add Model',
          ),
        ],
      ),
      constraints: BoxConstraints(maxWidth: 600),
      content: StreamBuilder(
        stream: allModels.stream,
        builder: (ctx, snap) {
          final models = allModels.value;
          return ListView.builder(
            shrinkWrap: true,
            itemCount: models.length,
            itemBuilder: (context, index) {
              final model = models[index];
              return ListTile(
                leading: SizedBox.square(dimension: 24, child: model.modelIcon),
                title: Text('${model.customName} | ${model.modelName}'),
                onPressed: () async {
                  final changedModel = await showDialog<ChatModelAi>(
                    context: context,
                    builder: (context) => AddAiModelDialog(initialModel: model),
                  );
                  if (changedModel != null) {
                    chatProvider.removeCustomModel(model);
                    chatProvider.addNewCustomModel(changedModel);
                  }
                },
                subtitle: Text(model.uri ?? 'no path'),
                trailing: IconButton(
                  icon: const Icon(FluentIcons.delete_24_filled),
                  onPressed: () => showDialog(
                      context: context,
                      builder: (ctx) => ConfirmationDialog(
                            onAcceptPressed: () =>
                                chatProvider.removeCustomModel(model),
                          )),
                ),
              );
            },
          );
        },
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

class AddAiModelDialog extends StatefulWidget {
  const AddAiModelDialog({super.key, this.initialModel});
  final ChatModelAi? initialModel;

  @override
  State<AddAiModelDialog> createState() => _AddAiModelDialogState();
}

class _AddAiModelDialogState extends State<AddAiModelDialog> {
  final openAiModels = [
    'gpt-4o',
    'chatgpt-4o-latest',
    'gpt-4',
    'gpt-4-32k',
    'gpt-4-32k-0314',
    'gpt-4-32k-0613',
    'gpt-4-0125-preview',
    'gpt-4-0314',
    'gpt-4-0613',
    'gpt-4-1106-preview',
    'gpt-4-turbo',
    'gpt-4-turbo-2024-04-09',
    'gpt-4-turbo-preview',
    'gpt-4-vision-preview',
    'gpt-4o-2024-05-13',
    'gpt-4o-2024-08-06',
    'gpt-4o-2024-08-06',
    'gpt-4o-mini',
    'gpt-4o-mini-2024-07-18',
    'gpt-3.5-turbo',
  ];
  ChatModelAi model = ChatModelAi(
    modelName: 'gpt-4o',
    customName: 'ChatGpt 4o',
    ownedBy: OwnedByEnum.openai.name,
    uri: 'https://api.openai.com/v1',
  );
  final _formKey = GlobalKey<FormState>();
  bool obscureKey = true;
  final autoSuggestOverlayController = GlobalKey<AutoSuggestBoxState>(
    debugLabel: 'autoSuggest model name',
  );
  final autoSuggestController = TextEditingController();
  final modelUriController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialModel != null) {
      model = widget.initialModel!;
      autoSuggestController.text = model.modelName;
      modelUriController.text = model.uri ?? 'https://';
    } else {
      autoSuggestController.text = openAiModels.first;
      modelUriController.text = 'https://api.openai.com/v1';
    }
  }

  List<String> autosuggestAdditionalItems = [];

  @override
  Widget build(BuildContext context) {
    final ownedBy = model.ownedBy ?? '';
    return ContentDialog(
      title: const Text('Add Model'),
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Custom Name'),
            TextFormBox(
              initialValue: model.customName,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
              onSaved: (value) {
                model = model.copyWith(customName: value);
              },
            ),
            spacer,
            Text('Model Name (Important. Case sensetive)'),
            AutoSuggestBox.form(
              key: autoSuggestOverlayController,
              items: [
                if (ownedBy == OwnedByEnum.openai.name)
                  ...openAiModels
                      .map((e) => AutoSuggestBoxItem(value: e, label: e)),
                ...autosuggestAdditionalItems.map(
                  (e) => AutoSuggestBoxItem(
                    value: e,
                    child: Text(e, maxLines: 1),
                    label: e,
                  ),
                ),
              ],
              controller: autoSuggestController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
              onChanged: (value, reason) {
                model = model.copyWith(modelName: value);
              },
            ),
            spacer,
            Text('Provider'),
            DropDownButton(
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 20,
                    child: model.modelIcon,
                  ),
                  const Icon(FluentIcons.chevron_down_20_regular),
                ],
              ),
              title: Text(ownedBy.isEmpty ? 'Select' : ownedBy),
              items: [
                for (final item in OwnedByEnum.values)
                  MenuFlyoutItem(
                    text: Text(item.name),
                    trailing: SizedBox.square(
                      dimension: 20,
                      child: ChatModelAi(modelName: '', ownedBy: item.name)
                          .modelIcon,
                    ),
                    selected: ownedBy == item.name,
                    onPressed: () {
                      if (item == OwnedByEnum.openai) {
                        model = model.copyWith(
                          uri: 'https://api.openai.com/v1',
                          ownedBy: item.name,
                        );
                        autoSuggestController.text = openAiModels.first;
                      }
                      model = model.copyWith(ownedBy: item.name);

                      setState(() {});
                    },
                  )
              ],
            ),
            spacer,
            Text('Url or Path'),
            TextFormBox(
              controller: modelUriController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a path';
                }
                if (value.endsWith('/')) {
                  return 'Please remove the trailing "/"';
                }
                return null;
              },
              onTapOutside: (event) {
                if (autoSuggestOverlayController
                        .currentState?.isOverlayVisible ==
                    true) {
                  autoSuggestOverlayController.currentState!.dismissOverlay();
                }
              },
              onFieldSubmitted: (uri) async {
                if (model.ownedBy == OwnedByEnum.openai.name) {
                  autoSuggestOverlayController.currentState!.showOverlay();
                } else if (model.ownedBy == OwnedByEnum.custom.name) {
                  await retrieveModelsFromPath(uri);
                  autoSuggestOverlayController.currentState!.showOverlay();
                } else if (model.ownedBy == OwnedByEnum.lm_studio.name) {
                  await retrieveModelsFromPath(uri);
                  autoSuggestOverlayController.currentState!.showOverlay();
                }
              },
              onSaved: (value) {
                model = model.copyWith(uri: value);
              },
            ),
            spacer,
            Text('API Key'),
            TextFormBox(
              initialValue: model.apiKey,
              obscureText: obscureKey,
              suffix: IconButton(
                icon: const Icon(FluentIcons.eye_20_regular),
                onPressed: () {
                  setState(() {
                    obscureKey = !obscureKey;
                  });
                },
              ),
              onSaved: (value) {
                model = model.copyWith(apiKey: value);
              },
            ),
            if (ownedBy == OwnedByEnum.openai.name)
              const Align(
                alignment: Alignment.centerLeft,
                child: LinkTextButton(
                  'https://platform.openai.com/api-keys',
                  url: 'https://platform.openai.com/api-keys',
                ),
              ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              if (model.customName.isEmpty) {
                model = model.copyWith(customName: model.modelName);
              }
              Navigator.of(context).pop(model);
            }
          },
          child: widget.initialModel == null
              ? const Text('Add')
              : const Text('Save'),
        ),
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future retrieveModelsFromPath(String url) async {
    final urlModels = '$url/models';
    final response = await http.get(Uri.parse(urlModels));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final models = body['data'] as List;
      autosuggestAdditionalItems =
          models.map((e) => e['id'] as String).toList();
      setState(() {});
    }
  }
}
