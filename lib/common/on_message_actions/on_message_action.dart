class OnMessageAction {
  final String actionName;
  final RegExp regExp;
  final OnMessageActionEnum actionEnum;

  OnMessageAction({
    required this.regExp,
    required this.actionName,
    this.actionEnum = OnMessageActionEnum.none,
  });

  Map<String, dynamic> toJson() => {
        'actionName': actionName,
        'regExp': regExp.pattern,
        'actionEnum': actionEnum.index,
      };

  factory OnMessageAction.fromJson(Map<String, dynamic> json) {
    return OnMessageAction(
      actionName: json['actionName'],
      regExp: RegExp(json['regExp']),
      actionEnum: OnMessageActionEnum.values[json['actionEnum'] ?? 0],
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
          actionEnum == other.actionEnum;

  @override
  int get hashCode =>
      actionName.hashCode ^ regExp.pattern.hashCode ^ actionEnum.hashCode;
}

enum OnMessageActionEnum {
  none,
  copyText,
  copyTextInsideQuotes,
  openUrl,
  runShellCommand,
}
