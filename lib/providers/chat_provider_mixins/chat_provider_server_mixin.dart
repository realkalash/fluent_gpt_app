import 'dart:io';
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/pages/preview_hf_model_dialog.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_gpt/providers/server_provider.dart';
import 'package:fluent_ui/fluent_ui.dart';

mixin ChatProviderServerMixin on ChangeNotifier, ChatProviderBaseMixin {
  void updateServerTimer() {
    if (AppCache.autoStopServerEnabled.value == true) {
      ServerProvider.resetAutoStopTimer();
    }
  }

  Future<bool> autoStartServer() async {
    /// TODO: add support for linux
    if (Platform.isLinux) return false;
    if (selectedModel.ownedBy == OwnedByEnum.localServer.name) {
      if (ServerProvider.isServerRunning || ServerProvider.modelPath.isEmpty) return false;
      File file = File(ServerProvider.modelPath);

      /// if exists then it is a local model
      bool isHfModel = !file.existsSync();
      if (isHfModel) {
        final isDownloaded = PreviewHuggingFaceModel.isDownloaded(ServerProvider.modelPath);
        if (!isDownloaded) {
          final model = await PreviewHuggingFaceModel.show(context!, ServerProvider.modelPath);
          if (model != null) {
            ServerProvider.modelPath = model.modelPath;
          }
        } else {
          ServerProvider.modelPath = PreviewHuggingFaceModel.getModelPath(ServerProvider.modelPath);
          isHfModel = false;
        }
      }
      final res = await ServerProvider.startLlamaServer(
        context: context!,
        modelPath: isHfModel ? null : ServerProvider.modelPath,
        hfModelPath: isHfModel ? ServerProvider.modelPath : null,
        ctxSize: 4096,
        // nPredict: SelectedModel.nPredict,
        // flashAttention: serverProvider.flashAttention,
        // numberOfThreads: serverProvider.numberOfThreads,
        device: AppCache.localServerDevice.value,
        // batchSize: serverProvider.batchSize,
        gpuLayers: 999,
        // disableLogging: true,
      );
      return res;
    }
    return false;
  }
}

