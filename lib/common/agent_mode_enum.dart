enum AgentMode {
  agent,
  ask,
  plan;

  String get runtimeName => switch (this) {
        AgentMode.agent => 'auto',
        AgentMode.ask => 'ask',
        AgentMode.plan => 'plan',
      };
}

class AgentModeUtils {
  static AgentMode fromValue(int? value) {
    switch (value) {
      case 0:
        return AgentMode.agent;
      case 1:
        return AgentMode.ask;
      case 2:
        return AgentMode.plan;
      default:
        return AgentMode.agent;
    }
  }
}
