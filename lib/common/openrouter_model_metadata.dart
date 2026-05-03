import 'dart:convert';

import 'package:fluent_gpt/log.dart';

/// OpenRouter `GET /v1/models` entry (subset of fields we use for UI).
class OpenRouterModelMeta {
  const OpenRouterModelMeta({
    required this.id,
    this.name,
    this.description,
    this.contextLength,
    this.canonicalSlug,
    this.inputModalities = const [],
    this.outputModalities = const [],
    this.modality,
    this.instructType,
    this.tokenizer,
    this.supportedParameters = const [],
    this.pricingPrompt,
    this.pricingCompletion,
    this.detailsUrl,
  });

  final String id;
  final String? name;
  final String? description;
  final int? contextLength;
  final String? canonicalSlug;
  final List<String> inputModalities;
  final List<String> outputModalities;
  final String? modality;
  final String? instructType;
  final String? tokenizer;
  final List<String> supportedParameters;
  final String? pricingPrompt;
  final String? pricingCompletion;
  final String? detailsUrl;

  static const _openRouterOrigin = 'https://openrouter.ai';

  static OpenRouterModelMeta? tryParseMap(Map<String, dynamic> row) {
    final id = row['id'];
    if (id is! String || id.isEmpty) return null;

    final architecture = row['architecture'];
    Map<String, dynamic>? arch;
    if (architecture is Map<String, dynamic>) {
      arch = architecture;
    } else if (architecture is Map) {
      arch = Map<String, dynamic>.from(architecture);
    }

    List<String> stringList(dynamic v) {
      if (v is! List) return const [];
      return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }

    int? intOrNull(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return null;
    }

    String? pricingField(Map<String, dynamic>? pricing, String key) {
      if (pricing == null) return null;
      final v = pricing[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    Map<String, dynamic>? pricing;
    final p = row['pricing'];
    if (p is Map<String, dynamic>) {
      pricing = p;
    } else if (p is Map) {
      pricing = Map<String, dynamic>.from(p);
    }

    String? detailsUrl;
    final links = row['links'];
    Map<String, dynamic>? linksMap;
    if (links is Map<String, dynamic>) {
      linksMap = links;
    } else if (links is Map) {
      linksMap = Map<String, dynamic>.from(links);
    }
    final details = linksMap?['details'];
    if (details is String && details.isNotEmpty) {
      detailsUrl = details.startsWith('http') ? details : '$_openRouterOrigin$details';
    }

    return OpenRouterModelMeta(
      id: id,
      name: row['name'] as String?,
      description: row['description'] as String?,
      contextLength: intOrNull(row['context_length']),
      canonicalSlug: row['canonical_slug'] as String?,
      inputModalities: arch == null ? const [] : stringList(arch['input_modalities']),
      outputModalities: arch == null ? const [] : stringList(arch['output_modalities']),
      modality: arch?['modality'] as String?,
      instructType: arch?['instruct_type'] as String?,
      tokenizer: arch?['tokenizer']?.toString(),
      supportedParameters: stringList(row['supported_parameters']),
      pricingPrompt: pricingField(pricing, 'prompt'),
      pricingCompletion: pricingField(pricing, 'completion'),
      detailsUrl: detailsUrl,
    );
  }
}

/// Parses OpenRouter-style `GET /models` JSON body into a map by model id.
Map<String, OpenRouterModelMeta> parseOpenRouterModelsListResponse(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return {};
    final data = decoded['data'];
    if (data is! List) return {};
    final out = <String, OpenRouterModelMeta>{};
    for (final item in data) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final meta = OpenRouterModelMeta.tryParseMap(row);
      if (meta != null) {
        out[meta.id] = meta;
      }
    }
    return out;
  } catch (e, st) {
    log('parseOpenRouterModelsListResponse: $e\n$st');
    return {};
  }
}

bool _listContainsInsensitive(Iterable<String> items, String needle) {
  final n = needle.toLowerCase();
  for (final s in items) {
    if (s.toLowerCase() == n) return true;
  }
  return false;
}

bool metaSuggestsImageInput(OpenRouterModelMeta m) {
  return _listContainsInsensitive(m.inputModalities, 'image');
}

bool metaSuggestsTools(OpenRouterModelMeta m) {
  for (final p in m.supportedParameters) {
    final lower = p.toLowerCase();
    if (lower == 'tools' || lower == 'tool_choice') return true;
  }
  return false;
}

bool metaSuggestsReasoning(OpenRouterModelMeta m) {
  for (final p in m.supportedParameters) {
    final lower = p.toLowerCase();
    if (lower == 'reasoning' ||
        lower == 'include_reasoning' ||
        lower == 'reasoning_effort') {
      return true;
    }
  }
  return false;
}

/// Whether the OpenRouter `/models` entry includes fields we use for capability hints.
///
/// When true, the Add Model flow can set capability checkboxes from metadata and
/// skip runtime probes for vision, tools, and reasoning.
bool openRouterMetaListsCapabilities(OpenRouterModelMeta m) {
  if (m.supportedParameters.isNotEmpty) return true;
  if (m.inputModalities.isNotEmpty || m.outputModalities.isNotEmpty) return true;
  if (m.modality != null && m.modality!.trim().isNotEmpty) return true;
  return false;
}

/// Parses OpenRouter [pricing.prompt] / [pricing.completion] strings.
///
/// The API uses **USD per token** (e.g. `0.00003` → \$30 / 1M tokens). We convert
/// to **USD per 1M tokens** for display.
double? openRouterPriceToUsdPerMillionTokens(String? raw) {
  if (raw == null) return null;
  final v = double.tryParse(raw.trim());
  if (v == null) return null;
  return v * 1e6;
}

/// Trims trailing zeros and a leftover decimal point from a fixed-point amount.
String _trimUsdFraction(String s) {
  if (!s.contains('.')) return s;
  s = s.replaceFirst(RegExp(r'0+$'), '');
  if (s.endsWith('.')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// Renders [perM] (USD per 1M tokens) without unnecessary trailing zeros.
String _formatUsdPerMillionAmount(double perM) {
  if (perM == 0) return '0';
  // Enough fractional digits for sub-cent prices; then trim (.000, .5000, etc.).
  final s = perM.toStringAsFixed(8);
  return _trimUsdFraction(s);
}

/// Compact dollar string for per-1M-token price (e.g. `\$1.25`, `\$2`, `\$0.5`).
String formatOpenRouterUsdPerMillionLabel(String? raw) {
  final perM = openRouterPriceToUsdPerMillionTokens(raw);
  if (perM == null) {
    final s = raw?.trim();
    return (s == null || s.isEmpty) ? '—' : s;
  }
  if (perM == 0) {
    return '\$0';
  }
  return '\$${_formatUsdPerMillionAmount(perM)}';
}

String openRouterModalitySummary(OpenRouterModelMeta m) {
  if (m.modality != null && m.modality!.isNotEmpty) {
    return m.modality!;
  }
  final ins = m.inputModalities.join(',');
  final outs = m.outputModalities.join(',');
  if (ins.isEmpty && outs.isEmpty) return '';
  if (outs.isEmpty) return ins;
  if (ins.isEmpty) return '→ $outs';
  return '$ins → $outs';
}

/// Single scannable line for autosuggest subtitle (price + capabilities).
String? formatOpenRouterAutosuggestSubtitle(OpenRouterModelMeta m) {
  final parts = <String>[];
  final mod = openRouterModalitySummary(m);
  if (mod.isNotEmpty) parts.add(mod);
  if (m.contextLength != null) {
    final ctx = m.contextLength!;
    final ctxLabel = ctx >= 1000 ? '${(ctx / 1000).round()}k ctx' : '$ctx ctx';
    parts.add(ctxLabel);
  }
  if (m.pricingPrompt != null || m.pricingCompletion != null) {
    final pp = formatOpenRouterUsdPerMillionLabel(m.pricingPrompt);
    final pc = formatOpenRouterUsdPerMillionLabel(m.pricingCompletion);
    parts.add('in $pp · out $pc / 1M tok');
  }
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}
