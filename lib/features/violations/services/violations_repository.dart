import '../models/violation_model.dart';

/// Contract for accessing violation event data.
/// Easily replaceable by Firestore or real REST API repositories.
abstract class ViolationsRepository {
  /// Fetches all violations for a specific system.
  Future<List<ViolationModel>> getViolationsForSystem(String systemId);

  /// Fetches the most recent violations for a system, limited to [limit].
  Future<List<ViolationModel>> getRecentViolations(
    String systemId, {
    int limit = 3,
  });

  /// Streams all violations for a specific system in real-time.
  Stream<List<ViolationModel>> watchViolationsForSystem(String systemId);

  /// Streams recent violations for a system in real-time.
  Stream<List<ViolationModel>> watchRecentViolations(
    String systemId, {
    int limit = 3,
  });
}
