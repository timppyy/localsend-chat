class ChatTrustedDevice {
  final String fingerprint;
  final String alias;
  final String token;
  final String? lastIp;
  final int? lastPort;
  final bool? https;
  final DateTime trustedAt;
  final DateTime updatedAt;

  const ChatTrustedDevice({
    required this.fingerprint,
    required this.alias,
    required this.token,
    required this.lastIp,
    required this.lastPort,
    required this.https,
    required this.trustedAt,
    required this.updatedAt,
  });

  factory ChatTrustedDevice.fromJson(Map<String, dynamic> json) {
    return ChatTrustedDevice(
      fingerprint: json['fingerprint'] as String,
      alias: json['alias'] as String,
      token: json['token'] as String,
      lastIp: json['lastIp'] as String?,
      lastPort: json['lastPort'] as int?,
      https: json['https'] as bool?,
      trustedAt: DateTime.parse(json['trustedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fingerprint': fingerprint,
      'alias': alias,
      'token': token,
      'lastIp': lastIp,
      'lastPort': lastPort,
      'https': https,
      'trustedAt': trustedAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  ChatTrustedDevice copyWith({
    String? alias,
    String? token,
    String? lastIp,
    int? lastPort,
    bool? https,
    DateTime? updatedAt,
  }) {
    return ChatTrustedDevice(
      fingerprint: fingerprint,
      alias: alias ?? this.alias,
      token: token ?? this.token,
      lastIp: lastIp ?? this.lastIp,
      lastPort: lastPort ?? this.lastPort,
      https: https ?? this.https,
      trustedAt: trustedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatTrustedDevice &&
        other.fingerprint == fingerprint &&
        other.alias == alias &&
        other.token == token &&
        other.lastIp == lastIp &&
        other.lastPort == lastPort &&
        other.https == https &&
        other.trustedAt == trustedAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(fingerprint, alias, token, lastIp, lastPort, https, trustedAt, updatedAt);
}
