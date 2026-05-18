import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

mixin ChatProviderScrollingMixin on ChangeNotifier, ChatProviderBaseMixin {
  final ScrollController listItemsScrollController = ScrollController();

  // Key applied to the currently-streaming AI message's wrapper in the list.
  // Used by getOffsetToReveal to compute anchor-to-top / follow-on-overflow.
  final GlobalKey streamingMessageKey = GlobalKey();
  String? streamingMessageId;

  String? blinkMessageId;
  bool scrollToBottomOnAnswer = true;

  // How close to the follow target counts as "still following".
  static const double _stickyThreshold = 80.0;

  // True while we should auto-scroll to track the stream. Flips off when the
  // user manually scrolls away from the target; flips on again at the bottom.
  bool _isFollowingStream = true;
  bool get isFollowingStream => _isFollowingStream;

  // Guard so our own programmatic jumps don't trip the user-scroll listener.
  double _lastProgrammaticPixels = double.nan;

  bool _stickyScrollInitialized = false;

  void initStickyScroll() {
    if (_stickyScrollInitialized) return;
    _stickyScrollInitialized = true;
    listItemsScrollController.addListener(_onScrollChange);
  }

  void _onScrollChange() {
    if (!listItemsScrollController.hasClients) return;
    final pos = listItemsScrollController.position;

    // Ignore the notification fired by our own jumpTo.
    if (!_lastProgrammaticPixels.isNaN &&
        (pos.pixels - _lastProgrammaticPixels).abs() < 0.5) {
      return;
    }

    final atBottom = pos.pixels >= pos.maxScrollExtent - _stickyThreshold;
    if (atBottom != _isFollowingStream) {
      _isFollowingStream = atBottom;
      notifyListeners();
    }
  }

  void _programmaticJumpTo(double offset) {
    if (!listItemsScrollController.hasClients) return;
    final pos = listItemsScrollController.position;
    final clamped = offset.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    _lastProgrammaticPixels = clamped;
    listItemsScrollController.jumpTo(clamped);
  }

  /// Called by ChatProvider when a new AI response starts streaming.
  void markStreamingStart(String messageId) {
    streamingMessageId = messageId;
    _isFollowingStream = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _anchorStreamingToTop();
    });
  }

  void _anchorStreamingToTop() {
    if (!listItemsScrollController.hasClients) return;
    final ctx = streamingMessageKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject();
    if (box is! RenderBox) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final reveal = viewport.getOffsetToReveal(box, 0.0).offset;
    _programmaticJumpTo(reveal);
  }

  @override
  Future<void> scrollToEnd({bool withDelay = true}) async {
    try {
      if (withDelay) await Future.delayed(const Duration(milliseconds: 100));
      if (messages.value.isEmpty) return;
      if (!listItemsScrollController.hasClients) return;
      _isFollowingStream = true;
      final pos = listItemsScrollController.position;
      _lastProgrammaticPixels = pos.maxScrollExtent;
      await listItemsScrollController.animateTo(
        pos.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error while scrolling to end: $e');
      }
    }
  }

  /// Called on every streaming token. Anchors to the streaming message's
  /// bottom only once it has overflowed the viewport; otherwise no-op so the
  /// reader's view stays put.
  Future autoScrollToEnd({bool withDelay = true}) async {
    if (!scrollToBottomOnAnswer) return;
    if (!_isFollowingStream) return;
    if (!listItemsScrollController.hasClients) return;
    if (messages.value.isEmpty) return;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!listItemsScrollController.hasClients) return;
      final pos = listItemsScrollController.position;

      final ctx = streamingMessageKey.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject();
        if (box is RenderBox) {
          final viewport = RenderAbstractViewport.maybeOf(box);
          if (viewport != null) {
            final target = viewport.getOffsetToReveal(box, 1.0).offset;
            // Only scroll if the streaming message's bottom would otherwise be
            // hidden below the viewport (overflow case).
            if (pos.pixels < target - 0.5) {
              _programmaticJumpTo(target);
            }
            return;
          }
        }
      }
      // Fallback: no key context yet — just stay glued to the list bottom.
      if (pos.pixels < pos.maxScrollExtent - 0.5) {
        _programmaticJumpTo(pos.maxScrollExtent);
      }
    });
  }

  /// Deprecated: scroll-to-message navigation was dropped along with
  /// AutoScrollTag. The message still blinks for visual feedback.
  Future<void> scrollToMessage(String messageKey) async {
    blinkMessageId = messageKey;
    notifyListeners();
  }

  /// Deprecated: see [scrollToMessage].
  Future<void> scrollToIndex(int index) async {
    if (index < 0 || index >= messagesReversedList.length) return;
    blinkMessageId = messagesReversedList[index].id;
    notifyListeners();
  }
}
