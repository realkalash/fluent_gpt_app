final List<OnMessageAction> defaultCustomActionsList = [
  OnMessageAction(
    actionName: 'open url when contains quotes',
    regExp: RegExp(r"```open-url\n(.*?)\n```"),
    actionEnum: OnMessageActionEnum.openUrl,
    isEnabled: true,
  ),
  OnMessageAction(
    actionName: 'Copy to clipboard when contains quotes',
    regExp: RegExp(r"```clipboard\n(.*?)\n```"),
    actionEnum: OnMessageActionEnum.copyTextInsideQuotes,
    isEnabled: true,
  ),
  OnMessageAction(
    actionName: 'Auto Run shell',
    regExp: RegExp(r"```run-shell\n(.*?)\n```"),
    actionEnum: OnMessageActionEnum.runShellCommand,
    isEnabled: true,
  ),
  OnMessageAction(
    actionName: 'Generate image when contains quotes',
    regExp: RegExp(r"```image\n(.*?)\n```", caseSensitive: false),
    actionEnum: OnMessageActionEnum.generateImage,
    isEnabled: true,
  ),
  // OnMessageAction(
  //   actionName: 'Remember things',
  //   regExp: RegExp(r"```remember:(.*?)\n```", caseSensitive: false),
  //   actionEnum: OnMessageActionEnum.remember,
  //   isEnabled: true,
  // ),
];

class OnMessageAction {
  final String actionName;
  final RegExp regExp;
  final OnMessageActionEnum actionEnum;
  final bool isEnabled;

  const OnMessageAction({
    required this.regExp,
    required this.actionName,
    this.actionEnum = OnMessageActionEnum.none,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'actionName': actionName,
        'regExp': regExp.pattern,
        'actionEnum': actionEnum.index,
        'isEnabled': isEnabled,
      };

  factory OnMessageAction.fromJson(Map<String, dynamic> json) {
    return OnMessageAction(
      actionName: json['actionName'],
      regExp: RegExp(json['regExp']),
      actionEnum: OnMessageActionEnum.values[json['actionEnum'] ?? 0],
      isEnabled: json['isEnabled'] ?? true,
    );
  }

  @override
  String toString() {
    return 'OnMessageAction{actionName: $actionName, regExp: $regExp, actionEnum: $actionEnum}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnMessageAction &&
          runtimeType == other.runtimeType &&
          actionName == other.actionName &&
          regExp.pattern == other.regExp.pattern &&
          isEnabled == other.isEnabled &&
          actionEnum == other.actionEnum;

  @override
  int get hashCode =>
      actionName.hashCode ^
      regExp.pattern.hashCode ^
      actionEnum.hashCode ^
      isEnabled.hashCode;

  OnMessageAction copyWith({
    String? actionName,
    RegExp? regExp,
    OnMessageActionEnum? actionEnum,
    bool? isEnabled,
  }) {
    return OnMessageAction(
      actionName: actionName ?? this.actionName,
      regExp: regExp ?? this.regExp,
      actionEnum: actionEnum ?? this.actionEnum,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

enum OnMessageActionEnum {
  none,
  copyText,
  copyTextInsideQuotes,
  openUrl,
  runShellCommand,
  generateImage,
  remember,
}
