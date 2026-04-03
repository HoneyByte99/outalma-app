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
    return FirestoreCollections.chats(_db)
        .doc(chatId)
        .snapshots()
        .map((snap) => snap.exists ? snap.data() : null);
  }

  @override
  Stream<List<Chat>> watchForUser(String uid) {
    return FirestoreCollections.chats(_db)
        .where('participantIds', arrayContains: uid)
        .snapshots()
        .map((qs) {
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
        .snapshots()
        .map((qs) => qs.docs.map((d) => d.data()).toList());
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
  Future<void> markMessagesRead({
    required String chatId,
    required String uid,
  }) async {
    final col = FirestoreCollections.chatMessages(db: _db, chatId: chatId);
    final snap = await col.get();
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
}
