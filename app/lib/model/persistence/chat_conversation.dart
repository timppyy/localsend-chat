class ChatConversation {
  final String peerFingerprint;
  final String alias;
  final String? lastIp;
  final int? lastPort;
  final bool? https;
  final String? lastMessage;
  final DateTime updatedAt;

  const ChatConversation({
    required this.peerFingerprint,
    required this.alias,
    required this.lastIp,
    required this.lastPort,
    required this.https,
    required this.lastMessage,
    required this.updatedAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      peerFingerprint: json['peerFingerprint'] as String,
      alias: json['alias'] as String,
      lastIp: json['lastIp'] as String?,
      lastPort: json['lastPort'] as int?,
      https: json['https'] as bool?,
      lastMessage: json['lastMessage'] as String?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'peerFingerprint': peerFingerprint,
      'alias': alias,
      'lastIp': lastIp,
      'lastPort': lastPort,
      'https': https,
      'lastMessage': lastMessage,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  ChatConversation copyWith({
    String? alias,
    String? lastIp,
    int? lastPort,
    bool? https,
    String? lastMessage,
    DateTime? updatedAt,
  }) {
    return ChatConversation(
      peerFingerprint: peerFingerprint,
      alias: alias ?? this.alias,
      lastIp: lastIp ?? this.lastIp,
      lastPort: lastPort ?? this.lastPort,
      https: https ?? this.https,
      lastMessage: lastMessage ?? this.lastMessage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatConversation &&
        other.peerFingerprint == peerFingerprint &&
        other.alias == alias &&
        other.lastIp == lastIp &&
        other.lastPort == lastPort &&
        other.https == https &&
        other.lastMessage == lastMessage &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(peerFingerprint, alias, lastIp, lastPort, https, lastMessage, updatedAt);
}
