import '../models/chat_message.dart';

abstract interface class ChatRepository {
  Stream<List<ChatMessage>> watchMessages({
    required String chatId,
    int limit = 50,
  });

  Future<ChatMessage> sendMessage(ChatMessage message);
}
