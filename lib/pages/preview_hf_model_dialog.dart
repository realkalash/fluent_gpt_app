import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/common/llm_model_common.dart';
import 'package:fluent_gpt/dialogs/models_list_dialog.dart' show IconToolsSupported;
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:flutter/material.dart' show Material;
import 'package:gen_art_bg/gen_art_bg.dart';
import 'package:http/http.dart' as http;
import 'package:link_preview_generator/link_preview_generator.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
// import 'package:path_provider/path_provider.dart';

class PreviewHuggingFaceModel extends StatefulWidget {
  const PreviewHuggingFaceModel(
    this.modelUri, {
    super.key,
  });

  static Future<LlmModelCommon?> show(BuildContext context, String modelUri) async {
    if (modelUri.startsWith('http') == false) {
      // remove the :Q4_K part from the model uri
      modelUri = 'https://huggingface.co/${modelUri.split(':').first}';
    }
    return showDialog<LlmModelCommon?>(
      context: context,
      barrierDismissible: false,
      dismissWithEsc: false,
      builder: (context) => PreviewHuggingFaceModel(modelUri),
    );
  }

  final String modelUri;

  @override
  State<PreviewHuggingFaceModel> createState() => _PreviewHuggingFaceModelState();

  static Widget _buildTag(BuildContext context, String text) {
    final theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.resources.controlStrokeColorSecondary, width: 1),
      ),
      child: Text(text, style: theme.typography.caption),
    );
  }

  static bool isDownloaded(String modelUri) {
    /// remove the :Q4_K part from the model uri
    modelUri = modelUri.trimRight().split(':').first;
    final id = normalizeModelId(modelUri);
    final modelPathGguf = '${FileUtils.modelsDirectoryPath}${Platform.pathSeparator}$id.gguf';
    return File(modelPathGguf).existsSync();
  }

  static String getModelPath(String modelUri) {
    /// remove the :Q4_K part from the model uri
    modelUri = modelUri.trimRight().split(':').first;
    final id = normalizeModelId(modelUri);
    final modelPathGguf = '${FileUtils.modelsDirectoryPath}${Platform.pathSeparator}$id.gguf';
    return modelPathGguf;
  }

  static String normalizeModelId(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('http')) {
      final u = Uri.parse(trimmed);
      var path = u.path;
      if (path.startsWith('/')) path = path.substring(1);
      if (path.startsWith('api/models/')) path = path.substring('api/models/'.length);
      final parts = path.split('/');
      if (parts.length >= 2) {
        return '${parts[0]}/${parts[1]}';
      }
      return path;
    }
    return trimmed;
  }
}

class _PreviewHuggingFaceModelState extends State<PreviewHuggingFaceModel> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _model;
  bool isDownloaded = false;
  bool isGguf = true;
  List<String> availableQuantizations = [];
  String _selectedQuantization = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _fetchModel();
    });
  }

  void _fetchModel() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final id = PreviewHuggingFaceModel.normalizeModelId(widget.modelUri);
      final uri = Uri.https('huggingface.co', '/api/models/$id');
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Failed to load model: ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected response format');
      }
      // get model id
      final modelId = decoded['modelId'] ?? decoded['id'] ?? '';
      isDownloaded = PreviewHuggingFaceModel.isDownloaded(widget.modelUri);
      if (!isDownloaded) {
        final modelPathSafetensors = '${FileUtils.modelsDirectoryPath}${Platform.pathSeparator}$modelId.safetensors';
        isDownloaded = File(modelPathSafetensors).existsSync();
      }
      if (decoded['tags'] is List) {
        isGguf = (decoded['tags'] as List).cast<String>().any((t) => t == 'gguf');
      }
      if (!isGguf) {
        _errorMessage = 'The app supports only GGUF models for now. Please try a different model.';
      }
      availableQuantizations = getAvailableQuantizations(decoded);
      if (availableQuantizations.isNotEmpty) {
        // prefer the one that contains q4, else first one. Reversed to prefer the highest quality
        _selectedQuantization = availableQuantizations.reversed.firstWhere(
          (e) => e.toLowerCase().contains('q4'),
          orElse: () => availableQuantizations.last,
        );
      }
      setState(() {
        _model = Map<String, dynamic>.from(decoded);
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
    final theme = FluentTheme.of(context);
    final model = _model;
    final modelId = model != null ? (model['modelId'] ?? model['id'] ?? '') : '';
    final pipeline = model != null ? _extractPipelineTag(model) : '';
    final downloads = model != null ? _extractInt(model, 'downloads') : null;
    final likes = model != null ? _extractInt(model, 'likes') : null;
    final pageUri = modelId is String && modelId.isNotEmpty ? 'https://huggingface.co/$modelId' : widget.modelUri;
    final tags = model != null ? _extractTags(model) : const <String>[];
    final endpointCompatible = tags.contains('endpoint_compatible');
    return ContentDialog(
      title: Row(
        children: [
          const Icon(FluentIcons.box_16_regular),
          const SizedBox(width: 8),
          Text('Preview and Download Model'),
          const Spacer(),
          if (endpointCompatible) const IconToolsSupported(),
        ],
      ),
      constraints: BoxConstraints(maxWidth: 720, maxHeight: height * 0.8),
      content: _isLoading
          ? const SizedBox(height: 160, child: Center(child: ProgressBar()))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(_iconForPipeline(pipeline), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        modelId is String && modelId.isNotEmpty ? modelId : widget.modelUri,
                        style: theme.typography.subtitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Material(
                    child: LinkPreviewGenerator(
                      bodyMaxLines: 3,
                      link: pageUri,
                      linkPreviewStyle: LinkPreviewStyle.small,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(FluentIcons.arrow_download_20_filled, size: 24, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(_formatNumber(downloads)),
                    const SizedBox(width: 12),
                    Icon(FluentIcons.heart_20_filled, size: 24, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(_formatNumber(likes)),
                  ],
                ),
                const SizedBox(height: 8),
                if (model != null) ...[
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tags.take(12).map((t) => _buildTagWithIcon(context, t)).toList(growable: false),
                  ),
                  if (model['modelId'] is String) Text('Model ID: ${model['modelId']}'),
                  // gguf format
                  if (model['gguf']?['usedStorage'] is int)
                    Text('Used storage: ${_formatBytes(model['gguf']['usedStorage'])}'),
                  if (model['gguf']?['usedStorage'] is int)
                    Text('Used storage: ${_formatBytes(model['gguf']['usedStorage'])}'),
                  if (model['gguf']?['context_length'] is int)
                    Text('Context length: ${_formatNumber(model['gguf']['context_length'])}'),
                  if (model['createdAt'] is String) Text('Created at: ${model['createdAt']}'),
                  if (model['gguf']?['total'] is int) Text('GGUF Total: ${_formatBytes(model['gguf']['total'])}'),
                  // safetensors format
                  if (model['usedStorage'] is int) Text('Used storage: ${_formatBytes(model['usedStorage'])}'),
                  if (model['safetensors']?['total'] is int)
                    Text('Safetensors total: ${_formatBytes(model['safetensors']['total'])}'),
                ],
                if (_errorMessage != null)
                  Text(_errorMessage!, style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
      actions: [
        FilledButton(
          autofocus: true,
          onPressed: _isLoading || _errorMessage != null
              ? null
              : () {
                  if (model == null) {
                    Navigator.of(context).pop(null);
                    return;
                  }
                  _startDownload(model);
                },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(FluentIcons.arrow_download_20_regular),
              const SizedBox(width: 6),
              Text(isDownloaded ? 'Downloaded'.tr : 'Download'.tr),
              Spacer(),
              if (availableQuantizations.isNotEmpty)
                ComboBox<String>(
                  isExpanded: false,
                  value: _selectedQuantization,
                  onChanged: (value) {
                    setState(() => _selectedQuantization = value ?? '');
                  },
                  items: availableQuantizations
                      .map(
                        (e) => ComboBoxItem<String>(
                          value: e,
                          child: Text(e.split('-').last.replaceAll('.gguf', '')),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
        Button(onPressed: () => Navigator.of(context).pop(null), child: Text('Cancel'.tr)),
      ],
    );
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
    return '';
  }

  List<String> _extractTags(dynamic model) {
    if (model is Map<String, dynamic>) {
      final tags = model['tags'];
      if (tags is List) {
        return tags.where((tag) => tag.startsWith('arx') == false).cast<String>().toList(growable: false);
      }
    }
    return const [];
  }

  String _formatNumber(int? number) {
    if (number == null) return '-';
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  int? _extractInt(dynamic model, String key) {
    if (model is Map<String, dynamic>) {
      final val = model[key];
      if (val is int) return val;
      if (val is String) return int.tryParse(val);
    }
    return null;
  }

  IconData _iconForPipeline(String pipeline) {
    switch (pipeline) {
      case 'text-generation':
        return FluentIcons.text_grammar_wand_20_regular;
      case 'image-text-to-text':
      case 'image-to-text':
      case 'vision':
        return FluentIcons.image_20_regular;
      case 'audio-to-text':
      case 'automatic-speech-recognition':
        return FluentIcons.mic_20_regular;
      default:
        return FluentIcons.apps_20_regular;
    }
  }

  Widget _buildTagWithIcon(BuildContext context, String tag) {
    final theme = FluentTheme.of(context);
    IconData? icon;
    if (tag == 'endpoints_compatible') icon = FluentIcons.plug_connected_20_regular;
    if (tag.contains('gguf')) icon = FluentIcons.document_20_regular;
    if (tag == 'safetensors') icon = FluentIcons.shield_20_regular;
    if (tag.contains('text')) icon = icon ?? FluentIcons.text_grammar_wand_20_regular;
    if (tag.contains('image')) icon = icon ?? FluentIcons.image_20_regular;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.resources.controlStrokeColorSecondary, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14),
            const SizedBox(width: 6),
          ],
          Text(tag, style: theme.typography.caption),
        ],
      ),
    );
  }

  Future<void> _startDownload(Map<String, dynamic> model) async {
    final id = (model['modelId'] ?? model['id'] ?? '').toString();
    final fileName =
        _selectedQuantization.isNotEmpty ? _selectedQuantization : _pickBestFilename(model, _selectedQuantization);
    if (fileName == null) {
      setState(() => _errorMessage = 'No downloadable files found');
      return;
    }
    final suffix = fileName.split('.').last;

    final url = 'https://huggingface.co/$id/resolve/main/$fileName?download=true';
    final modelsRoot = FileUtils.modelsDirectoryPath;
    final savePath = '$modelsRoot${Platform.pathSeparator}$id.$suffix';

    final saved = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DownloadAnimatedSplashDialog(url: url, savePath: savePath),
    );

    if (saved != null && saved.isNotEmpty) {
      model['saved_path'] = saved;
      final result = LlmModelCommon.fromHuggingFaceModel(model);
      if (mounted) Navigator.of(context).pop(result);
    }
  }

  List<String> getAvailableQuantizations(Map<String, dynamic> model) {
    final siblings = model['siblings'];
    if (siblings is! List) return [];
    return siblings
        .map((e) {
          return e is Map<String, dynamic> ? e['rfilename'].toString() : null;
        })
        .cast<String>()
        .where((n) => n.endsWith('.gguf') && n.contains('Q'))
        .toList();
  }

  String? _pickBestFilename(Map<String, dynamic> model, [String? selectedQuantization]) {
    final siblings = model['siblings'];
    if (siblings is! List) return null;
    final names = siblings.map((e) => e is Map<String, dynamic> ? e['rfilename'] : null).whereType<String>().toList();
    String? pickBy(bool Function(String) test) => names.firstWhere((n) => test(n), orElse: () => '');
    final gguf = pickBy((n) => n.toLowerCase().endsWith('.gguf'));
    if (gguf != null && gguf.isNotEmpty) return gguf;
    final st = pickBy((n) => n.toLowerCase().endsWith('.safetensors'));
    if (st != null && st.isNotEmpty) return st;
    final bin = pickBy((n) => n.toLowerCase().endsWith('.bin'));
    if (bin != null && bin.isNotEmpty) return bin;
    final pt = pickBy((n) => n.toLowerCase().endsWith('.pt'));
    if (pt != null && pt.isNotEmpty) return pt;
    return names.isNotEmpty ? names.first : null;
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return '-';
    const int kb = 1024;
    const int mb = kb * 1024;
    const int gb = mb * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}

class DownloadAnimatedSplashDialog extends StatefulWidget {
  const DownloadAnimatedSplashDialog({super.key, required this.url, required this.savePath});
  final String url;
  final String savePath;

  @override
  State<DownloadAnimatedSplashDialog> createState() => _DownloadAnimatedSplashDialogState();
}

class _DownloadAnimatedSplashDialogState extends State<DownloadAnimatedSplashDialog> {
  /// progress percent in 0..100
  double? _progress;
  String? _status;
  int received = 0;
  int total = 0;
  int nextUpdate = 0;
  @override
  void initState() {
    super.initState();
    _progress = null;
    // kick off download immediately
    scheduleMicrotask(_startDownload);
  }

  void _startDownload() async {
    try {
      final file = File(widget.savePath);
      final dir = file.parent;
      if (!(await dir.exists())) await dir.create(recursive: true);

      if (await file.exists()) {
        await file.delete();
      }

      final request = http.Request('GET', Uri.parse(widget.url));
      final response = await http.Client().send(request);
      if (response.statusCode != 200) {
        throw Exception('Failed: ${response.statusCode}');
      }

      final sink = file.openWrite();
      total = response.contentLength ?? 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (!mounted) continue;
          // prevent too many state updates. Check every X MB or when the download is complete
          final intervalMB = 1024 * 1024 * 5;
          if (received >= nextUpdate) {
            if (total > 0) {
              setState(() {
                final pct = (received / total) * 100.0;
                _progress = pct.clamp(0.0, 100.0);
                _status = '${_progress!.toStringAsFixed(0)}%';
              });
            } else {
              setState(() {
                _progress = null;
                _status = _formatBytesLocal(received);
              });
            }
            nextUpdate += intervalMB;
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      if (mounted) Navigator.of(context).pop(widget.savePath);
    } catch (e) {
      if (mounted) Navigator.of(context).pop(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final theme = FluentTheme.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: ContentDialog(
        constraints: BoxConstraints(maxWidth: size.width, maxHeight: size.height),
        style: ContentDialogThemeData(
          padding: EdgeInsets.zero,
          bodyPadding: EdgeInsets.zero,
        ),
        content: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SpiralWave(size: 20),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: size.width * 0.75,
                    child: ProgressBar(
                      value: _progress != null && _progress! > 0 ? _progress : null,
                      strokeWidth: 32,
                    ),
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        'Downloading...'.tr +
                            (_status != null
                                ? ' $_status' ' (${_formatBytesLocal(received)} / ${_formatBytesLocal(total)})'
                                : ''),
                        style: theme.typography.subtitle,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBytesLocal(int bytes) {
    const int kb = 1024;
    const int mb = kb * 1024;
    const int gb = mb * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}
