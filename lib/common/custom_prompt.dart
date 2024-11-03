import 'dart:convert';

import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:flutter/widgets.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class CustomPrompt {
  /// The id of the prompt
  final int id;

  /// The name of the prompt
  final String title;

  /// Index for sorting
  final int index;

  /// User can paste a custon prompt for chatGPT here
  /// He can use ${input} to refer to the selected text in the chat field
  final String prompt;

  /// Icon. The default is chat_20_filled (62086)
  final int iconCodePoint;

  /// If true will be shown above the chat input field as a button
  final bool showInChatField;

  /// If true will be shown in the overlay
  final bool showInOverlay;

  final List<String> tags;

  /// If not empty, this prompt will be shown as a dropdown
  final List<CustomPrompt> children;

  /// Shortcut for using this custom prompt
  final HotKey? hotkey;

  /// If true will automatically focus the window when the prompt is run
  final bool focusTheWindowOnRun;

  IconData get icon => IconData(iconCodePoint,
      fontFamily: CustomPrompt.fontFamily,
      fontPackage: CustomPrompt.fontPackage);

  const CustomPrompt({
    this.id = 0,
    required this.title,
    required this.prompt,
    this.index = 0,
    this.showInChatField = false,
    this.showInOverlay = false,
    this.children = const [],
    this.iconCodePoint = 62086,
    this.hotkey,
    this.focusTheWindowOnRun = false,
    this.tags = const [],
  });

  /// Returns the prompt text with the selected text
  /// If selectedText is null, it will be replaced with '<nothing selected>'
  /// The prompt also use the language from the lang BehaviorSubject
  String getPromptText([String? selectedText]) => prompt
      .replaceAll('\${lang}', defaultGPTLanguage.value)
      .replaceAll(
        '\${clipboardAccess}',
        AppCache.gptToolCopyToClipboardEnabled.value == true
            ? 'ENABLED'
            : 'RESTRICTED',
      )
      .replaceAll('\${input}', selectedText ?? '<nothing selected>');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomPrompt &&
        other.id == id &&
        other.title == title &&
        other.prompt == prompt;
  }

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ prompt.hashCode;

  @override
  String toString() {
    return 'CustomPrompt(id: $id, index:$index, title: $title, showInChatField: $showInChatField, showInOverlay: $showInOverlay, children: $children, icon: $iconCodePoint)';
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'prompt': prompt,
      'showInChatField': showInChatField,
      'showInOverlay': showInOverlay,
      'children': children.map((e) => e.toJson()).toList(),
      'icon': iconCodePoint,
      'hotkey': hotkey?.toJson(),
      'focusTheWindowOnRun': focusTheWindowOnRun,
      'index': index,
      'tags': tags,
    };
  }

  static const fontPackage = 'fluentui_system_icons';
  static const fontFamily = 'FluentSystemIcons-Filled';

  static CustomPrompt fromJson(Map<dynamic, dynamic> json) {
    return CustomPrompt(
      id: json['id'] ?? -1,
      title: json['title'],
      prompt: json['prompt'],
      showInChatField: json['showInChatField'],
      index: json['index'] ?? 0,
      showInOverlay: json['showInOverlay'],
      children: (json['children'] is List)
          ? (json['children'] as List)
              .map((e) => CustomPrompt.fromJson(e))
              .toList()
          : [],
      iconCodePoint: json['icon'] as int? ?? 62086,
      hotkey: json['hotkey'] != null ? HotKey.fromJson(json['hotkey']) : null,
      focusTheWindowOnRun: json['focusTheWindowOnRun'] ?? false,
      tags: json['tags'] != null
          ? (json['tags'] as List).map((e) => e.toString()).toList()
          : [],
    );
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  static CustomPrompt fromJsonString(String jsonString) {
    return fromJson(jsonDecode(jsonString));
  }

  CustomPrompt copyWith({
    int? id,
    String? title,
    String? prompt,
    int? index,
    int? iconCodePoint,
    bool? showInChatField,
    bool? showInOverlay,
    List<CustomPrompt>? children,
    HotKey? hotkey,
    bool? focusTheWindowOnRun,
    List<String>? tags,
  }) {
    return CustomPrompt(
      id: id ?? this.id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      index: index ?? this.index,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      showInChatField: showInChatField ?? this.showInChatField,
      showInOverlay: showInOverlay ?? this.showInOverlay,
      children: children ?? this.children,
      hotkey: hotkey ?? this.hotkey,
      focusTheWindowOnRun: focusTheWindowOnRun ?? this.focusTheWindowOnRun,
      tags: tags ?? this.tags,
    );
  }
}
