import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../application/identity/identity_ports.dart';

/// [IdentityUploadPort] over Firebase Storage.
///
/// Sets `contentType` by hand, like `avatar_upload_service.dart` and
/// `chat_media_service.dart`: the Storage rule requires `image/.*`, and
/// `putData` without [SettableMetadata] would send `application/octet-stream`
/// and be denied. The path is built by the caller under
/// `private/identity/{uid}/{batchId}/`.
class IdentityUploadService implements IdentityUploadPort {
  const IdentityUploadService(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<void> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: contentType));
  }
}
