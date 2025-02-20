
import 'package:entry/entry.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:provider/provider.dart';

class CommandRequestAnswerOverlay extends StatefulWidget {
  const CommandRequestAnswerOverlay({
    super.key,
    required this.message,
    required this.screenSize,
    required this.initPosTop,
    required this.initPosLeft,
  });
  final FluentChatMessage message;
  final Size screenSize;
  final double initPosTop;
  final double initPosLeft;

  @override
  State<CommandRequestAnswerOverlay> createState() =>
      CommandRequestAnswerOverlayState();
}

class CommandRequestAnswerOverlayState
    extends State<CommandRequestAnswerOverlay> {
  FluentChatMessage? answer;
  bool isAnwering = true;
  void close() {
    final provider = context.read<ChatProvider>();
    provider.closeQuickOverlay();
  }

  int responseTokens = 0;

  Stream<ChatResult>? answerStream;

  Future sendMessageToAi() async {
    isAnwering = true;
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));
    final options = ChatOpenAIOptions(
      model: selectedChatRoom.model.modelName,
      maxTokens: selectedChatRoom.maxTokenLength,
    );
    if (selectedChatRoom.model.ownedBy == 'openai') {
      answerStream = openAI!.stream(
        PromptValue.string(widget.message.content),
        options: options,
      );
    } else {
      answerStream = localModel!.stream(
        PromptValue.string(widget.message.content),
        options: options,
      );
    }
    String responseId = '-1';
    answerStream!.listen((chunk) {
      final message = chunk.output;
      // log tokens
      if (message.content.isNotEmpty) {
        responseId = chunk.id;
        final time = DateTime.now().millisecondsSinceEpoch;
        if (answer == null) {
          answer = FluentChatMessage.ai(
            id: responseId,
            content: message.content,
            creator: 'AI',
            timestamp: time,
          );
        } else {
          answer = answer!.concat(message.content);
        }
      }
      if (chunk.usage.responseTokens != null) {
        responseTokens += chunk.usage.responseTokens!;
      }
      setState(() {});
    });
    isAnwering = false;
    setState(() {});
  }

  @override
  initState() {
    posTop = widget.initPosTop;
    posLeft = widget.initPosLeft;
    super.initState();
    sendMessageToAi();
  }
  double posTop = 0;
  double posLeft = 0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: posTop,
      left: posLeft,
      child: Entry.all(
        child: GestureDetector(
          onPanUpdate: (details) {
            posTop += details.delta.dy;
            posLeft += details.delta.dx;
            setState(() {});
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Acrylic(
              blurAmount: 5,
              tint: Colors.black,
              child: AnimatedContainer(
                constraints: BoxConstraints(
                  minHeight: 100,
                  minWidth: 100,
                  // maxHeight: widget.screenSize.height * 0.5,
                  maxWidth: 500,
                ),
                duration: Duration(milliseconds: 500),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            icon: Text('X', style: TextStyle(color: Colors.red)),
                            onPressed: close),
                        const SizedBox(width: 8),
                        Text(
                          'T: $responseTokens, R: ${widget.message.tokens}',
                          style: TextStyle(
                              color: Colors.white.withAlpha(128), fontSize: 10),
                        ),
                      ],
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: widget.screenSize.height * 0.4,
                        minWidth: 100,
                        maxWidth: 500,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (answer?.content != null)
                              SelectableText(
                                answer!.content,
                                style: TextStyle(color: Colors.white, fontSize: 18),
                              ),
                            if (isAnwering) ProgressBar(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}