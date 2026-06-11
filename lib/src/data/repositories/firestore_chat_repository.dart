import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/chat.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../firestore/firestore_collections.dart';

class FirestoreChatRepository implements ChatRepository {
  const FirestoreChatRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<Chat?> watchChat(String chatId) {
    return FirestoreCollections.chats(
      _db,
    ).doc(chatId).snapshots().map((snap) => snap.exists ? snap.data() : null);
  }

  @override
  Stream<List<Chat>> watchForUser(String uid) {
    return FirestoreCollections.chats(
      _db,
    ).where('participantIds', arrayContains: uid).snapshots().map((qs) {
      final list = qs.docs.map((d) => d.data()).toList();
      list.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  @override
  Stream<List<ChatMessage>> watchMessages({
    required String chatId,
    int limit = 50,
  }) {
    return FirestoreCollections.chatMessages(db: _db, chatId: chatId)
        .orderBy('createdAt', descending: false)
        .limitToLast(limit)
        // includeMetadataChanges: a sent message first emits with
        // hasPendingWrites=true (local write → clock icon). Without this flag,
        // Firestore never re-emits when the server ack arrives, so the clock
        // would stay forever even though the message is sent. With it, we get a
        // second emission with hasPendingWrites=false and the clock clears.
        .snapshots(includeMetadataChanges: true)
        .map(
          (qs) => qs.docs
              .map(
                (d) =>
                    d.data().copyWith(isPending: d.metadata.hasPendingWrites),
              )
              .toList(),
        );
  }

  @override
  Future<ChatMessage> sendMessage(ChatMessage message) async {
    final col = FirestoreCollections.chatMessages(
      db: _db,
      chatId: message.chatId,
    );
    final ref = col.doc();
    await ref.set(message);
    final snap = await ref.get();
    return snap.data()!;
  }

  @override
  Future<void> softDeleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    await FirestoreCollections.chatMessages(
      db: _db,
      chatId: chatId,
    ).doc(messageId).update({'deleted': true});
  }

  @override
  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newText,
  }) async {
    await FirestoreCollections.chatMessages(
      db: _db,
      chatId: chatId,
    ).doc(messageId).update({'text': newText, 'edited': true});
  }

  @override
  Future<void> setReaction({
    required String chatId,
    required String messageId,
    required String uid,
    String? emoji,
  }) async {
    final ref = FirestoreCollections.chatMessages(
      db: _db,
      chatId: chatId,
    ).doc(messageId);
    // Toggle off when emoji is null; otherwise set this user's reaction.
    await ref.update({'reactions.$uid': emoji ?? FieldValue.delete()});
  }

  @override
  Future<void> markMessagesRead({
    required String chatId,
    required String uid,
  }) async {
    // Bound the read: only the most recent window of messages can plausibly be
    // unread. The old `col.get()` fetched the ENTIRE message history on every
    // read-trigger (and the chat page fires this on each stream emission), so a
    // long thread re-downloaded all docs repeatedly. Ordering by createdAt desc
    // + a cap keeps it cheap; older unread messages (rare) are caught on a later
    // pass. (Bug C2.)
    const window = 100;
    final snap = await FirestoreCollections.chatMessages(
      db: _db,
      chatId: chatId,
    ).orderBy('createdAt', descending: true).limit(window).get();
    final batch = _db.batch();
    var count = 0;
    for (final doc in snap.docs) {
      final msg = doc.data();
      if (msg.senderId != uid && !msg.readBy.contains(uid)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([uid]),
        });
        count++;
      }
    }
    if (count > 0) await batch.commit();
  }

  @override
  Future<void> setTyping({required String chatId, required String uid}) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .doc(uid)
        .set({'updatedAt': FieldValue.serverTimestamp()});
  }

  @override
  Stream<DateTime?> watchOtherTyping({
    required String chatId,
    required String myUid,
  }) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .snapshots()
        .map((qs) {
          final other = qs.docs.where((d) => d.id != myUid).firstOrNull;
          if (other == null) return null;
          final ts = other.data()['updatedAt'];
          if (ts is Timestamp) return ts.toDate().toUtc();
          return null;
        });
  }
}
