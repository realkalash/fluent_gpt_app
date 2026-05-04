import 'dart:convert';

import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/openrouter_reasoning.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';

const _webSearchToolType = 'openrouter:web_search';

/// OpenRouter allows 1–25 results per search call for Exa / Parallel paths.
int clampOpenRouterWebSearchMaxResults(int value) => value.clamp(1, 25);

bool toolChoiceMeansDisableTools(dynamic toolChoice) {
  if (toolChoice == null) return false;
  if (toolChoice == 'none') return true;
  if (toolChoice is Map) {
    final mode = toolChoice['mode'];
    if (mode == 'none') return true;
  }
  return false;
}

/// Appends or updates the OpenRouter web search server tool on chat completions bodies.
///
/// See https://openrouter.ai/docs/guides/features/server-tools/web-search
void applyOpenRouterWebSearchToBodyMap(
  Map<String, dynamic> body,
  ChatModelAi model,
) {
  if (!isOpenRouterConfiguredModel(model)) return;
  if (toolChoiceMeansDisableTools(body['tool_choice'])) return;

  final stored = AppCache.openRouterWebSearchMaxResults.value ?? 5;
  final maxResults = clampOpenRouterWebSearchMaxResults(stored);

  final entry = <String, dynamic>{
    'type': _webSearchToolType,
    'parameters': <String, dynamic>{'max_results': maxResults},
  };

  final toolsRaw = body['tools'];
  if (toolsRaw is List) {
    final tools = toolsRaw;
    final idx = tools.indexWhere(
      (e) => e is Map && e['type'] == _webSearchToolType,
    );
    if (idx >= 0) {
      tools[idx] = entry;
    } else {
      tools.add(entry);
    }
    return;
  }

  body['tools'] = [entry];
  if (!body.containsKey('tool_choice') || body['tool_choice'] == null) {
    body['tool_choice'] = 'auto';
  }
}

/// Tool call names that OpenRouter may emit for [openrouter:web_search]; executed server-side.
bool isOpenRouterServerWebSearchToolInvocation(String toolName) {
  switch (toolName) {
    case 'web_search':
    case 'openrouter_web_search':
      return true;
    default:
      return false;
  }
}

/// Applies OpenRouter-specific POST body changes for `/v1/chat/completions`.
///
/// [includeWebSearchServerTool] is consulted only for OpenRouter models; default always includes.
String applyOpenRouterChatCompletionsBodyMutations(
  String bodyJson,
  ChatModelAi model, {
  bool Function()? includeWebSearchServerTool,
}) {
  final needsReasoning = shouldUseOpenRouterVendorReasoning(model);
  final isOpenRouter = isOpenRouterConfiguredModel(model);
  if (!needsReasoning && !isOpenRouter) return bodyJson;

  final includeWs = includeWebSearchServerTool ?? () => true;

  try {
    final decoded = jsonDecode(bodyJson);
    if (decoded is! Map) return bodyJson;
    final map = Map<String, dynamic>.from(decoded);
    applyOpenRouterVendorReasoningToBodyMap(map, model);
    if (isOpenRouter && includeWs()) {
      applyOpenRouterWebSearchToBodyMap(map, model);
    }
    return jsonEncode(map);
  } catch (_) {
    return bodyJson;
  }
}
