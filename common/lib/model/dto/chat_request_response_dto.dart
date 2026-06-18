import 'dart:convert';

class ChatRequestResponseDto {
  final String chatToken;

  const ChatRequestResponseDto({
    required this.chatToken,
  });

  factory ChatRequestResponseDto.fromJson(String json) {
    return ChatRequestResponseDto.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  factory ChatRequestResponseDto.fromMap(Map<String, dynamic> map) {
    return ChatRequestResponseDto(
      chatToken: map['chatToken'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chatToken': chatToken,
    };
  }
}
