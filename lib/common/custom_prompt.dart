import 'dart:convert';

import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:flutter/widgets.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:intl/intl.dart';

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

  /// If true will be shown in the context menu on right click
  final bool showInContextMenu;
  final bool showInHomePage;

  final List<String> tags;

  /// If not empty, this prompt will be shown as a dropdown
  final List<CustomPrompt> children;

  /// Shortcut for using this custom prompt
  final HotKey? hotkey;

  /// If true the main window will not be shown after the prompt is run
  /// and the result will be shown in Push notification
  final bool silentHideWindowsAfterRun;

  final bool includeSystemPrompt;
  final bool includeConversation;

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
    this.showInContextMenu = false,
    this.showInHomePage = true,
    this.children = const [],
    this.iconCodePoint = 62086,
    this.hotkey,
    this.tags = const [],
    this.silentHideWindowsAfterRun = false,
    this.includeSystemPrompt = true,
    this.includeConversation = true,
  });

  /// Returns the prompt text with the selected text
  /// If selectedText is null, it will be replaced with '<nothing selected>'
  /// The prompt also use the language from the lang BehaviorSubject
  String getPromptText([String? selectedText]) {
    final replacements = <String, String Function()>{
      '\${lang}': () => I18n.currentLocale.languageCode,
      '\${userInfo}': () => AppCache.userInfo.valueSync(),
      '\${timestamp}': () {
        final formatter = DateFormat('EEE d hh:mm a');
        return formatter.format(DateTime.now());
      },
      '\${systemInfo}': () => getSystemInfoString(),
      '\${clipboardAccess}': () =>
          AppCache.gptToolCopyToClipboardEnabled.value == true
              ? 'ENABLED'
              : 'RESTRICTED',
      '\${input}': () => selectedText ?? '<nothing selected>',
    };

    var result = prompt;

    /// Replace all the placeholders
    /// This should be faster then basing replaceAll on the whole string
    for (final entry in replacements.entries) {
      if (result.contains(entry.key)) {
        result = result.replaceAll(entry.key, entry.value());
      }
    }

    return result;
  }

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
      'showInContextMenu': showInContextMenu,
      'showInHomePage': showInHomePage,
      'children': children.map((e) => e.toJson()).toList(),
      'icon': iconCodePoint,
      'hotkey': hotkey?.toJson(),
      'index': index,
      'tags': tags,
      'silentHideWindowsAfterRun': silentHideWindowsAfterRun,
      'includeSystemPrompt': includeSystemPrompt,
      'includeConversation': includeConversation,
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
      showInHomePage: json['showInHomePage'] ?? true,
      index: json['index'] ?? 0,
      showInOverlay: json['showInOverlay'],
      showInContextMenu: json['showInContextMenu'] ?? false,
      children: (json['children'] is List)
          ? (json['children'] as List)
              .map((e) => CustomPrompt.fromJson(e))
              .toList()
          : [],
      iconCodePoint: json['icon'] as int? ?? 62086,
      hotkey: json['hotkey'] != null ? HotKey.fromJson(json['hotkey']) : null,
      tags: json['tags'] != null
          ? (json['tags'] as List).map((e) => e.toString()).toList()
          : [],
      silentHideWindowsAfterRun: json['silentHideWindowsAfterRun'] ?? false,
      includeSystemPrompt: json['includeSystemPrompt'] ?? true,
      includeConversation: json['includeConversation'] ?? true,
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
    bool? showInContextMenu,
    bool? showInHomePage,
    List<CustomPrompt>? children,
    HotKey? hotkey,
    bool? focusTheWindowOnRun,
    List<String>? tags,
    bool? silentHideWindowsAfterRun,
    bool? includeSystemPrompt,
    bool? includeConversation,
  }) {
    return CustomPrompt(
      id: id ?? this.id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      index: index ?? this.index,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      showInChatField: showInChatField ?? this.showInChatField,
      showInOverlay: showInOverlay ?? this.showInOverlay,
      showInContextMenu: showInContextMenu ?? this.showInContextMenu,
      showInHomePage: showInHomePage ?? this.showInHomePage,
      children: children ?? this.children,
      hotkey: hotkey ?? this.hotkey,
      tags: tags ?? this.tags,
      silentHideWindowsAfterRun:
          silentHideWindowsAfterRun ?? this.silentHideWindowsAfterRun,
      includeSystemPrompt: includeSystemPrompt ?? this.includeSystemPrompt,
      includeConversation: includeConversation ?? this.includeConversation,
    );
  }
}
