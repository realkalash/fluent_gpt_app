import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/dialogs/llm_models_dialogs/list_hf_models_dialog.dart';
import 'package:fluent_gpt/pages/preview_hf_model_dialog.dart';
import 'package:fluent_gpt/pages/welcome/choose_hf_model_dialog.dart';
import 'package:fluent_gpt/providers/server_provider.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class LocalServerPage extends StatefulWidget {
  const LocalServerPage({super.key});

  @override
  State<LocalServerPage> createState() => _LocalServerPageState();
}

class _LocalServerPageState extends State<LocalServerPage> {
  bool isOutputExpanded = false;
  bool isOutputHidden = false;
  Map<String, String> availableDevices = {};
  bool isLoadingDevices = false;
  bool disableLogging = false;
  final TextEditingController modelPathController = TextEditingController();
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _loadAvailableDevices().then((_) {
        if (availableDevices.isNotEmpty) {
          // ignore: use_build_context_synchronously
          final serverProvider = context.read<ServerProvider>();
          serverProvider.device = availableDevices.keys.first;
          serverProvider.gpuLayers = 999;
          if (mounted) setState(() {});
        }
      });
      modelPathController.text = ServerProvider.modelPath;
    });
  }

  Future<void> _loadAvailableDevices() async {
    setState(() {
      isLoadingDevices = true;
    });

    try {
      final serverProvider = context.read<ServerProvider>();
      final devices = await serverProvider.getListDevices();
      setState(() {
        availableDevices = devices;
        isLoadingDevices = false;
      });
    } catch (e) {
      setState(() {
        isLoadingDevices = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverProvider = context.watch<ServerProvider>();
    final theme = FluentTheme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final lighterGreenTextStyle = TextStyle(
      color: Colors.green.lighter,
      fontFamily: 'Consolas',
      fontSize: 12,
      height: 1.4,
    );
    return StreamBuilder(
        stream: ServerProvider.serverStatusStream,
        builder: (context, asyncSnapshot) {
          final isRunning = asyncSnapshot.data ?? false;
          return ScaffoldPage.scrollable(
            header: PageHeader(
              leading: IconButton(
                icon: const Icon(FluentIcons.arrow_left_24_filled, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text('Local AI Server'),
            ),
            children: [
              // Status Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isRunning
                        ? [Colors.green.withAlpha(26), Colors.teal.withAlpha(26)]
                        : [Colors.orange.withAlpha(26), Colors.red.withAlpha(26)],
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(
                    color: isRunning ? Colors.green.withAlpha(77) : Colors.orange.withAlpha(77),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isRunning ? Colors.green : Colors.orange,
                        borderRadius: const BorderRadius.all(Radius.circular(20)),
                      ),
                      child: Icon(
                        isRunning ? FluentIcons.play_24_filled : FluentIcons.stop_24_filled,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRunning ? 'Server Running' : 'Server Stopped',
                            style: theme.typography.subtitle?.copyWith(
                              color: isRunning ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: isRunning
                                                  ? 'Ready to process requests at ${ServerProvider.serverUrl}'
                                                  : 'Configure and start server at ${ServerProvider.serverUrl}',
                                            ),
                                            WidgetSpan(
                                              child: SqueareIconButtonSized(
                                                height: 24,
                                                width: 24,
                                                onTap: () {
                                                  Clipboard.setData(ClipboardData(text: ServerProvider.serverUrl));
                                                  displayCopiedToClipboard();
                                                },
                                                icon: Icon(FluentIcons.copy_16_filled),
                                                tooltip: 'Copy to clipboard',
                                              ),
                                            )
                                          ],
                                        ),
                                        style: theme.typography.body?.copyWith(
                                          color: isDarkMode ? Colors.white.withAlpha(179) : Colors.black.withAlpha(179),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: TextFormBox(
                                  initialValue: ServerProvider.serverPort.toString(),
                                  enabled: !ServerProvider.isServerRunning,
                                  expands: false,
                                  onChanged: (value) {
                                    ServerProvider.serverPort = int.tryParse(value) ?? 1235;
                                    ServerProvider.serverUrl =
                                        'http://${ServerProvider.serverHost}:${ServerProvider.serverPort}';
                                    AppCache.localServerPort.value = ServerProvider.serverPort;
                                    if (mounted) setState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Model Configuration
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white.withAlpha(13) : Colors.black.withAlpha(5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode ? Colors.white.withAlpha(26) : Colors.black.withAlpha(26),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Model Path',
                      style: theme.typography.body?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextFormBox(
                      controller: modelPathController,
                      onChanged: (value) => ServerProvider.modelPath = value,
                      placeholder: 'Enter or choose a model file path or Hugging face URL...',
                    ),
                    const SizedBox(height: 16),
                    Button(
                      onPressed: () async {
                        FilePickerResult? result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['gguf'],
                          allowMultiple: false,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          ServerProvider.modelPath = result.files.first.path!;
                        }
                      },
                      child: const Text('Choose Model File'),
                    ),
                    Button(
                      child: Text('Select trusty model'),
                      onPressed: () async {
                        final model = await ChooseHfModelDialog.show(context);
                        if (model != null) {
                          modelPathController.text = model.modelPath;
                        }
                      },
                    ),
                    Button(
                      child: Text('List HF models'),
                      onPressed: () async {
                        final selected = await ListHuggingFaceModelsDialog.show(context);
                        if (selected != null) {
                          modelPathController.text = selected.modelPath;
                          ServerProvider.modelPath = selected.modelPath;
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Advanced Configuration
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white.withAlpha(13) : Colors.black.withAlpha(5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode ? Colors.white.withAlpha(26) : Colors.black.withAlpha(26),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Advanced Configuration',
                      style: theme.typography.subtitle?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),

                    // First row: Context Size, Predict, Flash Attention
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Context Size',
                                style: theme.typography.body?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              TextFormBox(
                                placeholder: 'Auto (0)',
                                initialValue: serverProvider.ctxSize.toString(),
                                onChanged: (value) {
                                  final parsed = int.tryParse(value);
                                  AppCache.localServerCtxSize.value = parsed;
                                  serverProvider.ctxSize = parsed;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Predict Tokens',
                                style: theme.typography.body?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              TextFormBox(
                                placeholder: 'Unlimited (-1)',
                                onChanged: (value) {
                                  final parsed = int.tryParse(value);
                                  serverProvider.nPredict = parsed;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Flash Attention',
                              style: theme.typography.body?.copyWith(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            ToggleSwitch(
                              checked: serverProvider.flashAttention,
                              onChanged: (value) {
                                setState(() {
                                  serverProvider.flashAttention = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Second row: CPU Threads, GPU Device
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CPU Threads',
                                style: theme.typography.body?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              TextFormBox(
                                placeholder: 'Auto (-1)',
                                onChanged: (value) {
                                  final parsed = int.tryParse(value);
                                  serverProvider.numberOfThreads = parsed == -1 ? null : parsed;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'GPU Device',
                                    style: theme.typography.body?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isLoadingDevices)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: ProgressRing(strokeWidth: 2),
                                    ),
                                  const Spacer(),
                                  Button(
                                    onPressed: _loadAvailableDevices,
                                    child: const Text('Refresh'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ComboBox<String>(
                                placeholder: const Text('CPU (Default)'),
                                isExpanded: true,
                                value: serverProvider.device,
                                items: [
                                  const ComboBoxItem<String>(
                                    value: null,
                                    child: Text('CPU (Default)'),
                                  ),
                                  ...availableDevices.entries.map(
                                    (entry) => ComboBoxItem<String>(
                                      value: entry.key,
                                      child: Text(entry.value, maxLines: 1),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    serverProvider.device = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Third row: Batch Size, GPU Layers
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Batch Size',
                                style: theme.typography.body?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              TextFormBox(
                                placeholder: 'Default',
                                onChanged: (value) {
                                  final parsed = int.tryParse(value);
                                  serverProvider.batchSize = parsed;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GPU Layers',
                                style: theme.typography.body?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              TextFormBox(
                                placeholder: 'e.g., 999 for full GPU',
                                onChanged: (value) {
                                  final parsed = int.tryParse(value);
                                  serverProvider.gpuLayers = parsed;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Server Controls
              Row(
                children: [
                  Expanded(
                    child: _buildGradientButton(
                      text: 'Start Server',
                      icon: FluentIcons.play_24_filled,
                      color: Colors.green,
                      onPressed: () async {
                        File file = modelPathController.text.isNotEmpty
                            ? File(modelPathController.text)
                            : File(ServerProvider.modelPath);

                        /// if exists then it is a local model
                        bool isHfModel = !file.existsSync();
                        if (isHfModel) {
                          final isDownloaded = PreviewHuggingFaceModel.isDownloaded(modelPathController.text);
                          if (!isDownloaded) {
                            final model = await PreviewHuggingFaceModel.show(context, modelPathController.text);
                            if (model != null) {
                              ServerProvider.modelPath = model.modelPath;
                            }
                          } else {
                            ServerProvider.modelPath = PreviewHuggingFaceModel.getModelPath(modelPathController.text);
                            isHfModel = false;
                          }
                        }
                        final res = await ServerProvider.startLlamaServer(
                          // ignore: use_build_context_synchronously
                          context: context,
                          modelPath: isHfModel ? null : ServerProvider.modelPath,
                          hfModelPath: isHfModel ? ServerProvider.modelPath : null,
                          ctxSize: serverProvider.ctxSize,
                          nPredict: serverProvider.nPredict,
                          flashAttention: serverProvider.flashAttention,
                          numberOfThreads: serverProvider.numberOfThreads,
                          device: serverProvider.device,
                          batchSize: serverProvider.batchSize,
                          gpuLayers: serverProvider.gpuLayers,
                          disableLogging: disableLogging,
                        );
                        if (res) {
                          ServerProvider.autoStopServerChanged(AppCache.autoStopServerEnabled.value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (isRunning)
                    Expanded(
                      child: _buildGradientButton(
                        text: 'Stop Server',
                        icon: FluentIcons.stop_24_filled,
                        color: Colors.red,
                        onPressed: () => ServerProvider.stopLlamaServer(),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Checkbox(
                    checked: AppCache.autoStopServerEnabled.value,
                    onChanged: (value) {
                      ServerProvider.autoStopServerChanged(value);
                      setState(() {});
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Release resources after:'),
                  ),
                  SizedBox(
                    width: 100,
                    child: NumberBox(
                      value: AppCache.autoStopServerAfter.value,
                      clearButton: false,
                      min: 1,
                      onChanged: (value) {
                        final val = value?.toString();
                        final parsed = int.tryParse(val ?? '10');
                        ServerProvider.autoStopServerValueChanged(parsed);
                        setState(() {});
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('minutes if no activity'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Terminal Output
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: isOutputHidden
                    ? 50
                    : isOutputExpanded
                        ? 900
                        : 300,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFF2D2D30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode ? Colors.white.withAlpha(26) : Colors.black.withAlpha(26),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!isOutputHidden)
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => setState(() => isOutputHidden = !isOutputHidden),
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(FluentIcons.dismiss_20_filled, size: 10),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              isOutputExpanded = !isOutputExpanded;
                              isOutputHidden = false;
                            }),
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(FluentIcons.arrow_maximize_16_filled, size: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Server Output',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Spacer(),
                        Button(
                          style: ButtonStyle(
                            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4, vertical: 2)),
                          ),
                          onPressed: () {
                            setState(() {
                              disableLogging = !disableLogging;
                            });
                          },
                          child: disableLogging
                              ? const Text('Enable logging', style: TextStyle(fontSize: 12))
                              : const Text('Disable logging', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              serverProvider.clearOutput();
                            },
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(FluentIcons.delete_24_regular, size: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!isOutputHidden)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: SingleChildScrollView(
                              reverse: true,
                              child: StreamBuilder<String>(
                                stream: ServerProvider.serverOutputStream,
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Text(
                                      'No output yet...',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontFamily: 'Consolas',
                                        fontSize: 12,
                                      ),
                                    );
                                  }

                                  return SelectableText(
                                    snapshot.data!,
                                    style: lighterGreenTextStyle,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        });
  }

  Widget _buildGradientButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 45,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            color: color,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
