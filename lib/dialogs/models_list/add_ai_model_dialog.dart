import 'dart:convert';

import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/openrouter_model_metadata.dart';
import 'package:fluent_gpt/common/openrouter_reasoning.dart';
import 'package:fluent_gpt/dialogs/models_list/widgets/add_model_form_sections.dart';
import 'package:fluent_gpt/dialogs/models_list/widgets/openrouter_model_info_card.dart';
import 'package:fluent_gpt/gpt_tools.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/text_link.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class AddAiModelDialog extends StatefulWidget {
  const AddAiModelDialog({super.key, this.initialModel});

  final ChatModelAi? initialModel;

  @override
  State<AddAiModelDialog> createState() => _AddAiModelDialogState();
}

class _AddAiModelDialogState extends State<AddAiModelDialog> {
  ChatModelAi model = ChatModelAi(
    modelName: 'openai/gpt-4o-mini',
    customName: 'OpenRouter',
    ownedBy: OwnedByEnum.openrouter.name,
    uri: 'https://openrouter.ai/api/v1',
    imageSupported: true,
  );

  final _formKey = GlobalKey<FormState>();
  bool obscureKey = true;
  bool _useCustomEndpoint = false;
  String? modelsListError;
  String? _testPhaseLabel;

  final autoSuggestOverlayController = GlobalKey<AutoSuggestBoxState>(
    debugLabel: 'autoSuggest model name',
  );
  final autoSuggestController = TextEditingController();
  final modelUriController = TextEditingController();
  final apiKeyController = TextEditingController();
  final customNameController = TextEditingController();

  bool isTesting = false;
  List<String> autosuggestAdditionalItems = [];
  Map<String, OpenRouterModelMeta> _openRouterMetaById = {};

  String? _presetUrl(String? ownedBy) {
    if (ownedBy == null || ownedBy.isEmpty) return null;
    return ChatModelProviderBase.providersList()
        .firstWhereOrNull((p) => p.ownedBy.name == ownedBy)
        ?.apiUrl;
  }

  String _currentBaseUrl() {
    final preset = _presetUrl(model.ownedBy);
    if (!_useCustomEndpoint && preset != null) {
      return preset;
    }
    return modelUriController.text.trim();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialModel != null) {
      model = widget.initialModel!;
      autoSuggestController.text = model.modelName;
      modelUriController.text = model.uri ?? 'https://';
      apiKeyController.text = model.apiKey;
      customNameController.text = model.customName;
      final preset = _presetUrl(model.ownedBy);
      _useCustomEndpoint = preset == null || model.uri != preset;
    } else {
      customNameController.text = 'OpenRouter';
      autoSuggestController.text = 'openai/gpt-4o-mini';
      modelUriController.text = 'https://openrouter.ai/api/v1';
      _useCustomEndpoint = false;
    }
  }

  @override
  void dispose() {
    autoSuggestController.dispose();
    modelUriController.dispose();
    apiKeyController.dispose();
    customNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ownedBy = model.ownedBy ?? '';
    final providerLabel = ChatModelProviderBase.providersList()
        .firstWhereOrNull((p) => p.ownedBy.name == ownedBy)
        ?.providerName;
    final preset = _presetUrl(ownedBy);
    final mq = MediaQuery.sizeOf(context);
    final openRouterListingMeta =
        ownedBy == OwnedByEnum.openrouter.name ? _openRouterMetaById[model.modelName.trim()] : null;

    return ContentDialog(
      constraints: BoxConstraints(maxWidth: 560, maxHeight: mq.height * 0.92),
      title: Text(widget.initialModel == null ? 'Add model'.tr : 'Edit model'.tr),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (modelsListError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InfoBar(
                      title: Text('Could not load model list'.tr),
                      content: Text(modelsListError!),
                      severity: InfoBarSeverity.error,
                    ),
                  ),
                AddModelSectionTitle('Provider'.tr),
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
                  title: Text(ownedBy.isEmpty ? 'Select'.tr : (providerLabel ?? ownedBy)),
                  items: [
                    for (final item in ChatModelProviderBase.providersList())
                      MenuFlyoutItem(
                        text: Text(item.providerName),
                        trailing: SizedBox.square(
                          dimension: 20,
                          child: ChatModelAi(modelName: '', ownedBy: item.ownedBy.name).modelIcon,
                        ),
                        selected: ownedBy == item.ownedBy.name,
                        onPressed: () async {
                          setState(() {
                            _useCustomEndpoint = false;
                            modelUriController.text = item.apiUrl;
                            modelsListError = null;
                            _openRouterMetaById = {};
                          });
                          final modelThatExistFromTheSameProvider = allModels.value
                              .firstWhereOrNull((e) => e.ownedBy == item.ownedBy.name && e.apiKey.isNotEmpty);
                          final apiKey =
                              modelThatExistFromTheSameProvider?.apiKey ?? apiKeyController.text.trim();
                          apiKeyController.text = apiKey;
                          model = model.copyWith(
                            ownedBy: item.ownedBy.name,
                            uri: item.apiUrl,
                            apiKey: apiKey,
                          );
                          autoSuggestController.clear();
                          await retrieveModelsFromPath(item.apiUrl);
                          if (mounted) setState(() {});
                        },
                      )
                  ],
                ),
                const SizedBox(height: 8),
                AddModelSectionTitle('API key'.tr),
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
                    child: LinkTextButton('https://platform.openai.com/api-keys'),
                  ),
                if (ownedBy == OwnedByEnum.openrouter.name)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: LinkTextButton('https://openrouter.ai/settings/keys'),
                  ),
                if (ownedBy == OwnedByEnum.deepinfra.name)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: LinkTextButton('https://deepinfra.com/dash/api_keys'),
                  ),
                AddModelSectionTitle('API base URL'.tr),
                Checkbox(
                  content: Text('Use custom API base URL'.tr),
                  checked: _useCustomEndpoint,
                  onChanged: (value) {
                    setState(() {
                      _useCustomEndpoint = value ?? false;
                      modelsListError = null;
                      if (!_useCustomEndpoint) {
                        final p = _presetUrl(model.ownedBy);
                        if (p != null) {
                          modelUriController.text = p;
                          model = model.copyWith(uri: p);
                        }
                      }
                    });
                  },
                ),
                if (_useCustomEndpoint)
                  TextFormBox(
                    controller: modelUriController,
                    placeholder: 'https://example.com/v1',
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
                      autoSuggestOverlayController.currentState?.dismissOverlay();
                    },
                    onFieldSubmitted: (uri) async {
                      await retrieveModelsFromPath(uri);
                      autoSuggestController.value = const TextEditingValue(text: ' ');
                      autoSuggestOverlayController.currentState?.showOverlay();
                    },
                    onSaved: (value) {
                      model = model.copyWith(uri: value);
                    },
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SelectableText(
                      preset ?? modelUriController.text,
                      style: FluentTheme.of(context).typography.caption,
                    ),
                  ),
                Button(
                  onPressed: isTesting
                      ? null
                      : () async {
                          final url = _currentBaseUrl();
                          if (url.isEmpty) {
                            displayTextInfoBar('Please enter a valid API URL.'.tr);
                            return;
                          }
                          if (url.endsWith('/')) {
                            displayTextInfoBar('Remove the trailing "/" from the URL.'.tr);
                            return;
                          }
                          setState(() {
                            model = model.copyWith(uri: url);
                            modelUriController.text = url;
                            modelsListError = null;
                          });
                          await retrieveModelsFromPath(url);
                          if (mounted) setState(() {});
                        },
                  child: Text('Fetch models from API'.tr),
                ),
                const SizedBox(height: 4),
                AddModelSectionTitle('Model id (case-sensitive)'.tr),
                AutoSuggestBox<String?>.form(
                  key: autoSuggestOverlayController,
                  itemBuilder: (context, item) =>
                      _buildOpenRouterSuggestListRow(context, item as AutoSuggestBoxItem<String?>),
                  items: [
                    for (final e in autosuggestAdditionalItems)
                      AutoSuggestBoxItem<String?>(
                        value: e,
                        label: e,
                      ),
                  ],
                  controller: autoSuggestController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a model id'.tr;
                    }
                    return null;
                  },
                  onChanged: (value, reason) {
                    if (isTesting) return;
                    setState(() {
                      model = model.copyWith(modelName: value);
                    });
                  },
                  onSelected: (item) {
                    if (isTesting) return;
                    setState(() {
                      model = model.copyWith(modelName: item.value ?? item.label);
                    });
                    _testModel();
                  },
                ),
                if (openRouterListingMeta != null)
                  OpenRouterModelInfoCard(
                    meta: openRouterListingMeta,
                    onApplySuggestedCapabilities: () =>
                        _applyOpenRouterSuggestedCapabilities(openRouterListingMeta),
                  ),
                spacer,
                AddModelSectionTitle('Display name'.tr),
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
                AddModelSectionTitle('Capabilities'.tr),
                Text(
                  'You can set these manually; Test connection may update them based on the API.'.tr,
                  style: FluentTheme.of(context).typography.caption,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
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
                  onPressed: isTesting ? null : _testModel,
                  child: Text('Test connection'.tr),
                ),
                AddModelTestProgress(
                  isTesting: isTesting,
                  phaseLabel: _testPhaseLabel,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'.tr),
        ),
        FilledButton(
          onPressed: () {
            final url = _currentBaseUrl();
            if (!_useCustomEndpoint) {
              modelUriController.text = url;
            }
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              final presetUrl = _presetUrl(model.ownedBy);
              final resolvedUri =
                  _useCustomEndpoint ? modelUriController.text.trim() : (presetUrl ?? url);
              if (resolvedUri.endsWith('/')) {
                displayTextInfoBar('Please remove the trailing "/"'.tr);
                return;
              }
              if (model.customName.isEmpty) {
                model = model.copyWith(customName: model.modelName);
              }
              model = model.copyWith(uri: resolvedUri);
              Navigator.of(context).pop(model);
            }
          },
          child: widget.initialModel == null ? Text('Add'.tr) : Text('Save'.tr),
        ),
      ],
    );
  }

  /// OpenRouter overlay rows use a fixed [itemExtent] (~42px); keep content scaling inside it
  /// and handle taps here because [AutoSuggestBox.itemBuilder] replaces the default tile.
  Widget _buildOpenRouterSuggestListRow(BuildContext context, AutoSuggestBoxItem<String?> item) {
    final theme = FluentTheme.of(context);
    final id = item.label;
    final meta = _openRouterMetaById[id];
    final sub = meta == null ? null : formatOpenRouterAutosuggestSubtitle(meta);

    return HoverButton(
      semanticLabel: item.semanticLabel ?? id,
      onPressed: () => _applyOpenRouterSuggestSelection(item),
      builder: (context, states) {
        final bg = ButtonThemeData.uncheckedInputColor(
          theme,
          states,
          transparentWhenNone: true,
          transparentWhenDisabled: true,
        );
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: bg,
            shape: kDefaultListTileShape,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 10, top: 2, bottom: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body?.copyWith(fontSize: 14),
                ),
                if (sub != null)
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption?.copyWith(fontSize: 11.5),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _applyOpenRouterSuggestSelection(AutoSuggestBoxItem<String?> item) {
    autoSuggestOverlayController.currentState?.dismissOverlay();
    final label = item.label;
    autoSuggestController.value = TextEditingValue(
      text: label,
      selection: TextSelection.collapsed(offset: label.length),
    );
    if (isTesting) return;
    setState(() {
      model = model.copyWith(modelName: item.value ?? label);
    });
    _testModel();
  }

  void _applyOpenRouterSuggestedCapabilities(OpenRouterModelMeta meta) {
    setState(() {
      model = model.copyWith(
        imageSupported: metaSuggestsImageInput(meta),
        toolSupported: metaSuggestsTools(meta),
        reasoningSupported: metaSuggestsReasoning(meta),
      );
    });
  }

  OpenRouterModelMeta? _openRouterMetaForCurrentModel() {
    if (model.ownedBy != OwnedByEnum.openrouter.name) return null;
    return _openRouterMetaById[model.modelName.trim()];
  }

  Future<void> retrieveModelsFromPath(String url) async {
    if (!mounted) return;
    setState(() {
      modelsListError = null;
    });
    final apiKeyInField = apiKeyController.text.trim();
    final savedSameProvider =
        allModels.value.firstWhereOrNull((e) => e.ownedBy == model.ownedBy && e.apiKey.isNotEmpty);
    final bearer = apiKeyInField.isNotEmpty ? apiKeyInField : (savedSameProvider?.apiKey ?? '');
    log('Load models from $url');
    final urlModels = '$url/models';
    final response = await http.get(Uri.parse(urlModels), headers: {
      if (bearer.trim().isNotEmpty) 'Authorization': 'Bearer ${bearer.trim()}',
    });
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'];
      if (data is! List) {
        if (mounted) {
          setState(() {
            modelsListError = 'Unexpected /models response.'.tr;
            _openRouterMetaById = {};
          });
        }
        return;
      }
      autosuggestAdditionalItems = data
          .map((e) => (e as Map<String, dynamic>)['id'] as String)
          .toList();
      if (model.ownedBy == OwnedByEnum.openrouter.name) {
        _openRouterMetaById = parseOpenRouterModelsListResponse(response.body);
      } else {
        _openRouterMetaById = {};
      }
      if (mounted) setState(() {});
      if (autosuggestAdditionalItems.length == 1) {
        _selectFirstModel();
      } else if (autosuggestAdditionalItems.isNotEmpty) {
        autoSuggestController.value = const TextEditingValue(text: ' ');
        autoSuggestOverlayController.currentState?.showOverlay();
      }
    } else {
      log('Error loading models from $url: ${response.statusCode} ${response.body}');
      final snippet =
          response.body.length > 300 ? '${response.body.substring(0, 300)}…' : response.body;
      if (mounted) {
        setState(() {
          modelsListError = '${response.statusCode}: $snippet';
          _openRouterMetaById = {};
        });
      }
      if (model.ownedBy == OwnedByEnum.openai.name) {
        autoSuggestController.text = 'gpt-4.1';
      } else if (model.ownedBy == OwnedByEnum.openrouter.name) {
        autoSuggestController.text = 'openai/gpt-4o-mini';
      }
    }
  }

  void _selectFirstModel() {
    final id = autosuggestAdditionalItems.first;
    autoSuggestController.text = id;
    final name = id.split('\\').last;
    customNameController.text = name;
    model = model.copyWith(modelName: id, customName: name);
    _testModel();
  }

  Future<void> _testModel() async {
    if (isTesting) return;
    final url = _currentBaseUrl();
    if (url.isEmpty) {
      displayTextInfoBar('Please set a valid API base URL.'.tr);
      return;
    }
    if (url.endsWith('/')) {
      displayTextInfoBar('Remove the trailing "/" from the URL.'.tr);
      return;
    }
    model = model.copyWith(uri: url);
    final orMeta = _openRouterMetaForCurrentModel();
    final trustListing =
        orMeta != null && openRouterMetaListsCapabilities(orMeta);
    final modelThatExistFromTheSameProvider =
        allModels.value.firstWhereOrNull((e) => e.ownedBy == model.ownedBy && e.apiKey.isNotEmpty);
    final fieldApiKey = apiKeyController.text.trim();
    final bearer = fieldApiKey.isNotEmpty
        ? 'Bearer $fieldApiKey'
        : modelThatExistFromTheSameProvider != null
            ? 'Bearer ${modelThatExistFromTheSameProvider.apiKey}'
            : '';
    if (mounted) {
      setState(() {
        isTesting = true;
        _testPhaseLabel = 'Checking chat response…'.tr;
        if (trustListing) {
          model = model.copyWith(
            imageSupported: metaSuggestsImageInput(orMeta),
            toolSupported: metaSuggestsTools(orMeta),
            reasoningSupported: metaSuggestsReasoning(orMeta),
          );
        }
      });
    }

    if (trustListing) {
      await _testHiAndReasoning(
        url,
        bearer,
        updateReasoningFromResponse: false,
        openRouterReasoningProbe: false,
      );
    } else {
      await _testHiAndReasoning(url, bearer);
      if (!mounted) return;
      setState(() => _testPhaseLabel = 'Checking vision…'.tr);
      await _testImageSupport(url, bearer);
      if (!mounted) return;
      setState(() => _testPhaseLabel = 'Checking tools…'.tr);
      await _testToolSupport(url, bearer);
    }
    if (mounted) {
      setState(() {
        isTesting = false;
        _testPhaseLabel = null;
      });
    }
  }

  Future<void> _testImageSupport(String url, String bearer) async {
    if (!mounted) return;
    final probeOpenRouter = isOpenRouterConfiguredModel(model);
    final image = await rootBundle.load('assets/saucenao_favicon.png');
    final imageBytes = image.buffer.asUint8List();
    final base64Image = base64Encode(imageBytes);
    final imageBody = <String, dynamic>{
      'model': model.modelName,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': 'Describe this image in 3 words.',
            },
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/png;base64,$base64Image'},
            },
          ],
        },
      ],
    };
    applyOpenRouterVendorReasoningToBodyMap(imageBody, model, openRouterCapabilityProbe: probeOpenRouter);
    final response = await http.post(
      Uri.parse('$url/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': bearer,
      },
      body: jsonEncode(imageBody),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content = body['choices']?[0]?['message']?['content'];
      log('Image support test response: $content');
      if (content != null && content.toString().trim().isNotEmpty) {
        model = model.copyWith(imageSupported: true);
      }
    } else {
      log('Error testing image support: ${response.statusCode} ${response.body}');
      model = model.copyWith(imageSupported: false);
    }
  }

  Future<void> _testHiAndReasoning(
    String url,
    String bearer, {
    bool updateReasoningFromResponse = true,
    bool openRouterReasoningProbe = true,
  }) async {
    if (!mounted) return;
    final probeOpenRouter =
        openRouterReasoningProbe && isOpenRouterConfiguredModel(model);
    final hiBody = <String, dynamic>{
      'model': model.modelName,
      'messages': [
        {
          'role': 'user',
          'content': probeOpenRouter
              ? 'What is 2 + 2? Reply with just the digit.'
              : 'Hi. Answer using 1 word. /no_think',
        },
      ],
    };
    applyOpenRouterVendorReasoningToBodyMap(hiBody, model, openRouterCapabilityProbe: probeOpenRouter);
    final response = await http.post(
      Uri.parse('$url/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': bearer,
      },
      body: jsonEncode(hiBody),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content = body['choices']?[0]?['message']?['content'];
      if (content != null) {
        log('Hi and reasoning test response: $content');
      }
      if (updateReasoningFromResponse && openRouterChatResponseIndicatesReasoning(body)) {
        model = model.copyWith(reasoningSupported: true);
      }
    } else {
      log('Error testing model: ${response.statusCode} ${response.body}');
      if (updateReasoningFromResponse) {
        model = model.copyWith(reasoningSupported: false);
      }
    }
  }

  Future<void> _testToolSupport(String url, String bearer) async {
    if (!mounted) return;
    final probeOpenRouter = isOpenRouterConfiguredModel(model);

    Future<http.Response> postBody(Map<String, dynamic> toolBody) {
      applyOpenRouterVendorReasoningToBodyMap(toolBody, model, openRouterCapabilityProbe: probeOpenRouter);
      return http.post(
        Uri.parse('$url/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': bearer,
        },
        body: jsonEncode(toolBody),
      );
    }

    Map<String, dynamic> buildToolBody({required bool forcePing}) => {
          'model': model.modelName,
          'tools': [pingFunction],
          'max_tokens': 512,
          'messages': [
            {
              'role': 'user',
              'content': probeOpenRouter
                  ? 'Call the ping tool exactly once with responseMessage set to "pong". No other text.'
                  : 'This is a tool test. Use tool "ping" to ping connection. /no_think',
            },
          ],
          if (forcePing)
            'tool_choice': <String, dynamic>{
              'type': 'function',
              'function': {'name': 'ping'},
            },
        };

    var response = await postBody(buildToolBody(forcePing: true));
    if (response.statusCode >= 400) {
      log('Tool test (forced ping) failed: ${response.statusCode} retrying without tool_choice');
      response = await postBody(buildToolBody(forcePing: false));
    }

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final finishReason = body['choices']?[0]?['finish_reason'];
      final msg = body['choices']?[0]?['message'];
      final toolCalls = msg is Map ? msg['tool_calls'] : null;
      log('Tool support test response: $finishReason');
      if (finishReason == 'tool_calls' || (toolCalls is List && toolCalls.isNotEmpty)) {
        model = model.copyWith(toolSupported: true);
      }
    } else {
      log('Error testing tool support: ${response.statusCode} ${response.body}');
      model = model.copyWith(toolSupported: false);
    }
  }
}
