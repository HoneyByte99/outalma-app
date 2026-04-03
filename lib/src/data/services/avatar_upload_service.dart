import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';

/// Handles avatar image picking from the gallery and upload to Firebase Storage.
///
/// Storage path: /private/users/{uid}/avatar/profile.jpg
/// Returns the HTTPS download URL on success.
class AvatarUploadService {
  AvatarUploadService({
    required FirebaseStorage storage,
    required String uid,
  })  : _storage = storage,
        _uid = uid;

  final FirebaseStorage _storage;
  final String _uid;

  /// Opens the photo gallery, lets the user pick an image, compresses it,
  /// uploads it to Storage, and returns the download URL.
  ///
  /// Returns null if the user cancelled without selecting an image.
  Future<String?> pickAndUpload() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (file == null) return null;

    final ref = _storage.ref('private/users/$_uid/avatar/profile.jpg');
    await ref.putFile(
      File(file.path),
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return ref.getDownloadURL();
  }

  /// Deletes the stored avatar file. Ignores errors if the file does not exist.
  Future<void> deleteAvatar() async {
    try {
      await _storage.ref('private/users/$_uid/avatar/profile.jpg').delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}

final avatarUploadServiceProvider = Provider<AvatarUploadService?>((ref) {
  final authState = ref.watch(authNotifierProvider).valueOrNull;
  if (authState is! AuthAuthenticated) return null;
  return AvatarUploadService(
    storage: FirebaseStorage.instance,
    uid: authState.user.id,
  );
});
