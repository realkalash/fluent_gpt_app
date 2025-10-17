import 'dart:async';
import 'dart:convert';

import 'package:fluent_gpt/common/llm_model_common.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/pages/preview_hf_model_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:http/http.dart' as http;

class ListHuggingFaceModelsDialog extends StatefulWidget {
  /// shows list of text-generation models from Hugging Face
  const ListHuggingFaceModelsDialog({super.key});

  static Future<LlmModelCommon?> show(BuildContext context) async {
    return showDialog<LlmModelCommon?>(
      context: context,
      builder: (context) => const ListHuggingFaceModelsDialog(),
    );
  }

  @override
  State<ListHuggingFaceModelsDialog> createState() => _ListHuggingFaceModelsDialogState();
}

class _ListHuggingFaceModelsDialogState extends State<ListHuggingFaceModelsDialog> {
  static const String _hfHost = 'hf.co';
  static const String _hfPath = '/api/models';
  static const String _taskFilter = 'text-generation';

  final TextEditingController _searchController = TextEditingController();
  String lastSearch = '';
  Timer? _debounce;

  String _sort = 'downloads'; // 'downloads' | 'likes'
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _models = [];
  bool _filterGguf = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchModels();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (_searchController.text.trim().isEmpty || _searchController.text.trim() == lastSearch) return;
      lastSearch = _searchController.text.trim();
      _fetchModels();
    });
  }

  Future<void> _fetchModels() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final queryParams = <String, String>{
        'filter': _taskFilter,
        'sort': _sort,
        // 'limit': '50',
        'library': 'gguf',
      };
      final searchText = _searchController.text.trim();
      if (searchText.isNotEmpty) {
        queryParams['search'] = searchText;
      }

      final uri = Uri.https(_hfHost, _hfPath, queryParams);
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Failed to load models: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw Exception('Unexpected response format');
      }

      setState(() {
        _models = (decoded).where(
          (e) {
            if (e['tags'] is List) {
              return (e['tags'] as List).cast<String>().any((t) => t == 'gguf');
            }
            return false;
          },
        ).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return ContentDialog(
      title: Text('Hugging Face Models'),
      constraints: BoxConstraints(maxWidth: 720, maxHeight: height * 0.8),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextBox(
                  controller: _searchController,
                  placeholder: 'Search models (name, tags)'.tr,
                ),
              ),
              const SizedBox(width: 12),
              ComboBox<String>(
                value: _sort,
                items: const [
                  ComboBoxItem(value: 'downloads', child: Text('Downloads')),
                  ComboBoxItem(value: 'likes', child: Text('Likes')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _sort = value);
                  _fetchModels();
                },
              ),

              /// We dont support safetensors models yet
              // const SizedBox(width: 12),
              // Checkbox(
              //   checked: _filterGguf,
              //   onChanged: (value) {
              //     setState(() => _filterGguf = value ?? false);
              //     _fetchModels();
              //   },
              //   content: Text('Filter GGUF models'.tr),
              // ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Expanded(child: Center(child: ProgressBar()))
          else if (_errorMessage != null)
            Expanded(child: Center(child: Text(_errorMessage!)))
          else
            Expanded(
              child: _models.isEmpty
                  ? Center(child: Text('No models found'.tr))
                  : ListView.separated(
                      itemCount: _models.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final model = _models[index] as Map<String, dynamic>;
                        final modelId = _extractModelId(model);
                        final pipeline = _extractPipelineTag(model);
                        final downloads = _extractInt(model, 'downloads');
                        final likes = _extractInt(model, 'likes');

                        return ListTile(
                          title: Text(modelId.isNotEmpty ? modelId : 'unknown'),
                          subtitle: Text('task: $pipeline · downloads: ${downloads ?? '-'} · likes: ${likes ?? '-'}'),
                          onPressed: () async {
                            final result = await PreviewHuggingFaceModel.show(context, modelId);
                            if (!mounted) return;
                            if (result != null) {
                              // ignore: use_build_context_synchronously
                              Navigator.of(context).pop(result);
                            }
                          },
                        );
                      },
                    ),
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

  String _extractModelId(dynamic model) {
    if (model is Map<String, dynamic>) {
      final id = model['modelId'] ?? model['id'];
      return id is String ? id : '';
    }
    return '';
  }

  String _extractPipelineTag(dynamic model) {
    if (model is Map<String, dynamic>) {
      final tag = model['pipeline_tag'];
      if (tag is String && tag.isNotEmpty) return tag;
      final tags = model['tags'];
      if (tags is List && tags.isNotEmpty) {
        final first = tags.firstWhere(
          (t) => t is String && t.toString().isNotEmpty,
          orElse: () => null,
        );
        if (first is String) return first;
      }
    }
    return 'unknown';
  }

  int? _extractInt(dynamic model, String key) {
    if (model is Map<String, dynamic>) {
      final val = model[key];
      if (val is int) return val;
      if (val is String) return int.tryParse(val);
    }
    return null;
  }
}
