import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design/tokens.dart';
import '../models/chat_message.dart';
import '../providers/providers.dart';
import '../services/push_router.dart';
import 'chat/widgets/composer.dart';
import 'chat/widgets/message_bubble.dart';
import 'chat/widgets/quick_replies_bar.dart';

/// One-thread chat between the driver and dispatch.
///
/// Owns: the screen-lifecycle handshake with [ChatNotifier] (connect on
/// enter, schedule disconnect on leave / background) and the
/// scroll-on-arrival behaviour. Everything else lives in the provider.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  bool _composerHasText = false;
  int _lastMessageCount = 0;
  bool _wasAtBottom = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushRouter().setChatVisible(true);

    _inputController.addListener(() {
      final hasText = _inputController.text.trim().isNotEmpty;
      if (hasText != _composerHasText) {
        setState(() => _composerHasText = hasText);
      }
    });
    _scrollController.addListener(_onScroll);

    // ref.read inside initState requires a post-frame callback —
    // riverpod isn't ready until build completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).enterScreen();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PushRouter().setChatVisible(false);
    ref.read(chatProvider.notifier).leaveScreen();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lifecycle events can land in the queue *after* dispose() has
    // already torn the widget down — touching `ref` then throws
    // "Cannot use ref after the widget was disposed". The mounted
    // guard short-circuits that race.
    if (!mounted) return;
    final notifier = ref.read(chatProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      notifier.onAppForegrounded();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      notifier.onAppBackgrounded();
    }
  }

  void _onScroll() {
    // Scroll-back trigger: when user reaches near the top, fetch older.
    if (_scrollController.position.pixels <=
            _scrollController.position.minScrollExtent + 80 &&
        !_scrollController.position.outOfRange) {
      ref.read(chatProvider.notifier).loadOlder();
    }

    // Stick-to-bottom tracking: if the user has scrolled up, new
    // arrivals shouldn't yank them down. Tolerance ≈ one bubble.
    final position = _scrollController.position;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    _wasAtBottom = distanceFromBottom <= 120;
  }

  void _maybeScrollToBottom(int newCount) {
    if (newCount > _lastMessageCount && _wasAtBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    }
    if (_lastMessageCount == 0 && newCount > 0) {
      // First load — pin to bottom directly.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    }
    _lastMessageCount = newCount;
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    setState(() => _composerHasText = false);
    await ref.read(chatProvider.notifier).sendText(text);
  }

  Future<void> _handleQuickReply(ChatQuickReply reply) async {
    await ref.read(chatProvider.notifier).sendQuickReply(reply);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    _maybeScrollToBottom(state.messages.length);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ChatTopBar(isConnected: state.isConnected),
            if (state.loadError != null) _ErrorBanner(text: state.loadError!),
            Expanded(
              child: _MessageList(
                scrollController: _scrollController,
                state: state,
              ),
            ),
            if (state.sendError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageX,
                  4,
                  AppSpacing.pageX,
                  4,
                ),
                child: Text(
                  state.sendError!,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.accentDanger),
                ),
              ),
            QuickRepliesBar(
              visible: !_composerHasText && !state.isLoading,
              isSending: state.isSending,
              onPick: _handleQuickReply,
            ),
            ChatComposer(
              controller: _inputController,
              isSending: state.isSending,
              onSend: _handleSend,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTopBar extends StatelessWidget {
  final bool isConnected;

  const _ChatTopBar({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space2,
        AppSpacing.space2,
        AppSpacing.space3,
        AppSpacing.space3,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.fgPrimary,
              size: 22,
            ),
            onPressed: () => context.pop(),
            tooltip: 'Volver',
          ),
          const SizedBox(width: 2),
          // Lime avatar — Despacho identity, with subtle support-icon.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.limeSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.support_agent_rounded,
              size: 18,
              color: AppColors.lime,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Despacho',
                  style: AppTypography.h4.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _ConnectionDot(isConnected: isConnected),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? 'En línea' : 'Reconectando…',
                      style: AppTypography.monoSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionDot extends StatefulWidget {
  final bool isConnected;
  const _ConnectionDot({required this.isConnected});

  @override
  State<_ConnectionDot> createState() => _ConnectionDotState();
}

class _ConnectionDotState extends State<_ConnectionDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final color = widget.isConnected
            ? AppColors.accentLive
            : AppColors.accentWarning;
        return Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isConnected)
              Container(
                width: 6 + 8 * t,
                height: 6 + 8 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.35 * (1 - t)),
                ),
              ),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageX,
        vertical: AppSpacing.space2,
      ),
      color: AppColors.accentDangerDim.withValues(alpha: 0.3),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: AppColors.accentDanger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.fgPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final ScrollController scrollController;
  final ChatState state;

  const _MessageList({required this.scrollController, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accentLive,
          ),
        ),
      );
    }
    if (state.messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.fgSecondary,
                size: 22,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              'Sin mensajes',
              style: AppTypography.h4,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              'Cuando despacho te escriba o uses una respuesta rápida, aparecerá aquí.',
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
      itemCount:
          state.messages.length + (state.isLoadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (state.isLoadingOlder && index == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.space3),
            child: Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.fgTertiary,
                ),
              ),
            ),
          );
        }
        final adjusted =
            state.isLoadingOlder ? index - 1 : index;
        final msg = state.messages[adjusted];
        return MessageBubble(message: msg);
      },
    );
  }
}
