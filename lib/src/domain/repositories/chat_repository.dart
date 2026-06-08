import '../models/chat.dart';
import '../models/chat_message.dart';

abstract interface class ChatRepository {
  Stream<Chat?> watchChat(String chatId);

  /// Watches all chats where [uid] is a participant, ordered by lastMessageAt.
  Stream<List<Chat>> watchForUser(String uid);

  Stream<List<ChatMessage>> watchMessages({
    required String chatId,
    int limit = 50,
  });

  Future<ChatMessage> sendMessage(ChatMessage message);

  /// Soft-deletes a message (sets `deleted: true`); only the sender may do so.
  Future<void> softDeleteMessage({
    required String chatId,
    required String messageId,
  });

  /// Edits a message's text (sets `edited: true`); sender-only, time-limited
  /// server-side.
  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newText,
  });

  /// Sets (or, when [emoji] is null, removes) the caller's emoji reaction on a
  /// message. One reaction per user, keyed by uid.
  Future<void> setReaction({
    required String chatId,
    required String messageId,
    required String uid,
    String? emoji,
  });

  /// Marks all messages in [chatId] not sent by [uid] as read by [uid].
  Future<void> markMessagesRead({required String chatId, required String uid});

  /// Writes (or refreshes) the caller's typing presence in [chatId].
  /// Should be called at most every 2 seconds while the user is typing.
  Future<void> setTyping({required String chatId, required String uid});

  /// Streams the [updatedAt] timestamp of the other participant's typing doc.
  /// Returns null when the other participant is not typing.
  Stream<DateTime?> watchOtherTyping({
    required String chatId,
    required String myUid,
  });
}
