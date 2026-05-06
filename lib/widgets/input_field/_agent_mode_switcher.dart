part of 'input_field_main.dart';

String _agentModeLabel(AgentMode mode) => switch (mode) {
  AgentMode.agent => 'Auto',
  AgentMode.ask => 'Ask',
  AgentMode.plan => 'Plan',
};

class AgentModeSwitcher extends StatefulWidget {
  const AgentModeSwitcher({super.key});
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

  static const icons = {
    'agent': Icon(ic.FluentIcons.sparkle_24_filled),
    'ask': Icon(ic.FluentIcons.chat_24_filled),
    'plan': Icon(ic.FluentIcons.text_bullet_list_24_filled),
  };

  @override
  State<AgentModeSwitcher> createState() => _AgentModeSwitcherState();
}

class _AgentModeSwitcherState extends State<AgentModeSwitcher> {
  FlyoutController? flyoutController;
  @override
  void initState() {
    flyoutController = FlyoutController();
    super.initState();
  }

  @override
  void dispose() {
    flyoutController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agentMode = context.select<ChatProvider, AgentMode>((provider) => provider.agentMode);
    final color = AgentModeSwitcher.colors[agentMode.name];
    final colorText = AgentModeSwitcher.colorsText[agentMode.name];
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          flyoutController!.showFlyout(
            builder: (context) => _AgentModeOptionsFlyout(flyoutController: flyoutController!),
          );
        },
        child: FlyoutTarget(
          controller: flyoutController!,
          child: Container(
            height: 30,
            width: 75,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 4),
                IconTheme(
                  data: IconThemeData(color: colorText, size: 20),
                  child: AgentModeSwitcher.icons[agentMode.name]!,
                ),
                Expanded(
                  child: Text(
                    _agentModeLabel(agentMode),
                    style: TextStyle(color: colorText, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    textAlign: TextAlign.center,
                  ),
                ),
                Icon(ic.FluentIcons.chevron_down_24_regular, size: 12, color: colorText),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentModeOptionsFlyout extends StatelessWidget {
  const _AgentModeOptionsFlyout({required this.flyoutController});
  final FlyoutController flyoutController;

  @override
  Widget build(BuildContext context) {
    return FlyoutContent(
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ...AgentMode.values.map(
              (e) {
                return Selector<ChatProvider, AgentMode>(
                  selector: (ctx, provider) => provider.agentMode,
                  builder: (context, agentMode, child) => HoverBasicListTile(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    color: Colors.transparent,
                    title: Text(_agentModeLabel(e)),
                    leading: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AgentModeSwitcher.icons[e.name],
                    ),
                    trailing: e == agentMode
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(mat.Icons.check_rounded),
                          )
                        : null,
                    onTap: () {
                      flyoutController.close();
                      context.read<ChatProvider>().setAgentMode(e);
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
