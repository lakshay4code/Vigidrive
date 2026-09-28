import '../models/system_model.dart';

/// Contract for accessing monitoring system data.
/// Easily replaceable by Firestore or real REST API repositories.
abstract class SystemsRepository {
  /// Fetches the list of active systems.
  Future<List<SystemModel>> getActiveSystems();

  /// Fetches a specific system by its unique ID.
  Future<SystemModel?> getSystemById(String id);

  /// Streams the list of active systems for real-time status updates.
  Stream<List<SystemModel>> watchActiveSystems();

  /// Streams a single system by ID for real-time status updates.
  Stream<SystemModel?> watchSystemById(String id);
}
