import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/user/user_providers.dart';
import '../../data/repositories/firestore_chat_repository.dart';
import '../../domain/enums/active_mode.dart';
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

/// Stable UID — avoids transient null during auth re-evaluation.
final _stableChatUidProvider = Provider<String?>((ref) {
  final auth = ref.watch(authNotifierProvider).valueOrNull;
  if (auth is AuthAuthenticated) return auth.user.id;
  return null;
});

/// Watches all chats for the currently authenticated user, sorted by activity.
final userChatsProvider = StreamProvider<List<Chat>>((ref) {
  final uid = ref.watch(_stableChatUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(chatRepositoryProvider).watchForUser(uid);
});

/// Watches chats filtered to the user's active mode.
final chatsForModeProvider = Provider<AsyncValue<List<Chat>>>((ref) {
  final chatsAsync = ref.watch(userChatsProvider);
  final uid = ref.watch(_stableChatUidProvider);
  final mode = ref.watch(activeModeProvider);

  if (uid == null) return const AsyncValue.data([]);

  return chatsAsync.whenData((chats) {
    return chats.where((c) {
      // Legacy document: neither field is set → show in both modes
      if (c.customerId.isEmpty && c.providerId.isEmpty) return true;
      return mode == ActiveMode.client
          ? c.customerId == uid
          : c.providerId == uid;
    }).toList();
  });
});

/// Unread messages count across all chats (messages not sent by me and not in readBy).
final totalUnreadMessagesCountProvider = Provider<int>((ref) {
  // We use the chat list to know which chats exist; detailed unread count
  // per chat requires per-chat message subscriptions which is expensive.
  // For now: count of chats that have lastMessageAt set (proxy for activity).
  // A proper per-chat unread count would require watching each chat's messages.
  return 0; // placeholder — badge driven by notifications instead
});
