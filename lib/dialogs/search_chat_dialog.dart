import 'dart:convert';

import 'package:fluent_gpt/common/attachment.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/widgets/message_list_tile.dart';
import 'package:fluent_gpt/widgets/zoom_hover.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:langchain/langchain.dart';

class SearchChatDialog extends StatefulWidget {
  const SearchChatDialog({super.key, required this.query});
  final String query;

  @override
  State<SearchChatDialog> createState() => _SearchChatDialogState();
}

class _SearchChatDialogState extends State<SearchChatDialog> {
  final Map<String, FluentChatMessage> _messages = {};
  final textController = TextEditingController();
  @override
  void initState() {
    textController.text = widget.query;
    super.initState();
  }

  void search() {
    final originalMessages = messages.value;
    _messages.clear();
    for (final entry in originalMessages.entries) {
      final message = entry.value;
      if (message.isTextMessage) {
        if (message.content.toLowerCase().contains(textController.text.toLowerCase())) {
          _messages[entry.key] = message;
        }
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Search in chat'),
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 1200),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextBox(
            autocorrect: true,
            autofocus: true,
            controller: textController,
            placeholder: 'Search...',
            onChanged: (value) => search(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final element = _messages.entries.elementAt(index);
                final message = element.value;
                if (message is CustomChatMessage) {
                  return const SizedBox.shrink();
                }
                if (message is HumanChatMessage && message.content is ChatMessageContentImage) {
                  return const SizedBox.shrink();
                }
                final words = message.content.split(' ');
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop(element.key);
                    },
                    child: Card(
                      margin: const EdgeInsets.all(4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message is HumanChatMessage) const Text('Human'),
                          if (message is AIChatMessage) const Text('AI'),
                          Text.rich(
                            TextSpan(
                              children: [
                                for (final word in words)
                                  TextSpan(
                                    text: '$word ',
                                    style: TextStyle(
                                      backgroundColor: word.toLowerCase().contains(textController.text.toLowerCase())
                                          ? Colors.yellow.withAlpha(127)
                                          : null,
                                      // color: word.toLowerCase().contains(
                                      //         textController.text.toLowerCase())
                                      //     ? Colors.black
                                      //     : null,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Dismiss'.tr),
        ),
      ],
    );
  }
}

// ChatImagesDialog class to display images from a chat in a dialog
class ChatImagesDialog extends StatelessWidget {
  const ChatImagesDialog({super.key});
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ChatImagesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageMessages = messages.value.values.where((element) {
      if (element.type == FluentChatMessageType.image || element.type == FluentChatMessageType.imageAi) {
        return true;
      }
      return false;
    }).toList();
    return ContentDialog(
      title: Text('Images in chat'.tr),
      constraints: const BoxConstraints(maxWidth: 1200),
      content: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: imageMessages.length,
        itemBuilder: (context, index) {
          final message = imageMessages[index];
          if (message is CustomChatMessage) {
            return const SizedBox.shrink();
          }
          if (message is HumanChatMessage && message.content is ChatMessageContentImage) {
            return const SizedBox.shrink();
          }
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                final image = decodeImage(message.content);
                final provider = Image.memory(
                  image,
                  filterQuality: FilterQuality.high,
                ).image;

                showDialog(
                  context: context,
                  barrierColor: Colors.black,
                  barrierDismissible: true,
                  builder: (context) {
                    return ImageViewerDialog(provider: provider, description: message.imagePrompt);
                  },
                );
              },
              child: ZoomHover(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode((message.content)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Dismiss'.tr),
        ),
      ],
    );
  }
}

class ImagesDialog extends StatelessWidget {
  const ImagesDialog({super.key, required this.images});
  final List<Attachment> images;
  static void show(BuildContext context, List<Attachment> images) {
    showDialog(context: context, builder: (ctx) => ImagesDialog(images: images));
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text('Images'.tr),
      content: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final file = images[index];
          if (file.isImage == true) {
            return GestureDetector(
              onTap: () async {
                final fileData = await file.file.readAsBytes();
                final provider = Image.memory(
                  fileData,
                  filterQuality: FilterQuality.high,
                ).image;

                showDialog(
                  // ignore: use_build_context_synchronously
                  context: context,
                  barrierColor: Colors.black,
                  barrierDismissible: true,
                  builder: (context) {
                    return ImageViewerDialog(
                      provider: provider,
                      description: file.name,
                    );
                  },
                );
              },
              child: ZoomHover(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    color: Colors.white,
                  ),
                  child: FutureBuilder(
                    future: file.readAsBytes(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            );
          }
          return ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Icon(FluentIcons.file_image, size: 48),
                  const SizedBox(height: 8),
                  Expanded(
                      child: Text(
                    file.name,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  )),
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Dismiss'.tr),
        ),
      ],
    );
  }
}
