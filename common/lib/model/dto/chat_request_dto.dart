import 'dart:convert';

import 'package:common/model/dto/chat_peer_dto.dart';

class ChatRequestDto {
  final ChatPeerDto sender;
  final String messageId;
  final String text;
  final DateTime timestamp;

  const ChatRequestDto({
    required this.sender,
    required this.messageId,
    required this.text,
    required this.timestamp,
  });

  factory ChatRequestDto.fromJson(String json) {
    return ChatRequestDto.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  factory ChatRequestDto.fromMap(Map<String, dynamic> map) {
    return ChatRequestDto(
      sender: ChatPeerDto.fromMap(map['sender'] as Map<String, dynamic>),
      messageId: map['messageId'] as String,
      text: map['text'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender': sender.toJson(),
      'messageId': messageId,
      'text': text,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }
}
