import 'package:cloud_firestore/cloud_firestore.dart';
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
final chatDetailProvider = StreamProvider.autoDispose.family<Chat?, String>((
  ref,
  chatId,
) {
  return ref.watch(chatRepositoryProvider).watchChat(chatId);
});

/// Default number of messages loaded, and the increment per "load older" tap.
const chatMessagePageSize = 50;

/// How many messages to load for a chat. Bumped by [chatMessagePageSize] each
/// time the user requests older messages. Auto-disposes with the chat view, so
/// the window resets to one page next time the conversation is opened.
final chatMessageLimitProvider = StateProvider.autoDispose.family<int, String>(
  (ref, chatId) => chatMessagePageSize,
);

/// Watches the most recent messages for a chat, up to the current limit.
final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, chatId) {
      final limit = ref.watch(chatMessageLimitProvider(chatId));
      return ref
          .watch(chatRepositoryProvider)
          .watchMessages(chatId: chatId, limit: limit);
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

  final blocked = ref.watch(blockedUserIdsProvider).valueOrNull ?? const {};

  return chatsAsync.whenData((chats) {
    return chats.where((c) {
      // Hide chats with a blocked participant.
      final otherUid = c.customerId == uid ? c.providerId : c.customerId;
      if (otherUid.isNotEmpty && blocked.contains(otherUid)) return false;
      // Legacy document: neither field is set → show in both modes
      if (c.customerId.isEmpty && c.providerId.isEmpty) return true;
      return mode == ActiveMode.client
          ? c.customerId == uid
          : c.providerId == uid;
    }).toList();
  });
});

/// Streams the other participant's typing timestamp for [chatId].
/// Returns null when the other user is not typing (or TTL has expired).
final otherTypingProvider = StreamProvider.autoDispose
    .family<DateTime?, String>((ref, chatId) {
      final auth = ref.watch(authNotifierProvider).valueOrNull;
      if (auth is! AuthAuthenticated) return const Stream.empty();
      return ref
          .watch(chatRepositoryProvider)
          .watchOtherTyping(chatId: chatId, myUid: auth.user.id);
    });

/// Set of user ids the current user has blocked (live).
final blockedUserIdsProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final uid = ref.watch(_stableChatUidProvider);
  if (uid == null) return Stream.value(<String>{});
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .collection('blockedUsers')
      .snapshots()
      .map((qs) => qs.docs.map((d) => d.id).toSet());
});

/// Blocks/unblocks another user (writes under the caller's own subcollection).
class UserBlockService {
  UserBlockService(this._db, this._uid);
  final FirebaseFirestore _db;
  final String? _uid;

  CollectionReference<Map<String, dynamic>>? _col() {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('blockedUsers');
  }

  Future<void> block(String otherUid) async =>
      _col()?.doc(otherUid).set({'createdAt': FieldValue.serverTimestamp()});

  Future<void> unblock(String otherUid) async => _col()?.doc(otherUid).delete();
}

final userBlockServiceProvider = Provider<UserBlockService>((ref) {
  return UserBlockService(
    ref.watch(firestoreProvider),
    ref.watch(_stableChatUidProvider),
  );
});

/// Unread messages count across all chats (messages not sent by me and not in readBy).
final totalUnreadMessagesCountProvider = Provider<int>((ref) {
  // We use the chat list to know which chats exist; detailed unread count
  // per chat requires per-chat message subscriptions which is expensive.
  // For now: count of chats that have lastMessageAt set (proxy for activity).
  // A proper per-chat unread count would require watching each chat's messages.
  return 0; // placeholder — badge driven by notifications instead
});
