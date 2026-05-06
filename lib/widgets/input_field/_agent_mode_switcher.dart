part of 'input_field_main.dart';

class AgentModeSwitcher extends StatefulWidget {
  const AgentModeSwitcher({super.key});

  @override
  State<AgentModeSwitcher> createState() => _AgentModeSwitcherState();
}

class _AgentModeSwitcherState extends State<AgentModeSwitcher> {
  static const colors = {
    'agent': Color.fromRGBO(158, 158, 158, 0.2),
    'ask': mat.Color.fromRGBO(67, 160, 71, 0.2),
    'plan': mat.Color.fromRGBO(255, 111, 0, 0.2),
  };
  static const colorsText = {
    'agent': Color.fromRGBO(205, 205, 205, 1),
    'ask': mat.Color.fromRGBO(67, 160, 71, 1),
    'plan': mat.Color.fromRGBO(255, 111, 0, 1),
  };
  @override
  Widget build(BuildContext context) {
    final agentMode = context.select<ChatProvider, AgentMode>((provider) => provider.agentMode);
    final color = colors[agentMode.name];
    final colorText = colorsText[agentMode.name];
    return Container(
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: Text(agentMode.name, style: TextStyle(color: colorText)),
    );
  }
}
