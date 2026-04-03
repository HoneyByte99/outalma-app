import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_providers.dart';
import '../../data/repositories/firestore_chat_repository.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return FirestoreChatRepository(ref.watch(firestoreProvider));
});

/// Watches a single chat document by id.
final chatDetailProvider = StreamProvider.family<Chat?, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).watchChat(chatId);
});

/// Watches the latest 50 messages for a chat.
final chatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, chatId) {
  return ref
      .watch(chatRepositoryProvider)
      .watchMessages(chatId: chatId, limit: 50);
});
