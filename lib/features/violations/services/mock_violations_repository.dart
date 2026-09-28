import '../models/violation_model.dart';
import 'violations_repository.dart';

/// Local mock implementation of [ViolationsRepository] for UI testing and prototyping.
class MockViolationsRepository implements ViolationsRepository {
  final Map<String, List<ViolationModel>> _violations;

  MockViolationsRepository({Map<String, List<ViolationModel>>? initialData})
      : _violations = initialData ?? _defaultViolations;

  static final Map<String, List<ViolationModel>> _defaultViolations = {
    'sys_lakshays_pc': [
      ViolationModel(
        id: 'vio_001',
        systemId: 'sys_lakshays_pc',
        timestamp: DateTime(2026, 9, 21, 19, 31, 42),
        type: 'Drowsiness detected',
        durationSeconds: 4.2,
        confidence: 0.92,
        driverName: 'Lakshay',
      ),
      ViolationModel(
        id: 'vio_002',
        systemId: 'sys_lakshays_pc',
        timestamp: DateTime(2026, 9, 21, 18, 54, 17),
        type: 'Drowsiness detected',
        durationSeconds: 3.7,
        confidence: 0.87,
        driverName: 'Lakshay',
      ),
      ViolationModel(
        id: 'vio_003',
        systemId: 'sys_lakshays_pc',
        timestamp: DateTime(2026, 9, 21, 17, 22, 3),
        type: 'Drowsiness detected',
        durationSeconds: 5.1,
        confidence: 0.95,
        driverName: 'Lakshay',
      ),
    ],
  };

  @override
  Future<List<ViolationModel>> getViolationsForSystem(String systemId) async {
    return List.unmodifiable(_violations[systemId] ?? []);
  }

  @override
  Future<List<ViolationModel>> getRecentViolations(
    String systemId, {
    int limit = 3,
  }) async {
    final all = _violations[systemId] ?? [];
    final sorted = List<ViolationModel>.from(all)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.unmodifiable(sorted.take(limit));
  }

  @override
  Stream<List<ViolationModel>> watchViolationsForSystem(String systemId) {
    return Stream.value(List.unmodifiable(_violations[systemId] ?? []));
  }

  @override
  Stream<List<ViolationModel>> watchRecentViolations(
    String systemId, {
    int limit = 3,
  }) {
    final all = _violations[systemId] ?? [];
    final sorted = List<ViolationModel>.from(all)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return Stream.value(List.unmodifiable(sorted.take(limit)));
  }
}
