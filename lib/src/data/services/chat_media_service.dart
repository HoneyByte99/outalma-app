import 'dart:io';

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
  ChatMediaService({required FirebaseStorage storage}) : _storage = storage;

  final FirebaseStorage _storage;
  final _picker = ImagePicker();

  /// Pick an image from gallery and upload. Returns download URL or null.
  Future<String?> pickImageFromGallery(String chatId) async {
    final file = kIsWeb
        ? await _picker.pickImage(source: ImageSource.gallery)
        : await _picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1024,
            imageQuality: 80,
          );
    if (file == null) return null;
    return _uploadFile(chatId, file, 'image');
  }

  /// Take a photo with camera and upload. Returns download URL or null.
  Future<String?> takePhoto(String chatId) async {
    final file = kIsWeb
        ? await _picker.pickImage(source: ImageSource.camera)
        : await _picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1024,
            imageQuality: 80,
          );
    if (file == null) return null;
    return _uploadFile(chatId, file, 'image');
  }

  /// Upload a voice recording file. Returns download URL.
  Future<String> uploadVoice(String chatId, String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('private/chats/$chatId/media/${ts}_voice.m4a');
    await ref.putData(bytes, SettableMetadata(contentType: 'audio/mp4'));
    return ref.getDownloadURL();
  }

  Future<String> _uploadFile(String chatId, XFile file, String prefix) async {
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final contentType = _mimeType(ext);
    final ref =
        _storage.ref('private/chats/$chatId/media/${ts}_$prefix.$ext');
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
