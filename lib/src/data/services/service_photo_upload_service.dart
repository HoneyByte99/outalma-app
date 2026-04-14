import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Handles service photo picking from the gallery and upload to Firebase Storage.
///
/// Storage path: /public/services/{serviceId}/photo_0.jpg
/// Returns the HTTPS download URL on success, null if the user cancelled.
class ServicePhotoUploadService {
  ServicePhotoUploadService({required FirebaseStorage storage})
    : _storage = storage;

  final FirebaseStorage _storage;

  /// Opens the photo gallery, lets the user pick an image, compresses it,
  /// uploads it to Storage under the given [serviceId], and returns the
  /// download URL.
  ///
  /// Returns null if the user cancelled without selecting an image.
  Future<String?> pickAndUpload(String serviceId) async {
    final picker = ImagePicker();
    // maxWidth and imageQuality are not supported on Flutter Web and cause
    // a PlatformException (decodeEnvelope). Skip them on web.
    final XFile? file = kIsWeb
        ? await picker.pickImage(source: ImageSource.gallery)
        : await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1024,
            imageQuality: 80,
          );

    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final contentType = _mimeType(file.path);

    final ref = _storage.ref('public/services/$serviceId/photo_0.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));

    return ref.getDownloadURL();
  }

  /// Deletes the stored photo. Ignores errors if the file does not exist.
  Future<void> deletePhoto(String serviceId) async {
    try {
      await _storage.ref('public/services/$serviceId/photo_0.jpg').delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  String _mimeType(String path) {
    switch (path.split('.').last.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}

final servicePhotoUploadServiceProvider = Provider<ServicePhotoUploadService>((
  ref,
) {
  return ServicePhotoUploadService(storage: FirebaseStorage.instance);
});
