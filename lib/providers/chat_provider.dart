import 'dart:async';
import 'dart:convert';

import 'package:centrifuge/centrifuge.dart' as cf;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import 'auth_provider.dart';

/// Idle window before the WebSocket is torn down once the chat screen
/// is no longer visible. Push notifications cover anything that lands
/// while the socket is down — the trade-off is battery + Centrifugo
/// connection count vs UX of micro-reconnects.
const Duration _kIdleDisconnectWindow = Duration(seconds: 30);

const int _kInitialLimit = 50;
const int _kScrollBackLimit = 50;

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isLoadingOlder;
  final bool hasMoreOlder;
  final bool isSending;
  final bool isConnected;
  final String? sendError;
  final String? loadError;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingOlder = false,
    this.hasMoreOlder = false,
    this.isSending = false,
    this.isConnected = false,
    this.sendError,
    this.loadError,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? hasMoreOlder,
    bool? isSending,
    bool? isConnected,
    String? sendError,
    String? loadError,
    bool clearSendError = false,
    bool clearLoadError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      isSending: isSending ?? this.isSending,
      isConnected: isConnected ?? this.isConnected,
      sendError: clearSendError ? null : (sendError ?? this.sendError),
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
    );
  }
}

/// Driver-side chat orchestrator.
///
/// Owns:
///   - the message list (initial fetch + paginated scroll-back + live).
///   - the Centrifugo client lifecycle (ephemeral: connect on screen
///     enter, disconnect [_kIdleDisconnectWindow] after leave/background).
///   - the "is the chat screen currently visible" flag, which the
///     OneSignal foreground handler reads to decide whether to suppress
///     the banner — we don't want a push popping over a live thread.
///
/// Does NOT own:
///   - navigation (router push from a notification tap lives in
///     PushRouter).
///   - sign-in/sign-out plumbing (auth_provider).
class ChatNotifier extends StateNotifier<ChatState> {
  final ChatService _service;
  final String? _driverId;
  final String? _companyId;

  cf.Client? _client;
  StreamSubscription<cf.ServerPublicationEvent>? _publicationSub;
  StreamSubscription<cf.ServerSubscribedEvent>? _subscribedSub;
  StreamSubscription<cf.ConnectedEvent>? _connectedSub;
  StreamSubscription<cf.DisconnectedEvent>? _disconnectedSub;

  Timer? _idleTimer;
  bool _screenVisible = false;
  bool _hadFirstSubscribe = false;
  String? _latestMessageId;

  /// True while the chat screen is in the foreground — read by the
  /// OneSignal `willDisplay` handler to suppress the banner.
  bool get isScreenVisible => _screenVisible;

  ChatNotifier({
    required ChatService service,
    required String? driverId,
    required String? companyId,
  })  : _service = service,
        _driverId = driverId,
        _companyId = companyId,
        super(const ChatState());

  // ── Screen lifecycle ──────────────────────────────────────────────

  /// Call from the chat screen's `initState`.
  Future<void> enterScreen() async {
    _screenVisible = true;
    _idleTimer?.cancel();
    if (_driverId == null) return;

    if (state.messages.isEmpty) {
      await _loadInitial();
    }

    await _ensureConnected();

    // No read-receipt call here: the conversation /read endpoint is
    // dispatch-scoped and 403s for CONDUCTOR. Unread bookkeeping is the
    // dispatcher's concern; the driver app has no unread counter.
  }

  /// Call from the chat screen's `dispose`.
  void leaveScreen() {
    _screenVisible = false;
    _scheduleIdleDisconnect();
  }

  /// App went to background (or returned). Drive from the host widget's
  /// WidgetsBindingObserver.didChangeAppLifecycleState.
  void onAppBackgrounded() {
    if (!_screenVisible) return;
    _scheduleIdleDisconnect();
  }

  void onAppForegrounded() {
    if (!_screenVisible) return;
    _idleTimer?.cancel();
    _ensureConnected();
  }

  void _scheduleIdleDisconnect() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_kIdleDisconnectWindow, _disconnect);
  }

  // ── Actions ───────────────────────────────────────────────────────

  Future<void> sendText(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || _driverId == null) return;
    await _doSend(body: trimmed);
  }

  Future<void> sendQuickReply(ChatQuickReply reply) async {
    if (_driverId == null) return;
    await _doSend(body: reply.label, templateCode: reply.code);
  }

  Future<void> loadOlder() async {
    if (_driverId == null) return;
    if (state.isLoadingOlder || !state.hasMoreOlder) return;
    if (state.messages.isEmpty) return;

    final oldestId = state.messages.first.id;
    state = state.copyWith(isLoadingOlder: true);
    try {
      final older = await _service.getMessagesBefore(
        _driverId,
        oldestId,
        limit: _kScrollBackLimit,
      );
      state = state.copyWith(
        messages: [...older, ...state.messages],
        hasMoreOlder: older.length >= _kScrollBackLimit,
        isLoadingOlder: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingOlder: false);
      debugPrint('[chat] loadOlder failed: $e');
    }
  }

  // ── Internals ─────────────────────────────────────────────────────

  Future<void> _loadInitial() async {
    if (_driverId == null) return;
    state = state.copyWith(isLoading: true, clearLoadError: true);
    try {
      final initial =
          await _service.getInitialMessages(_driverId, limit: _kInitialLimit);
      _latestMessageId = initial.isEmpty ? null : initial.last.id;
      state = state.copyWith(
        messages: initial,
        isLoading: false,
        hasMoreOlder: initial.length >= _kInitialLimit,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        loadError: 'No se pudo cargar el historial',
      );
      debugPrint('[chat] loadInitial failed: $e');
    }
  }

  Future<void> _doSend({required String body, String? templateCode}) async {
    if (_driverId == null) return;
    state = state.copyWith(isSending: true, clearSendError: true);
    try {
      // Don't insert optimistically — the server publishes the message
      // back over the WS subscription, and the dedupe in _onPublication
      // would handle the race but the boundary is fragile. The send
      // round-trip is fast enough to feel immediate.
      await _service.sendMessage(
        _driverId,
        body: body,
        templateCode: templateCode,
      );
      state = state.copyWith(isSending: false);
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        sendError: 'No se pudo enviar',
      );
      debugPrint('[chat] send failed: $e');
    }
  }

  Future<void> _ensureConnected() async {
    if (_client != null) return;
    if (_companyId == null) return;

    final url = _resolveWsUrl();
    final client = cf.createClient(
      url,
      cf.ClientConfig(
        getToken: (cf.ConnectionTokenEvent event) async {
          try {
            return await _service.getRealtimeToken();
          } catch (e) {
            // Throwing this stops reconnects permanently — only do it
            // for genuine auth failure (401). Other errors are logged
            // and let the SDK retry with backoff.
            debugPrint('[chat] token fetch failed: $e');
            throw cf.UnauthorizedException();
          }
        },
        minReconnectDelay: const Duration(milliseconds: 300),
        maxReconnectDelay: const Duration(seconds: 30),
        name: 'aea-driver',
      ),
    );

    _connectedSub = client.connected.listen((_) {
      state = state.copyWith(isConnected: true);
    });
    _disconnectedSub = client.disconnected.listen((event) {
      state = state.copyWith(isConnected: false);
      debugPrint('[chat] disconnected code=${event.code} reason=${event.reason}');
    });

    // Server-side subs auto-attach via the connection JWT's `channels`
    // claim — driver gets `chat:{co}:driver:{ownId}` and
    // `chat:{co}:broadcast`. Both publications land on `client.publication`.
    _publicationSub = client.publication.listen(_onPublication);

    _subscribedSub = client.subscribed.listen((event) {
      // First fire is the initial subscribe — initial fetch covers it.
      // Later fires are reconnects, where we may have missed messages.
      if (!_hadFirstSubscribe) {
        _hadFirstSubscribe = true;
        return;
      }
      unawaited(_reconcileGap());
    });

    _client = client;
    await client.connect();
  }

  void _onPublication(cf.ServerPublicationEvent event) {
    if (_driverId == null) return;
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final kind = data['kind'] as String?;
    if (kind == 'chat.message') {
      final raw = data['message'] as Map<String, dynamic>?;
      if (raw == null) return;
      final msg = ChatMessage.fromJson(raw);
      if (msg.driverId != _driverId) return;
      _appendIfNew(msg);
    } else if (kind == 'chat.broadcast') {
      // The broadcast row is fanned out per-driver on the server, so it
      // will also arrive on our per-driver channel as a chat.message
      // with kind=BROADCAST. Pulling it here would risk a duplicate —
      // skip and let the per-driver publication carry it.
    }
  }

  void _appendIfNew(ChatMessage msg) {
    if (state.messages.any((m) => m.id == msg.id)) return;
    _latestMessageId = msg.id;
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  Future<void> _reconcileGap() async {
    if (_driverId == null) return;
    final cursor = _latestMessageId;
    if (cursor == null) {
      // Cold reconnect with no local messages — nothing to gap-fetch.
      return;
    }
    try {
      final gap = await _service.getMessagesAfter(_driverId, cursor);
      if (gap.isEmpty) return;
      final existing = state.messages.map((m) => m.id).toSet();
      final fresh = gap.where((m) => !existing.contains(m.id)).toList();
      if (fresh.isEmpty) return;
      _latestMessageId = fresh.last.id;
      state = state.copyWith(messages: [...state.messages, ...fresh]);
    } catch (e) {
      debugPrint('[chat] gap fetch failed: $e');
    }
  }

  void _disconnect() {
    _idleTimer = null;
    _publicationSub?.cancel();
    _subscribedSub?.cancel();
    _connectedSub?.cancel();
    _disconnectedSub?.cancel();
    _publicationSub = null;
    _subscribedSub = null;
    _connectedSub = null;
    _disconnectedSub = null;

    final client = _client;
    _client = null;
    _hadFirstSubscribe = false;
    if (client != null) {
      try {
        client.disconnect();
      } catch (_) {}
    }
    if (mounted) {
      state = state.copyWith(isConnected: false);
    }
  }

  /// Resolve the Centrifugo WS URL from build config (see
  /// [ApiConfig.wsUrl]). Defaults to the dev loopback; production passes
  /// a `wss://` URL via `--dart-define=WS_URL=...`.
  String _resolveWsUrl() => ApiConfig.wsUrl;

  @override
  void dispose() {
    _idleTimer?.cancel();
    _disconnect();
    super.dispose();
  }
}

/// Provider. Tied to the auth state — recreated when the user changes
/// so a logout fully tears down the WS and clears any cached messages.
final chatProvider =
    StateNotifierProvider.autoDispose<ChatNotifier, ChatState>((ref) {
  final user = ref.watch(authProvider).user;
  // Keep the notifier alive across screen pops while authed; only
  // dispose on logout.
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return ChatNotifier(
    service: ChatService(),
    driverId: user?.id,
    companyId: user?.companyId,
  );
});
