enum ChatMessageDirection {
  incoming,
  outgoing,
}

enum ChatMessageKind {
  text,
  file,
}

enum ChatMessageStatus {
  sending,
  sent,
  received,
  failed,
  declined,
}

const _unchanged = Object();

class ChatMessage {
  final String id;
  final String peerFingerprint;
  final ChatMessageDirection direction;
  final ChatMessageKind kind;
  final ChatMessageStatus status;
  final String? text;
  final String? fileName;
  final int? fileSize;
  final String? filePath;
  final String? errorMessage;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.peerFingerprint,
    required this.direction,
    required this.kind,
    required this.status,
    required this.text,
    required this.fileName,
    required this.fileSize,
    required this.filePath,
    required this.errorMessage,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      peerFingerprint: json['peerFingerprint'] as String,
      direction: ChatMessageDirection.values.firstWhere((value) => value.name == json['direction']),
      kind: ChatMessageKind.values.firstWhere((value) => value.name == json['kind']),
      status: ChatMessageStatus.values.firstWhere((value) => value.name == json['status']),
      text: json['text'] as String?,
      fileName: json['fileName'] as String?,
      fileSize: json['fileSize'] as int?,
      filePath: json['filePath'] as String?,
      errorMessage: json['errorMessage'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'peerFingerprint': peerFingerprint,
      'direction': direction.name,
      'kind': kind.name,
      'status': status.name,
      'text': text,
      'fileName': fileName,
      'fileSize': fileSize,
      'filePath': filePath,
      'errorMessage': errorMessage,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  ChatMessage copyWith({
    ChatMessageStatus? status,
    Object? errorMessage = _unchanged,
  }) {
    return ChatMessage(
      id: id,
      peerFingerprint: peerFingerprint,
      direction: direction,
      kind: kind,
      status: status ?? this.status,
      text: text,
      fileName: fileName,
      fileSize: fileSize,
      filePath: filePath,
      errorMessage: identical(errorMessage, _unchanged) ? this.errorMessage : errorMessage as String?,
      timestamp: timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatMessage &&
        other.id == id &&
        other.peerFingerprint == peerFingerprint &&
        other.direction == direction &&
        other.kind == kind &&
        other.status == status &&
        other.text == text &&
        other.fileName == fileName &&
        other.fileSize == fileSize &&
        other.filePath == filePath &&
        other.errorMessage == errorMessage &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(id, peerFingerprint, direction, kind, status, text, fileName, fileSize, filePath, errorMessage, timestamp);
}
