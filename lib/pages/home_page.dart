import 'dart:convert';

import 'package:chatgpt_windows_flutter_app/common/prefs/app_cache.dart';
import 'package:chatgpt_windows_flutter_app/dialogs/cost_dialog.dart';
import 'package:chatgpt_windows_flutter_app/log.dart';
import 'package:file_selector/file_selector.dart';
import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:chatgpt_windows_flutter_app/common/chat_room.dart';
import 'package:chatgpt_windows_flutter_app/file_utils.dart';
import 'package:chatgpt_windows_flutter_app/main.dart';
import 'package:chatgpt_windows_flutter_app/shell_driver.dart';
import 'package:chatgpt_windows_flutter_app/system_messages.dart';
import 'package:chatgpt_windows_flutter_app/theme.dart';
import 'package:chatgpt_windows_flutter_app/widgets/input_field.dart';
import 'package:chatgpt_windows_flutter_app/widgets/markdown_builders/md_code_builder.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:rxdart/rxdart.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;

import '../providers/chat_gpt_provider.dart';

final promptTextFocusNode = FocusNode();

class ChatRoomPage extends StatelessWidget {
  const ChatRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScaffoldPage(
      header: PageHeader(title: PageHeaderText()),
      content: Stack(
        children: [
          ChatGPTContent(),
          HomeDropOverlay(),
          HomeDropRegion(),
        ],
      ),
    );
  }
}

// isDropOverlayVisible is a BehaviorSubject that is used to show the overlay when a drag is over the drop region.
final BehaviorSubject<bool> isDropOverlayVisible =
    BehaviorSubject<bool>.seeded(false);

class HomeDropOverlay extends StatelessWidget {
  const HomeDropOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: isDropOverlayVisible,
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return Container(
            color: Colors.black.withOpacity(0.2),
            child: Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: FluentTheme.of(context).accentColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Center(
                  child: Icon(
                    FluentIcons.file_image,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class HomeDropRegion extends StatelessWidget {
  const HomeDropRegion({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ChatGPTProvider>();
    return DropRegion(
      // Formats this region can accept.
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.translucent,
      onDropOver: (event) {
        // This drop region only supports copy operation.
        if (event.session.allowedOperations.contains(DropOperation.copy)) {
          return DropOperation.copy;
        } else {
          return DropOperation.none;
        }
      },
      onDropEnter: (event) {
        // This is called when region first accepts a drag. You can use this
        // to display a visual indicator that the drop is allowed.
        isDropOverlayVisible.add(true);
      },
      onDropLeave: (event) {
        // Called when drag leaves the region. Will also be called after
        // drag completion.
        // This is a good place to remove any visual indicators.
        isDropOverlayVisible.add(false);
      },
      onPerformDrop: (event) async {
        // Called when user dropped the item. You can now request the data.
        // Note that data must be requested before the performDrop callback
        // is over.
        final item = event.session.items.first;

        // data reader is available now
        final reader = item.dataReader!;

        if (reader.canProvide(Formats.png)) {
          reader.getFile(Formats.png, (file) async {
            final data = await file.readAll();
            final xfile = XFile.fromData(
              data,
              name: file.fileName,
              mimeType: 'image/png',
              length: data.length,
            );
            log('File dropped: ${xfile.mimeType} ${data.length} bytes');
            provider.addFileToInput(xfile);
          }, onError: (error) {
            log('Error reading value $error');
          });
        }
      },
      child: const SizedBox.expand(),
    );
  }
}

class ModelChooserCards extends StatelessWidget {
  const ModelChooserCards({super.key});
  static const textStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold);

  Color applyOpacityIfSelected(bool isSelected, Color color) {
    if (!isSelected) {
      return color.withOpacity(0.2);
    }
    return color;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ChatGPTProvider>();
    return StreamBuilder<Map<String, ChatRoom>>(
        stream: chatRoomsStream,
        builder: (context, snapshot) {
          final currentChat = selectedChatRoomName;
          bool isGPT4O = selectedModel.model == 'gpt-4o';
          bool isGPT4 = selectedModel.model == 'gpt-4';
          bool isGPT3_5 = selectedModel.model == 'gpt-3.5-turbo';
          bool isLocal = selectedModel.model == 'local';
          return SizedBox(
            width: 400,
            height: 46,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        provider.selectModelForChat(currentChat, GPT4OModel()),
                    child: Card(
                      backgroundColor:
                          applyOpacityIfSelected(isGPT4O, Colors.blue),
                      child: const Text('GPT-4o',
                          style: textStyle, textAlign: TextAlign.center),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      provider.selectModelForChat(currentChat, Gpt4ChatModel());
                    },
                    child: Card(
                        backgroundColor:
                            applyOpacityIfSelected(isGPT4, Colors.yellow),
                        child: const Text('GPT-4',
                            style: textStyle, textAlign: TextAlign.center)),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => provider.selectModelForChat(
                        currentChat, GptTurboChatModel()),
                    child: Card(
                        backgroundColor:
                            applyOpacityIfSelected(isGPT3_5, Colors.green),
                        child: const Text('GPT-3.5',
                            style: textStyle, textAlign: TextAlign.center)),
                  ),
                ),
                GestureDetector(
                  onTap: () => provider.selectModelForChat(
                      currentChat, LocalChatModel()),
                  child: Card(
                    backgroundColor:
                        applyOpacityIfSelected(isLocal, Colors.purple),
                    child: const Text('Local',
                        style: textStyle, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          );
        });
  }
}

class PageHeaderText extends StatelessWidget {
  const PageHeaderText({super.key});

  Future<void> editChatRoomDialog(
      BuildContext context, ChatRoom room, ChatGPTProvider provider) async {
    var roomName = room.chatRoomName;
    var commandPrefix = room.systemMessage;
    var maxLength = room.maxTokenLength;
    var token = room.token;
    var orgID = room.orgID;
    await showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Edit chat room'),
        actions: [
          Button(
            onPressed: () {
              provider.editChatRoom(
                room.chatRoomName,
                room.copyWith(
                  chatRoomName: roomName,
                  commandPrefix: commandPrefix,
                  maxLength: maxLength,
                  token: token,
                  orgID: orgID,
                ),
                switchToForeground: true,
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
          Button(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
        content: ListView(
          shrinkWrap: true,
          children: [
            const Text('Chat room name'),
            TextBox(
              controller: TextEditingController(text: room.chatRoomName),
              onChanged: (value) {
                roomName = value;
              },
            ),
            const Text('Command prefix'),
            TextBox(
              controller: TextEditingController(text: room.systemMessage),
              onChanged: (value) {
                commandPrefix = value;
              },
            ),
            const Text('Max length'),
            TextBox(
              controller:
                  TextEditingController(text: room.maxTokenLength.toString()),
              onChanged: (value) {
                maxLength = int.parse(value);
              },
            ),
            const Text('Token'),
            TextBox(
              controller: TextEditingController(text: room.token),
              obscureText: true,
              onChanged: (value) {
                token = value;
              },
            ),
            const Text('Org ID'),
            TextBox(
              controller: TextEditingController(text: room.orgID),
              onChanged: (value) {
                orgID = value;
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var chatProvider = context.watch<ChatGPTProvider>();
    final selectedRoom = selectedChatRoomName;
    return Column(
      children: [
        GestureDetector(
          onTap: () => editChatRoomDialog(
              context, chatRooms[selectedRoom]!, chatProvider),
          child: Text(selectedRoom, maxLines: 2),
        ),
        const ModelChooserCards(),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Words: ${chatProvider.countWordsInAllMessages}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.normal),
                  ),
                  HyperlinkButton(
                    style: ButtonStyle(
                      padding: ButtonState.all(EdgeInsets.zero),
                    ),
                    onPressed: () => showCostCalculatorDialog(context),
                    child: Text(
                      ' Tokens: ${selectedChatRoom.tokens ?? 0} | ${(selectedChatRoom.costUSD ?? 0.0).toStringAsFixed(4)}\$',
                      style: const TextStyle(fontSize: 12),
                    ),
                  )
                ],
              ),
            ),
            const IncludeConversationSwitcher(),
            if (chatProvider.selectionModeEnabled) ...[
              IconButton(
                icon: Icon(ic.FluentIcons.delete_16_filled, color: Colors.red),
                onPressed: () {
                  chatProvider.deleteSelectedMessages();
                },
              ),
              IconButton(
                icon: const Icon(FluentIcons.cancel),
                onPressed: () {
                  chatProvider.disableSelectionMode();
                },
              ),
            ]
          ],
        ),
      ],
    );
  }

  void showCostCalculatorDialog(BuildContext context) {
    final tokens = selectedChatRoom.tokens ?? 0;
    showDialog(
      context: context,
      builder: (context) => CostDialog(tokens: tokens),
    );
  }
}

class IncludeConversationSwitcher extends StatelessWidget {
  const IncludeConversationSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatGPTProvider chatProvider = context.watch<ChatGPTProvider>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FlyoutListTile(
          text: const Icon(FluentIcons.full_history),
          tooltip: 'Include conversation',
          trailing: Checkbox(
            checked: chatProvider.includeConversationGlobal,
            onChanged: (value) {
              chatProvider.setIncludeWholeConversation(value ?? false);
            },
          ),
        ),
        FlyoutListTile(
          text: const Icon(FluentIcons.search_data),
          tooltip: 'Tool Search files',
          trailing: Checkbox(
            checked: AppCache.gptToolSearchEnabled.value!,
            onChanged: (value) {
              AppCache.gptToolSearchEnabled.value = value;
              // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
              chatProvider.notifyListeners();
            },
          ),
        ),
        FlyoutListTile(
          text: const Icon(FluentIcons.python_language),
          tooltip: 'Tool Python code execution',
          trailing: Checkbox(
            checked: AppCache.gptToolPythonEnabled.value!,
            onChanged: (value) {
              AppCache.gptToolPythonEnabled.value = value;
              // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
              chatProvider.notifyListeners();
            },
          ),
        ),
      ],
    );
  }
}

class ChatGPTContent extends StatefulWidget {
  const ChatGPTContent({super.key});

  @override
  State<ChatGPTContent> createState() => _ChatGPTContentState();
}

class _ChatGPTContentState extends State<ChatGPTContent> {
  @override
  void initState() {
    super.initState();
    promptTextFocusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      var chatProvider = context.read<ChatGPTProvider>();
      chatProvider.listItemsScrollController.animateTo(
        chatProvider.listItemsScrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    var chatProvider = context.watch<ChatGPTProvider>();
    chatProvider.context = context;

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: <Widget>[
            Expanded(
              child: StreamBuilder(
                  stream: chatRoomsStream,
                  builder: (context, snapshot) {
                    return ListView.builder(
                      controller: chatProvider.listItemsScrollController,
                      itemCount: messages.entries.length,
                      itemBuilder: (context, index) {
                        final message = messages.entries.elementAt(index).value;
                        final dateTimeRaw =
                            messages.entries.elementAt(index).value['created'];

                        return MessageCard(
                          id: messages.entries.elementAt(index).key,
                          message: message,
                          dateTime: DateTime.tryParse(dateTimeRaw ?? ''),
                          selectionMode: chatProvider.selectionModeEnabled,
                          isError: message['error'] == 'true',
                          textSize: chatProvider.textSize,
                        );
                      },
                    );
                  }),
            ),
            const HotShurtcutsWidget(),
            const InputField()
          ],
        ),
        const Positioned(
          bottom: 128,
          right: 16,
          child: _ScrollToBottomButton(),
        ),
      ],
    );
  }
}

class _ScrollToBottomButton extends StatefulWidget {
  const _ScrollToBottomButton({super.key});

  @override
  State<_ScrollToBottomButton> createState() => __ScrollToBottomButtonState();
}

class __ScrollToBottomButtonState extends State<_ScrollToBottomButton> {
  bool isAtBottom = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final chatProvider = context.read<ChatGPTProvider>();
      chatProvider.listItemsScrollController.addListener(() {
        if (mounted == false) return;
        final isAtBottomNew = chatProvider.listItemsScrollController.offset ==
            chatProvider.listItemsScrollController.position.maxScrollExtent;
        if (isAtBottom == isAtBottomNew) return;
        if (isAtBottomNew) {
          setState(() {
            isAtBottom = true;
          });
        } else {
          setState(() {
            isAtBottom = false;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isAtBottom) {
      return const SizedBox.shrink();
    }
    return SizedBox.square(
      dimension: 48,
      child: GestureDetector(
          onTap: () {
            final chatProvider = context.read<ChatGPTProvider>();
            chatProvider.listItemsScrollController.animateTo(
              chatProvider.listItemsScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            );
          },
          child: const Card(child: Icon(FluentIcons.down, size: 16))),
    );
  }
}

class MessageCard extends StatefulWidget {
  const MessageCard({
    super.key,
    required this.message,
    this.dateTime,
    required this.selectionMode,
    required this.id,
    required this.isError,
    required this.textSize,
  });
  final Map<String, String> message;
  final DateTime? dateTime;
  final bool selectionMode;
  final String id;
  final bool isError;
  final int textSize;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  bool _isMarkdownView = true;
  bool _containsCode = false;
  @override
  void initState() {
    super.initState();
    _isMarkdownView = prefs!.getBool('isMarkdownView') ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final formatDateTime = widget.dateTime == null
        ? ''
        : DateFormat('HH:mm:ss').format(widget.dateTime!);
    final appTheme = context.read<AppTheme>();
    final myMessageStyle = TextStyle(color: appTheme.color, fontSize: 14);
    final botMessageStyle = TextStyle(color: Colors.green, fontSize: 14);
    Widget tileWidget;
    Widget? leading = widget.selectionMode
        ? Checkbox(
            onChanged: (v) {
              final provider = context.read<ChatGPTProvider>();
              provider.toggleSelectMessage(widget.id);
            },
            checked: widget.message['selected'] == 'true',
          )
        : null;
    if (widget.message['role'] == 'user') {
      tileWidget = ListTile(
        leading: leading,
        tileColor: widget.message['commandMessage'] == 'true'
            ? ButtonState.all(Colors.blue.withOpacity(0.5))
            : null,
        contentPadding: EdgeInsets.zero,
        onPressed: () {
          final provider = context.read<ChatGPTProvider>();
          provider.toggleSelectMessage(widget.id);
        },
        title: Row(
          children: [
            Text('$formatDateTime ',
                style: FluentTheme.of(context).typography.caption!),
            Text('You:', style: myMessageStyle),
          ],
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.message['commandMessage'] == 'true')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Command prompt'),
                      IconButton(
                        icon: Icon(widget.message['hidePrompt'] == 'true'
                            ? FluentIcons.chevron_down
                            : FluentIcons.chevron_up),
                        onPressed: () {
                          final provider = context.read<ChatGPTProvider>();
                          provider.toggleHidePrompt(widget.id);
                        },
                      ),
                    ],
                  ),
                if (widget.message['hidePrompt'] != 'true')
                  SelectableText(
                    '${widget.message['content']}',
                    style: FluentTheme.of(context).typography.body?.copyWith(
                          fontSize: widget.textSize.toDouble(),
                        ),
                    selectionControls: fluentTextSelectionControls,
                  ),
              ],
            ),
            if (widget.message['image'] != null)
              GestureDetector(
                onTap: () {
                  _showImageDialog(context, widget.message);
                },
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 400,
                    height: 400,
                    margin: const EdgeInsets.all(8.0),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: 5,
                          )
                        ]),
                    child: Image.memory(
                      decodeImage(widget.message['image']!),
                      fit: BoxFit.fitHeight,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      tileWidget = ListTile(
        leading: leading,
        tileColor: widget.isError
            ? ButtonState.all(Colors.red.withOpacity(0.2))
            : null,
        onPressed: () {
          final provider = context.read<ChatGPTProvider>();
          provider.toggleSelectMessage(widget.id);
        },
        contentPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Text('$formatDateTime ',
                style: FluentTheme.of(context).typography.caption!),
            Text('${widget.message['role']}:', style: botMessageStyle),
          ],
        ),
        subtitle: !_isMarkdownView
            ? SelectableText(
                '${widget.message['content']}',
                style: FluentTheme.of(context).typography.body?.copyWith(
                      fontSize: widget.textSize.toDouble(),
                    ),
              )
            : Markdown(
                data: widget.message['content'] ?? '',
                softLineBreak: true,
                selectable: true,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(fontSize: widget.textSize.toDouble()),
                  code: TextStyle(
                    fontSize: widget.textSize.toDouble() + 2,
                    backgroundColor: Colors.transparent,
                  ),
                ),
                builders: {
                  'code': CodeElementBuilder(
                      isDarkTheme: FluentTheme.of(context).brightness ==
                          Brightness.dark),
                },
                onTapLink: (text, href, title) => launchUrlString(href!),
                extensionSet: md.ExtensionSet(
                  md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                  <md.InlineSyntax>[
                    md.EmojiSyntax(),
                    ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                  ],
                ),
              ),
      );
    }
    _containsCode = widget.message['content'].toString().contains('```');

    return Stack(
      children: [
        GestureDetector(
          onSecondaryTap: () {
            showDialog(
                context: context,
                builder: (ctx) {
                  final provider = context.read<ChatGPTProvider>();
                  return ContentDialog(
                    title: const Text('Message options'),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.message['image'] != null)
                          Container(
                            width: 100,
                            height: 100,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.0)),
                            child: Image.memory(
                              decodeImage(widget.message['image']!),
                              fit: BoxFit.fitHeight,
                              gaplessPlayback: true,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Button(
                          onPressed: () async {
                            Navigator.of(context).maybePop();

                            final item = DataWriterItem();
                            final imageBytesString = widget.message['image']!;
                            final imageBytes = base64.decode(imageBytesString);

                            item.add(Formats.png(imageBytes));
                            await SystemClipboard.instance!.write([item]);
                            // ignore: use_build_context_synchronously
                            displayCopiedToClipboard(context);
                          },
                          child: const Text('Copy image data'),
                        ),
                        const SizedBox(height: 8),
                        Button(
                          onPressed: () async {
                            final fileBytesString = widget.message['image']!;
                            final fileBytes = base64.decode(fileBytesString);
                            final file = XFile.fromData(
                              fileBytes,
                              name: 'image.png',
                              mimeType: 'image/png',
                              length: fileBytes.lengthInBytes,
                            );

                            final FileSaveLocation? location =
                                await getSaveLocation(
                              suggestedName: '${fileBytes.lengthInBytes}.png',
                              acceptedTypeGroups: [
                                const XTypeGroup(
                                  label: 'images',
                                  extensions: ['png', 'jpg', 'jpeg'],
                                ),
                              ],
                            );

                            if (location != null) {
                              await file.saveTo(location.path);
                              displayInfoBar(
                                // ignore: use_build_context_synchronously
                                context,
                                builder: (context, close) => const InfoBar(
                                  title: Text('Image saved to file'),
                                  severity: InfoBarSeverity.success,
                                ),
                              );
                              // ignore: use_build_context_synchronously
                              Navigator.of(context).maybePop();
                            }
                          },
                          child: const Text('Save image to file'),
                        ),
                        const SizedBox(height: 8),
                        Button(
                          onPressed: () {
                            Navigator.of(context).maybePop();
                            provider.toggleSelectMessage(widget.id);
                          },
                          child: const Text('Select'),
                        ),
                        const SizedBox(height: 8),
                        Button(
                          onPressed: () {
                            Navigator.of(context).maybePop();
                            _showRawMessageDialog(context, widget.message);
                          },
                          child: const Text('Show raw message'),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Divider(),
                        ),
                        if (provider.selectionModeEnabled)
                          Button(
                            onPressed: () {
                              Navigator.of(context).maybePop();
                              provider.mergeSelectedMessagesToAssistant();
                            },
                            child: Text(
                                'Merge ${provider.selectedMessages.length} messages'),
                          ),
                        const SizedBox(height: 8),
                        Button(
                            onPressed: () {
                              Navigator.of(context).maybePop();
                              if (provider.selectionModeEnabled) {
                                provider.deleteSelectedMessages();
                                provider.disableSelectionMode();
                              } else {
                                provider.deleteMessage(widget.id);
                              }
                            },
                            style: ButtonStyle(
                                backgroundColor: ButtonState.all(Colors.red)),
                            child: provider.selectionModeEnabled
                                ? Text(
                                    'Delete ${provider.selectedMessages.length}')
                                : const Text('Delete')),
                      ],
                    ),
                    actions: [
                      Button(
                        onPressed: () {
                          Navigator.of(context).maybePop();
                        },
                        child: const Text('Dismiss'),
                      ),
                    ],
                  );
                });
          },
          child: Card(
            margin: const EdgeInsets.all(4),
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(8.0),
            child: tileWidget,
          ),
        ),
        Positioned(
          right: 16,
          top: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: _isMarkdownView ? 'Show text' : 'Show markdown',
                child: SizedBox.square(
                  dimension: 30,
                  child: ToggleButton(
                    onChanged: (_) {
                      setState(() {
                        _isMarkdownView = !_isMarkdownView;
                      });
                      prefs!.setBool('isMarkdownView', _isMarkdownView);
                    },
                    checked: false,
                    child: const Icon(FluentIcons.format_painter, size: 10),
                  ),
                ),
              ),
              Tooltip(
                message: 'Edit message',
                child: SizedBox.square(
                  dimension: 30,
                  child: ToggleButton(
                    onChanged: (_) {
                      _showEditMessageDialog(context, widget.message);
                    },
                    checked: false,
                    child: const Icon(FluentIcons.edit, size: 10),
                  ),
                ),
              ),
              Tooltip(
                message: 'Copy text to clipboard',
                child: SizedBox.square(
                  dimension: 30,
                  child: ToggleButton(
                    onChanged: (_) {
                      Clipboard.setData(
                        ClipboardData(text: '${widget.message['content']}'),
                      );
                      displayCopiedToClipboard(context);
                    },
                    checked: false,
                    child: const Icon(FluentIcons.copy, size: 10),
                  ),
                ),
              ),
              if (_containsCode)
                Tooltip(
                  message: 'Copy python code to clipboard',
                  child: SizedBox.square(
                    dimension: 30,
                    child: ToggleButton(
                      onChanged: (_) {
                        _copyCodeToClipboard(
                            widget.message['content'].toString());
                      },
                      checked: false,
                      style: ToggleButtonThemeData(
                        uncheckedButtonStyle: ButtonStyle(
                            backgroundColor: ButtonState.all(Colors.blue)),
                      ),
                      child: const Icon(FluentIcons.code, size: 10),
                    ),
                  ),
                ),
              if (_containsCode)
                Tooltip(
                  message: 'Run python code',
                  child: RunCodeButton(
                    code: widget.message['content'].toString(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _copyCodeToClipboard(String string) {
    final code = getCodeFromMarkdown(string);
    log(code.toString());
    if (code.isEmpty) {
      displayInfoBar(
        context,
        builder: (context, close) => const InfoBar(
          title: Text('No code snippet found'),
          severity: InfoBarSeverity.warning,
        ),
      );
      return;
    }
    if (code.length == 1) {
      Clipboard.setData(ClipboardData(text: code.first));
      displayCopiedToClipboard(context);
      return;
    }
    // if more than one code snippet is found, show a dialog to select one
    chooseCodeBlockDialog(context, code);
  }

  void _showRawMessageDialog(
      BuildContext context, Map<String, String> message) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Raw message'),
        content: SelectableText.rich(
          TextSpan(
            children: [
              for (final entry in message.entries) ...[
                TextSpan(
                  text: '"${entry.key}": ',
                  style: TextStyle(color: Colors.blue),
                ),
                TextSpan(
                  text: '"${entry.value}",\n',
                  style: TextStyle(color: Colors.green),
                ),
              ],
            ],
          ),
          style: FluentTheme.of(context).typography.body,
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _showEditMessageDialog(
      BuildContext context, Map<String, String> message) {
    final contentController = TextEditingController(text: message['content']);
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Edit message'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const IncludeConversationSwitcher(),
            const SizedBox(height: 8),
            TextBox(
              controller: contentController,
              minLines: 5,
              maxLines: 10,
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () {
              final provider = context.read<ChatGPTProvider>();
              provider.editMessage(message, contentController.text);
              provider.regenerateMessage(message);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save & regenerate'),
          ),
          Button(
            onPressed: () {
              final provider = context.read<ChatGPTProvider>();
              provider.editMessage(message, contentController.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
          Button(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _showImageDialog(BuildContext context, Map<String, String> message) {
    final image = decodeImage(message['image']!);
    final provider = Image.memory(
      image,
      filterQuality: FilterQuality.high,
    ).image;
    showImageViewer(context, provider);
  }

  @Deprecated('Not used')
  void _showContextMenuImage(
      BuildContext context, Map<String, String> message) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Image options'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              clipBehavior: Clip.antiAlias,
              decoration:
                  BoxDecoration(borderRadius: BorderRadius.circular(12.0)),
              child: Image.memory(
                decodeImage(message['image']!),
                fit: BoxFit.fitHeight,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(height: 8),
            Button(
              onPressed: () {
                Navigator.of(context).maybePop();
                Clipboard.setData(
                  ClipboardData(text: message['image']!),
                );
                displayCopiedToClipboard(context);
              },
              child: const Text('Copy image data'),
            ),
            // save to file
            Button(
              onPressed: () async {
                final fileBytesString = message['image']!;
                final fileBytes = base64.decode(fileBytesString);
                final file = XFile.fromData(
                  fileBytes,
                  name: 'image.png',
                  mimeType: 'image/png',
                  length: fileBytes.length,
                );
                final first8Bytes = fileBytes.sublist(0, 8).toString();
                final FileSaveLocation? location = await getSaveLocation(
                  suggestedName: '$first8Bytes.png',
                  acceptedTypeGroups: [
                    const XTypeGroup(
                      label: 'images',
                      extensions: ['png', 'jpg', 'jpeg'],
                    ),
                  ],
                );

                if (location != null) {
                  // Save the file to the selected path
                  await file.saveTo(location.path);
                  // Optionally, show a confirmation message to the user
                }
              },
              child: const Text('Save image to file'),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
}

void displayCopiedToClipboard(BuildContext context) {
  displayInfoBar(
    context,
    builder: (context, close) => const InfoBar(
      title: Text('The result is copied to clipboard'),
      severity: InfoBarSeverity.info,
    ),
  );
}

void chooseCodeBlockDialog(BuildContext context, List<String> blocks) {
  showDialog(
    context: context,
    builder: (ctx) => ContentDialog(
      title: const Text('Choose code block'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final block in blocks) ...[
            ListTile(
              onPressed: () {},
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 30,
                    child: ToggleButton(
                      onChanged: (_) {
                        Clipboard.setData(ClipboardData(text: block));
                        displayCopiedToClipboard(context);
                      },
                      checked: false,
                      child: const Icon(FluentIcons.copy, size: 10),
                    ),
                  ),
                  RunCodeButton(code: block),
                ],
              ),
              subtitle: Markdown(
                data: '```python\n$block\n```',
                selectable: true,
                shrinkWrap: true,
                styleSheet: MarkdownStyleSheet(
                  code: const TextStyle(
                      fontSize: 14, backgroundColor: Colors.transparent),
                ),
                builders: {
                  'code': CodeElementBuilder(
                      isDarkTheme: FluentTheme.of(context).brightness ==
                          Brightness.dark),
                },
              ),
            ),
          ],
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Dismiss'),
        ),
      ],
    ),
  );
}

/// Extracts code snippets from a given assistant content.
///
/// The [assistantContent] parameter is the content provided by the assistant.
/// It searches for specific patterns using regular expressions and extracts the code snippets.
/// The extracted code snippets are returned as a list of strings.
List<String> getCodeFromMarkdown(String assistantContent) {
  List<String> codeList = [];

  final regexList = [
    shellCommandRegex,
    pythonCommandRegex,
    everythingSearchCommandRegex,
    copyToCliboardRegex,
  ];

  for (final regex in regexList) {
    final matches = regex.allMatches(assistantContent);
    for (final match in matches) {
      final command = match.group(1);
      if (command != null) {
        codeList.add(command);
      }
    }
  }
  if (codeList.isEmpty) {
    final unknownMatches = unknownCodeBlockRegex.allMatches(assistantContent);
    for (final match in unknownMatches) {
      final command = match.group(2);
      if (command != null) {
        codeList.add(command);
      }
    }
  }

  return codeList;
}

class RunCodeButton extends StatelessWidget {
  const RunCodeButton({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 30,
      child: StreamBuilder(
        stream: ShellDriver.isRunningStream,
        builder: (BuildContext ctx, AsyncSnapshot<dynamic> snap) {
          late Widget child;
          if (snap.data == true) {
            child = const Icon(FluentIcons.progress_ring_dots, size: 10);
          } else {
            child = const Icon(FluentIcons.play_solid, size: 10);
          }
          return ToggleButton(
            onChanged: (_) async {
              final provider =
                  Provider.of<ChatGPTProvider>(context, listen: false);
              final codeBlocks = getCodeFromMarkdown(code);
              if (codeBlocks.length > 1) {
                chooseCodeBlockDialog(context, codeBlocks);
                return;
              }

              if (shellCommandRegex.hasMatch(code)) {
                final match = shellCommandRegex.firstMatch(code);
                final command = match?.group(1);
                if (command != null) {
                  final result = await ShellDriver.runShellCommand(command);
                  provider.sendResultOfRunningShellCode(result);
                }
              } else if (pythonCommandRegex.hasMatch(code)) {
                final match = pythonCommandRegex.firstMatch(code);
                final command = match?.group(1);
                if (command != null) {
                  final result = await ShellDriver.runPythonCode(command);
                  provider.sendResultOfRunningShellCode(result);
                }
              }
            },
            checked: snap.data == true,
            style: ToggleButtonThemeData(
              uncheckedButtonStyle:
                  ButtonStyle(backgroundColor: ButtonState.all(Colors.green)),
            ),
            child: child,
          );
        },
      ),
    );
  }
}
