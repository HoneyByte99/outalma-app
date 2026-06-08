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
    this.edited = false,
    this.replyToId,
    this.replyToText,
    this.replyToSenderId,
    this.reactions = const {},
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

  /// Edited by its sender — rendered with an "(edited)" marker.
  final bool edited;

  /// Reply/quote: id + snapshot of the message this one replies to.
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderId;

  /// Emoji reactions keyed by reactor uid → emoji (one reaction per user).
  final Map<String, String> reactions;

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
    bool? edited,
    String? replyToId,
    String? replyToText,
    String? replyToSenderId,
    Map<String, String>? reactions,
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
      edited: edited ?? this.edited,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
      reactions: reactions ?? this.reactions,
    );
  }
}
