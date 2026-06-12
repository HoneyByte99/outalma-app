import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Handles uploading images and voice messages for chat.
///
/// Storage paths:
/// - Images: /private/chats/{chatId}/media/{timestamp}_image.jpg
/// - Voice:  /private/chats/{chatId}/media/{timestamp}_voice.m4a
class ChatMediaService {
  ChatMediaService({required FirebaseStorage storage, ImagePicker? picker})
    : _storage = storage,
      _picker = picker ?? ImagePicker();

  final FirebaseStorage _storage;
  final ImagePicker _picker;

  /// Picks an image with a consistent size budget on every platform: bounded to
  /// 1024×1024 at 80% quality. Bounding BOTH dimensions (not just width) keeps a
  /// tall portrait photo from being uploaded huge and rendering awkwardly in the
  /// chat bubble.
  Future<XFile?> _pickImage(ImageSource source) {
    return _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
  }

  /// Pick an image from gallery and upload. Returns download URL or null.
  Future<String?> pickImageFromGallery(String chatId) async {
    final file = await _pickImage(ImageSource.gallery);
    if (file == null) return null;
    return _uploadFile(chatId, file, 'image');
  }

  /// Take a photo with camera and upload. Returns download URL or null.
  Future<String?> takePhoto(String chatId) async {
    final file = await _pickImage(ImageSource.camera);
    if (file == null) return null;
    return _uploadFile(chatId, file, 'image');
  }

  /// Upload voice recording bytes. Web-compatible (no dart:io dependency).
  Future<String> uploadVoiceBytes(String chatId, Uint8List bytes) async {
    return _uploadVoiceBytes(chatId, bytes);
  }

  /// Upload a booking voice message before the booking is created
  /// (no bookingId available yet).
  ///
  /// Scoped under the uploader's uid so Storage rules can restrict writes to
  /// the owner. The provider later plays it via the tokenised download URL
  /// stored on the booking document.
  ///
  /// Storage path: private/bookings/voice/{uid}/{timestamp}_voice.m4a
  Future<String> uploadBookingVoice(Uint8List bytes) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Booking voice upload requires an authenticated user');
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('private/bookings/voice/$uid/${ts}_voice.m4a');
    await ref.putData(bytes, SettableMetadata(contentType: 'audio/mp4'));
    return ref.getDownloadURL();
  }

  /// Current uid — chat media is stored under it so Storage rules authorize
  /// writes via isSelf(uid) (no fragile cross-service Firestore lookup).
  String _requireUid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Chat media upload requires an authenticated user');
    }
    return uid;
  }

  Future<String> _uploadVoiceBytes(String chatId, Uint8List bytes) async {
    final uid = _requireUid();
    final ts = DateTime.now().millisecondsSinceEpoch;
    const ext = kIsWeb ? 'webm' : 'm4a';
    const contentType = kIsWeb ? 'audio/webm' : 'audio/mp4';
    final ref = _storage.ref(
      'private/chats/$chatId/media/$uid/${ts}_voice.$ext',
    );
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  Future<String> _uploadFile(String chatId, XFile file, String prefix) async {
    final uid = _requireUid();
    final bytes = await file.readAsBytes();
    // On web, file.path is a blob URL (blob:http://...) — extract extension
    // from mimeType instead, or default to jpg for images.
    final rawExt = file.path.split('.').last.toLowerCase();
    final ext = rawExt.length > 5 || rawExt.contains('/') ? 'jpg' : rawExt;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final contentType = file.mimeType ?? _mimeType(ext);
    final ref = _storage.ref(
      'private/chats/$chatId/media/$uid/${ts}_$prefix.$ext',
    );
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  String _mimeType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      default:
        return 'image/jpeg';
    }
  }
}

final chatMediaServiceProvider = Provider<ChatMediaService>((ref) {
  return ChatMediaService(storage: FirebaseStorage.instance);
});
