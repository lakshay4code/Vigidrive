import 'package:firebase_storage/firebase_storage.dart';

/// Contract for accessing violation recording assets from cloud storage.
abstract class ViolationRecordingStorageService {
  /// Fetches the public or signed download URL for a violation recording if it exists.
  Future<String?> getRecordingDownloadUrl(String systemId, String violationId);
}

/// Firebase Storage implementation of [ViolationRecordingStorageService].
/// References recordings stored at `systems/{systemId}/violations/{violationId}/recording.mp4`.
class FirebaseViolationRecordingStorageService
    implements ViolationRecordingStorageService {
  final FirebaseStorage _storage;

  FirebaseViolationRecordingStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  @override
  Future<String?> getRecordingDownloadUrl(
    String systemId,
    String violationId,
  ) async {
    try {
      final ref = _storage
          .ref()
          .child('systems')
          .child(systemId)
          .child('violations')
          .child(violationId)
          .child('recording.mp4');

      return await ref.getDownloadURL();
    } catch (_) {
      // Recording not yet uploaded or not found
      return null;
    }
  }
}
