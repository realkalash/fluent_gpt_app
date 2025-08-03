import 'dart:convert';

import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/gpt_tools.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/confirmation_dialog.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_gpt/widgets/text_link.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
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
          Text('Models List'.tr),
          Spacer(),
          SqueareIconButton(
            onTap: () async {
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
            icon: Icon(FluentIcons.add_24_filled),
            tooltip: 'Add'.tr,
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
                  final isThisModelWasSelected = model == selectedModel;
                  final changedModel = await showDialog<ChatModelAi>(
                    context: context,
                    builder: (context) => AddAiModelDialog(initialModel: model),
                  );
                  if (changedModel != null) {
                    chatProvider.removeCustomModel(model);
                    chatProvider.addNewCustomModel(changedModel);
                    if (isThisModelWasSelected) {
                      await Future.delayed(const Duration(milliseconds: 100));
                      chatProvider.selectNewModel(changedModel);
                    }
                  }
                },
                subtitle: Text(model.uri ?? 'no path'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (model.imageSupported) Icon(FluentIcons.image_24_filled),
                    if (model.reasoningSupported) Icon(FluentIcons.brain_sparkle_20_filled),
                    if (model.toolSupported) Icon(FluentIcons.code_16_filled),
                    Button(
                      child: Text('Select'.tr),
                      onPressed: () async {
                        chatProvider.selectNewModel(model);
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 4),
                    SqueareIconButtonSized(
                      icon: Icon(FluentIcons.edit_20_regular),
                      tooltip: 'Edit'.tr,
                      height: 29,
                      width: 29,
                      onTap: () async {
                        final isThisModelWasSelected = model == selectedModel;
                        final changedModel = await showDialog<ChatModelAi>(
                          context: context,
                          builder: (context) => AddAiModelDialog(initialModel: model),
                        );
                        if (changedModel != null) {
                          chatProvider.removeCustomModel(model);
                          chatProvider.addNewCustomModel(changedModel);
                          if (isThisModelWasSelected) {
                            await Future.delayed(const Duration(milliseconds: 100));
                            chatProvider.selectNewModel(changedModel);
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.delete_24_filled),
                      onPressed: () => showDialog(
                          context: context,
                          builder: (ctx) => ConfirmationDialog(
                                onAcceptPressed: () => chatProvider.removeCustomModel(model),
                              )),
                    ),
                  ],
                ),
              );
            },
          );
        },
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

class AddAiModelDialog extends StatefulWidget {
  const AddAiModelDialog({super.key, this.initialModel});
  final ChatModelAi? initialModel;

  @override
  State<AddAiModelDialog> createState() => _AddAiModelDialogState();
}

class _AddAiModelDialogState extends State<AddAiModelDialog> {
  ChatModelAi model = ChatModelAi(
    modelName: 'gpt-4.1',
    customName: 'ChatGpt 4.1',
    ownedBy: OwnedByEnum.openai.name,
    uri: 'https://api.openai.com/v1',
    imageSupported: true,
  );
  final _formKey = GlobalKey<FormState>();
  bool obscureKey = true;
  final autoSuggestOverlayController = GlobalKey<AutoSuggestBoxState>(
    debugLabel: 'autoSuggest model name',
  );
  final autoSuggestController = TextEditingController();
  final modelUriController = TextEditingController();
  final apiKeyController = TextEditingController();
  final customNameController = TextEditingController();
  bool isTesting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialModel != null) {
      model = widget.initialModel!;
      autoSuggestController.text = model.modelName;
      modelUriController.text = model.uri ?? 'https://';
      apiKeyController.text = model.apiKey;
      customNameController.text = model.customName;
    } else {
      customNameController.text = 'ChatGPT';
      autoSuggestController.text = 'gpt-4.1';
      modelUriController.text = 'https://api.openai.com/v1';
    }
  }

  List<String> autosuggestAdditionalItems = [];

  @override
  Widget build(BuildContext context) {
    final ownedBy = model.ownedBy ?? '';
    return ContentDialog(
      title: Text('Add'.tr),
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Custom Name'.tr),
            TextFormBox(
              controller: customNameController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name'.tr;
                }
                return null;
              },
              onSaved: (value) {
                model = model.copyWith(customName: value);
              },
            ),
            spacer,
            Text('Model Name (Important. Case sensetive)'.tr),
            AutoSuggestBox.form(
              key: autoSuggestOverlayController,
              items: [
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
                  return 'Please enter a name'.tr;
                }
                return null;
              },
              onChanged: (value, reason) {
                if (isTesting) return;
                model = model.copyWith(modelName: value);
              },
              onSelected: (item) {
                if (isTesting) return;
                model = model.copyWith(modelName: item.value);
                _testModel();
              },
            ),
            spacer,
            Wrap(
              spacing: 8,
              children: [
                Checkbox(
                  content: Text('Support images?'.tr),
                  checked: model.imageSupported,
                  onChanged: (value) {
                    model = model.copyWith(imageSupported: value);
                    setState(() {});
                  },
                ),
                Checkbox(
                  content: Text('Support reasoning?'.tr),
                  checked: model.reasoningSupported,
                  onChanged: (value) {
                    model = model.copyWith(reasoningSupported: value);
                    setState(() {});
                  },
                ),
                Checkbox(
                  content: Text('Support tools?'.tr),
                  checked: model.toolSupported,
                  onChanged: (value) {
                    model = model.copyWith(toolSupported: value);
                    setState(() {});
                  },
                ),
              ],
            ),
            Button(
              onPressed: () {
                _testModel();
              },
              child: Text('Test model'.tr),
            ),
            spacer,
            Text('Provider'.tr),
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
              title: Text(ownedBy.isEmpty ? 'Select'.tr : ownedBy),
              items: [
                for (final item in ChatModelProviderBase.providersList())
                  MenuFlyoutItem(
                    text: Text(item.providerName),
                    trailing: SizedBox.square(
                      dimension: 20,
                      child: ChatModelAi(modelName: '', ownedBy: item.ownedBy.name).modelIcon,
                    ),
                    selected: ownedBy == item.providerName,
                    onPressed: () async {
                      modelUriController.text = item.apiUrl;
                      final modelThatExistFromTheSameProvider = allModels.value
                          .firstWhereOrNull((e) => e.ownedBy == item.ownedBy.name && e.apiKey.isNotEmpty);
                      final apiKey = modelThatExistFromTheSameProvider?.apiKey ?? apiKeyController.text.trim();
                      apiKeyController.text = apiKey;
                      model = model.copyWith(
                        ownedBy: item.ownedBy.name,
                        uri: item.apiUrl,
                        apiKey: apiKey,
                      );

                      autoSuggestController.clear();
                      await retrieveModelsFromPath(item.apiUrl);
                      setState(() {});
                    },
                  )
              ],
            ),
            if (isTesting)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Text('Testing...'.tr), ProgressBar()],
              ),
            spacer,
            Text('Url'.tr),
            TextFormBox(
              controller: modelUriController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a path'.tr;
                }
                if (value.endsWith('/')) {
                  return 'Please remove the trailing "/"'.tr;
                }
                return null;
              },
              onTapOutside: (event) {
                if (autoSuggestOverlayController.currentState?.isOverlayVisible == true) {
                  autoSuggestOverlayController.currentState!.dismissOverlay();
                }
              },
              onFieldSubmitted: (uri) async {
                await retrieveModelsFromPath(uri);
                autoSuggestController.value = TextEditingValue(text: ' ');
                autoSuggestOverlayController.currentState!.showOverlay();
              },
              onSaved: (value) {
                model = model.copyWith(uri: value);
              },
            ),
            spacer,
            Text('API Key'.tr),
            TextFormBox(
              controller: apiKeyController,
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
              onFieldSubmitted: (value) {
                if (isTesting) {
                  displayTextInfoBar('Wait for previous test to finish'.tr);
                  return;
                }
                _testModel();
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
          child: widget.initialModel == null ? Text('Add'.tr) : Text('Save'.tr),
        ),
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'.tr),
        ),
      ],
    );
  }

  Future retrieveModelsFromPath(String url) async {
    final isOpenAi = model.uri == url;
    final apiKeyInField = apiKeyController.text.trim();
    final openAiModel =
        allModels.value.firstWhereOrNull((e) => e.ownedBy == OwnedByEnum.openai.name && e.apiKey.isNotEmpty);
    final bearer = apiKeyInField.isNotEmpty
        ? apiKeyInField
        : (isOpenAi && openAiModel != null)
            ? openAiModel.apiKey
            : '';
    log('Load models from $url');
    final urlModels = '$url/models';
    final response = await http.get(Uri.parse(urlModels), headers: {
      if (bearer.trim().isNotEmpty) 'Authorization': 'Bearer ${bearer.trim()}',
    });
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final models = body['data'] as List;
      autosuggestAdditionalItems = models.map((e) => e['id'] as String).toList();
      setState(() {});
      if (autosuggestAdditionalItems.length == 1) {
        _selectFirstModel();
      } else {
        if (autosuggestAdditionalItems.isNotEmpty) {
          autoSuggestController.value = TextEditingValue(text: ' ');
          autoSuggestOverlayController.currentState!.showOverlay();
        }
      }
    } else {
      log('Error loading models from $url: ${response.statusCode} ${response.body}');
      if (isOpenAi) {
        autoSuggestController.text = 'gpt-4.1';
      }
    }
  }

  void _selectFirstModel() {
    autoSuggestController.text = autosuggestAdditionalItems.first;
    final name = autosuggestAdditionalItems.first.split('\\').last;
    customNameController.text = name;
    _testModel();
  }

  /// Will try to send:
  /// 1. Basic Hi message.
  /// 2. Send an image to test image support.
  /// 3. Ask use tool to test tool support.
  /// 4. Test reasoning support.
  Future<void> _testModel() async {
    if (isTesting) return;
    if (mounted)
      setState(() {
        isTesting = true;
      });
    final modelThatExistFromTheSameProvider =
        allModels.value.firstWhereOrNull((e) => e.ownedBy == model.ownedBy && e.apiKey.isNotEmpty);
    final fieldApiKey = apiKeyController.text.trim();
    final url = model.uri;
    final bearer = fieldApiKey.isNotEmpty
        ? 'Bearer $fieldApiKey'
        : modelThatExistFromTheSameProvider != null
            ? 'Bearer ${modelThatExistFromTheSameProvider.apiKey}'
            : '';
    await _testHiAndReasoning(url.toString(), bearer);
    await _testImageSupport(url.toString(), bearer);
    await _testToolSupport(url.toString(), bearer);
    if (mounted)
      setState(() {
        isTesting = false;
      });
  }

  Future<void> _testImageSupport(String url, String bearer) async {
    if (!mounted) return;
    // get asset from assets/saucenao_favicon.png
    final image = await rootBundle.load('assets/saucenao_favicon.png');
    final imageBytes = image.buffer.asUint8List();
    final base64Image = base64Encode(imageBytes);
    // send image to model and ask to describe it in 3 words.
    final response = await http.post(Uri.parse('$url/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': bearer,
        },
        body: jsonEncode({
          'model': model.modelName,
          'messages': [
            {'role': 'user', 'content': 'Describe this image in 3 words.'},
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/png;base64,$base64Image'}
                }
              ],
            }
          ],
        }));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final content = body['choices'][0]['message']['content'];
      log('Image support test response: $content');
      if (content != null) {
        model = model.copyWith(imageSupported: true);
      }
    } else {
      log('Error testing image support: ${response.statusCode} ${response.body}');
      model = model.copyWith(imageSupported: false);
    }
  }

  Future<void> _testHiAndReasoning(String url, String bearer) async {
    if (!mounted) return;
    final response = await http.post(Uri.parse('$url/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': bearer,
        },
        body: jsonEncode({
          'model': model.modelName,
          'messages': [
            {'role': 'user', 'content': 'Hi. Answer using 1 word. /no_think'},
          ],
        }));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final content = body['choices'][0]['message']['content'];
      if (content != null) {
        log('Hi and reasoning test response: $content');
        if (content.toString().contains('<think>')) {
          model = model.copyWith(reasoningSupported: true);
        }
      }
    } else {
      log('Error testing model: ${response.statusCode} ${response.body}');
      model = model.copyWith(reasoningSupported: false);
    }
  }

  Future<void> _testToolSupport(String url, String bearer) async {
    if (!mounted) return;
    final response = await http.post(Uri.parse('$url/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': bearer,
        },
        body: jsonEncode({
          'model': model.modelName,
          'tools': [
            pingFunction,
          ],
          'max_tokens': 100,
          'messages': [
            {'role': 'user', 'content': 'This is a tool test. Use tool "ping" to ping connection. /no_think'},
          ],
        }));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final content = body['choices'][0]['finish_reason'];
      log('Tool support test response: $content');
      if (content == 'tool_calls') {
        model = model.copyWith(toolSupported: true);
      }
    } else {
      log('Error testing tool support: ${response.statusCode} ${response.body}');
      model = model.copyWith(toolSupported: false);
    }
  }
}
