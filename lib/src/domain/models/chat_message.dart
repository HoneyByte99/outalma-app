import '../enums/message_type.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    required this.createdAt,
    this.text,
    this.mediaUrl,
    this.readBy = const [],
    this.deleted = false,
    this.replyToId,
    this.replyToText,
    this.replyToSenderId,
  });

  final String id;
  final String chatId;
  final String senderId;
  final MessageType type;
  final DateTime createdAt;
  final String? text;
  final String? mediaUrl;

  /// UIDs of participants who have read this message.
  final List<String> readBy;

  /// Soft-deleted by its sender — rendered as "message deleted".
  final bool deleted;

  /// Reply/quote: id + snapshot of the message this one replies to.
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderId;

  bool get isReply => replyToId != null && replyToId!.isNotEmpty;

  ChatMessage copyWith({
    String? chatId,
    String? senderId,
    MessageType? type,
    DateTime? createdAt,
    String? text,
    String? mediaUrl,
    List<String>? readBy,
    bool? deleted,
    String? replyToId,
    String? replyToText,
    String? replyToSenderId,
  }) {
    return ChatMessage(
      id: id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      text: text ?? this.text,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      readBy: readBy ?? this.readBy,
      deleted: deleted ?? this.deleted,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
    );
  }
}
