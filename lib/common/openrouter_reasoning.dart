import 'dart:convert';

import 'package:fluent_gpt/common/chat_model.dart';

/// True when this model configuration targets OpenRouter (preset or URL).
bool isOpenRouterConfiguredModel(ChatModelAi model) {
  if (model.ownedBy == OwnedByEnum.openrouter.name) return true;
  return false;
}

/// Whether to add OpenRouter's vendor `reasoning: { enabled: true }` to chat requests
/// during normal use (user must enable "Support reasoning?").
///
/// See: https://openrouter.ai/docs/use-cases/reasoning-tokens
bool shouldUseOpenRouterVendorReasoning(ChatModelAi model) {
  if (!model.reasoningSupported) return false;
  return isOpenRouterConfiguredModel(model);
}

/// Injects `reasoning.enabled: true` for OpenRouter.
///
/// [openRouterCapabilityProbe]: during "Test connection", inject even when
/// [ChatModelAi.reasoningSupported] is still false so we can detect reasoning
/// from the response and/or exercise models that require this field.
void applyOpenRouterVendorReasoningToBodyMap(
  Map<String, dynamic> body,
  ChatModelAi model, {
  bool openRouterCapabilityProbe = false,
}) {
  final inject = openRouterCapabilityProbe
      ? isOpenRouterConfiguredModel(model)
      : shouldUseOpenRouterVendorReasoning(model);
  if (!inject) return;
  final existing = body['reasoning'];
  if (existing is Map) {
    body['reasoning'] = <String, dynamic>{
      ...Map<String, dynamic>.from(existing),
      'enabled': true,
    };
  } else {
    body['reasoning'] = <String, dynamic>{'enabled': true};
  }
}

/// Returns updated JSON body, or original if no change (production path only).
String applyOpenRouterVendorReasoningToJsonBody(String bodyJson, ChatModelAi model) {
  if (!shouldUseOpenRouterVendorReasoning(model)) return bodyJson;
  try {
    final decoded = jsonDecode(bodyJson);
    if (decoded is! Map) return bodyJson;
    final map = Map<String, dynamic>.from(decoded);
    applyOpenRouterVendorReasoningToBodyMap(map, model);
    return jsonEncode(map);
  } catch (_) {
    return bodyJson;
  }
}

/// Non-streaming chat completion JSON: detects OpenRouter / vendor reasoning signals.
bool openRouterChatResponseIndicatesReasoning(Map<String, dynamic> responseBody) {
  final choices = responseBody['choices'];
  if (choices is! List || choices.isEmpty) return false;
  final first = choices[0];
  if (first is! Map) return false;
  final msg = first['message'];
  if (msg is! Map) return false;

  final reasoningDetails = msg['reasoning_details'];
  if (reasoningDetails is List && reasoningDetails.isNotEmpty) return true;

  final rc = msg['reasoning_content'];
  if (rc != null && rc.toString().trim().isNotEmpty) return true;

  final r = msg['reasoning'];
  if (r is Map && r.isNotEmpty) return true;
  if (r is String && r.trim().isNotEmpty) return true;

  final content = msg['content'];
  if (content is String && content.contains('<think>')) return true;

  return false;
}
