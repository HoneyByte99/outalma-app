import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Handles service photo picking from the gallery and upload to Firebase Storage.
///
/// Storage path: /public/services/{serviceId}/photo_{timestamp}.jpg
/// Each upload uses a unique filename so existing photos are preserved
/// (services support multiple photos).
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

    // Unique filename per upload so we never overwrite existing photos.
    final ext = _extension(file.path);
    final filename = 'photo_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref('public/services/$serviceId/$filename');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));

    return ref.getDownloadURL();
  }

  /// Deletes a stored photo by its download URL. Ignores errors if the file
  /// does not exist.
  Future<void> deletePhotoByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  String _extension(String path) {
    switch (path.split('.').last.toLowerCase()) {
      case 'png':
        return 'png';
      case 'gif':
        return 'gif';
      case 'webp':
        return 'webp';
      default:
        return 'jpg';
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
