import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/openrouter_web_search.dart';
import 'package:http/http.dart' as http;

/// Rewrites POST `/chat/completions` JSON for OpenRouter: vendor `reasoning.enabled`,
/// and optionally the `openrouter:web_search` server tool (see [includeWebSearchServerTool]).
class OpenRouterVendorReasoningHttpClient extends http.BaseClient {
  OpenRouterVendorReasoningHttpClient(
    this._inner, {
    required this.modelSelector,
    bool Function()? includeWebSearchServerTool,
  }) : includeWebSearchServerTool = includeWebSearchServerTool ?? (() => true);

  final http.Client _inner;
  final ChatModelAi Function() modelSelector;
  final bool Function() includeWebSearchServerTool;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request &&
        request.method == 'POST' &&
        request.url.path.contains('chat/completions') &&
        request.body.isNotEmpty) {
      try {
        final model = modelSelector();
        request.body = applyOpenRouterChatCompletionsBodyMutations(
          request.body,
          model,
          includeWebSearchServerTool: includeWebSearchServerTool,
        );
      } catch (_) {}
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
