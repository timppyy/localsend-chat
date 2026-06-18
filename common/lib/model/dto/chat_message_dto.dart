import 'dart:convert';

import 'package:common/model/dto/chat_peer_dto.dart';

class ChatMessageDto {
  final ChatPeerDto sender;
  final String chatToken;
  final String messageId;
  final String text;
  final DateTime timestamp;

  const ChatMessageDto({
    required this.sender,
    required this.chatToken,
    required this.messageId,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessageDto.fromJson(String json) {
    return ChatMessageDto.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  factory ChatMessageDto.fromMap(Map<String, dynamic> map) {
    return ChatMessageDto(
      sender: ChatPeerDto.fromMap(map['sender'] as Map<String, dynamic>),
      chatToken: map['chatToken'] as String,
      messageId: map['messageId'] as String,
      text: map['text'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender': sender.toJson(),
      'chatToken': chatToken,
      'messageId': messageId,
      'text': text,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }
}
