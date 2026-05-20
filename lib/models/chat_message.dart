/// Chat message model — mirrors the backend `chat_messages` row shape
/// returned by `/api/chat/conversations/:driverId/messages`.
///
/// The driver app only ever talks to its own thread, so this model is
/// thread-agnostic (no inbox concept here, unlike the dispatcher).
class ChatMessage {
  final String id;
  final String companyId;
  final String driverId;
  final String senderId;
  final ChatDirection direction;
  final ChatMessageKind kind;
  final String body;
  final String? templateCode;
  final DateTime? readAt;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.companyId,
    required this.driverId,
    required this.senderId,
    required this.direction,
    required this.kind,
    required this.body,
    required this.createdAt,
    this.templateCode,
    this.readAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      companyId: json['companyId'] as String,
      driverId: json['driverId'] as String,
      senderId: json['senderId'] as String,
      direction: ChatDirection.fromWire(json['direction'] as String),
      kind: ChatMessageKind.fromWire(json['kind'] as String),
      body: json['body'] as String,
      templateCode: json['templateCode'] as String?,
      readAt: _parseDate(json['readAt']),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  /// Whether the message came FROM the dispatcher TO this driver — i.e.
  /// the driver should render it as an inbound bubble on the left.
  bool get isInbound => direction == ChatDirection.toDriver;
  bool get isBroadcast => kind == ChatMessageKind.broadcast;
  bool get isTemplate => kind == ChatMessageKind.template;

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }
}

enum ChatDirection {
  /// Dispatcher → driver. Renders as inbound in the driver app.
  toDriver,

  /// Driver → dispatcher. Renders as outbound (own message).
  toDispatch;

  static ChatDirection fromWire(String wire) {
    switch (wire) {
      case 'TO_DRIVER':
        return ChatDirection.toDriver;
      case 'TO_DISPATCH':
        return ChatDirection.toDispatch;
      default:
        // Unknown direction = treat as inbound; safer than dropping.
        return ChatDirection.toDriver;
    }
  }
}

enum ChatMessageKind {
  text,
  template,
  broadcast;

  static ChatMessageKind fromWire(String wire) {
    switch (wire) {
      case 'TEMPLATE':
        return ChatMessageKind.template;
      case 'BROADCAST':
        return ChatMessageKind.broadcast;
      default:
        return ChatMessageKind.text;
    }
  }
}

/// Hard-coded driver quick-replies. Mirror of CHAT_QUICK_REPLIES in
/// `src/lib/chat/quick-replies.ts` — keep these in sync if either side
/// adds a new template code, the server validates against the backend
/// list and a stale client just gets a 400.
class ChatQuickReply {
  final String code;
  final String label;

  const ChatQuickReply({required this.code, required this.label});
}

const List<ChatQuickReply> chatQuickReplies = [
  ChatQuickReply(code: 'ON_THE_WAY', label: 'Voy en camino'),
  ChatQuickReply(code: 'ARRIVED', label: 'Llegué al punto'),
  ChatQuickReply(code: 'CUSTOMER_ABSENT', label: 'Cliente ausente'),
  ChatQuickReply(code: 'DELAYED', label: 'Me demoro unos minutos'),
  ChatQuickReply(code: 'NEED_HELP', label: 'Necesito ayuda'),
];
