import '../core/constants.dart';
import '../models/chat_message.dart';
import 'api_service.dart';

/// Chat HTTP client for the driver app.
///
/// Always scoped to the logged-in driver's own thread — the driverId is
/// passed in by the caller (who reads it from the auth state). The
/// backend enforces tenant + self-only scope; we trust that and don't
/// re-check here.
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final ApiService _api = ApiService();

  /// Initial page (no cursor) — the newest `limit` messages, oldest-first
  /// for top-to-bottom render. Defaults match the backend's default.
  Future<List<ChatMessage>> getInitialMessages(
    String driverId, {
    int limit = 50,
  }) async {
    final res = await _api.get<Map<String, dynamic>>(
      ApiConfig.chatMessages(driverId),
      queryParameters: {'limit': limit},
    );
    return _parseMessages(res.data);
  }

  /// Reconnect reconciliation — every message strictly newer than [afterId].
  /// Used after the WS reconnects and we may have missed events.
  Future<List<ChatMessage>> getMessagesAfter(
    String driverId,
    String afterId,
  ) async {
    final res = await _api.get<Map<String, dynamic>>(
      ApiConfig.chatMessages(driverId),
      queryParameters: {'after': afterId},
    );
    return _parseMessages(res.data);
  }

  /// Scroll-back — older messages, oldest-first, ready to prepend.
  Future<List<ChatMessage>> getMessagesBefore(
    String driverId,
    String beforeId, {
    int limit = 50,
  }) async {
    final res = await _api.get<Map<String, dynamic>>(
      ApiConfig.chatMessages(driverId),
      queryParameters: {'before': beforeId, 'limit': limit},
    );
    return _parseMessages(res.data);
  }

  /// Send a free-text or template-coded message. The backend derives
  /// direction (TO_DISPATCH) from the caller's role — we never send it.
  Future<ChatMessage> sendMessage(
    String driverId, {
    required String body,
    String? templateCode,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiConfig.chatMessages(driverId),
      data: {
        'body': body,
        if (templateCode != null) 'templateCode': templateCode,
      },
    );
    final data = res.data?['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ApiException('Respuesta inesperada del servidor');
    }
    return ChatMessage.fromJson(data);
  }

  /// Marca leídos los mensajes despacho→driver del hilo propio. Es la
  /// base del "Leído" que ve el despachador en sus mensajes. Best-effort:
  /// el caller decide si ignora errores (no debe bloquear el chat).
  Future<void> markThreadRead(String driverId) async {
    await _api.post<Map<String, dynamic>>(ApiConfig.chatRead(driverId));
  }

  /// Fetch a short-lived Centrifugo connection token. The SDK calls this
  /// via its `getToken` callback on connect and again before expiry.
  Future<String> getRealtimeToken() async {
    final res = await _api.get<Map<String, dynamic>>(
      ApiConfig.realtimeToken,
    );
    final token = res.data?['token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException('Token de tiempo real vacío');
    }
    return token;
  }

  List<ChatMessage> _parseMessages(Map<String, dynamic>? data) {
    final raw = (data?['data'] as List?) ?? const [];
    return raw
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
