import '../enums/message_type.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    required this.sentAt,
    this.text,
    this.mediaUrl,
  });

  final String id;
  final String chatId;
  final String senderId;
  final MessageType type;
  final DateTime sentAt;
  final String? text;
  final String? mediaUrl;

  Map<String, Object?> toJson() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'type': type.name,
      'sentAt': sentAt.toUtc().toIso8601String(),
      'text': text,
      'mediaUrl': mediaUrl,
    };
  }

  static ChatMessage fromJson(String id, Map<String, Object?> json) {
    final sentAtRaw = json['sentAt'];
    return ChatMessage(
      id: id,
      chatId: (json['chatId'] as String?) ?? '',
      senderId: (json['senderId'] as String?) ?? '',
      type: MessageType.fromString(
        (json['type'] as String?) ?? MessageType.text.name,
      ),
      sentAt: sentAtRaw is String
          ? DateTime.parse(sentAtRaw).toUtc()
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      text: json['text'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
    );
  }
}
