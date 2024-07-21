class ConversationLengthStyleEnum {
  final String name;
  final String? prompt;

  const ConversationLengthStyleEnum(this.name, this.prompt);

  static const ConversationLengthStyleEnum short =
      ConversationLengthStyleEnum('short', '(Keep answer short)');
  static const ConversationLengthStyleEnum normal =
      ConversationLengthStyleEnum('normal', null);
  static const ConversationLengthStyleEnum detailed =
      ConversationLengthStyleEnum('detailed', '(Be precise and detailed)');

  static List<ConversationLengthStyleEnum> values = [
    short,
    normal,
    detailed,
  ];

  static ConversationLengthStyleEnum? fromName(String name) {
    switch (name) {
      case 'short':
        return ConversationLengthStyleEnum.short;
      case 'normal':
        return ConversationLengthStyleEnum.normal;
      case 'detailed':
        return ConversationLengthStyleEnum.detailed;
      default:
        return null;
    }
  }

  @override
  String toString() {
    return name;
  }
}

class ConversationStyleEnum {
  final String name;
  final String? prompt;

  const ConversationStyleEnum(this.name, this.prompt);

  static const ConversationStyleEnum normal =
      ConversationStyleEnum('normal', null);
  static const ConversationStyleEnum business =
      ConversationStyleEnum('business', '(Use business language)');
  static const ConversationStyleEnum casual =
      ConversationStyleEnum('casual', '(Use casual language)');
  static const ConversationStyleEnum friendly =
      ConversationStyleEnum('friendly', '(Use friendly language)');
  static const ConversationStyleEnum professional =
      ConversationStyleEnum('professional', '(Use professional language)');
  static const ConversationStyleEnum seductive =
      ConversationStyleEnum('seductive', '(Be seductive in your answer)');

  static List<ConversationStyleEnum> values = [
    normal,
    business,
    casual,
    friendly,
    professional,
    seductive,
  ];

  static ConversationStyleEnum? fromName(String name) {
    switch (name) {
      case 'normal':
        return ConversationStyleEnum.normal;
      case 'business':
        return ConversationStyleEnum.business;
      case 'casual':
        return ConversationStyleEnum.casual;
      case 'friendly':
        return ConversationStyleEnum.friendly;
      case 'professional':
        return ConversationStyleEnum.professional;
      case 'seductive':
        return ConversationStyleEnum.seductive;
      default:
        return null;
    }
  }

  @override
  String toString() {
    return name;
  }
}
