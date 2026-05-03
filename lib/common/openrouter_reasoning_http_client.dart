import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/openrouter_reasoning.dart';
import 'package:http/http.dart' as http;

/// Injects OpenRouter `reasoning: { enabled: true }` into POST /chat/completions bodies
/// when the current model requests vendor reasoning support.
class OpenRouterVendorReasoningHttpClient extends http.BaseClient {
  OpenRouterVendorReasoningHttpClient(
    this._inner, {
    required this.modelSelector,
  });

  final http.Client _inner;
  final ChatModelAi Function() modelSelector;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request &&
        request.method == 'POST' &&
        request.url.path.contains('chat/completions') &&
        request.body.isNotEmpty) {
      try {
        final model = modelSelector();
        request.body = applyOpenRouterVendorReasoningToJsonBody(request.body, model);
      } catch (_) {}
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
