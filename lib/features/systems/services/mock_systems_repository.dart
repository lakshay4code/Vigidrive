import '../models/system_model.dart';
import 'systems_repository.dart';

/// Local mock implementation of [SystemsRepository] for UI testing and prototyping.
class MockSystemsRepository implements SystemsRepository {
  final List<SystemModel> _systems;

  MockSystemsRepository({List<SystemModel>? initialSystems})
      : _systems = initialSystems ??
            const [
              SystemModel(
                id: 'sys_lakshays_pc',
                name: 'LakshaysPC',
                isConnected: true,
                hasUnresolvedViolations: true,
                driverName: 'Lakshay',
                driverPhone: '+919876543210',
              ),
              SystemModel(
                id: 'sys_vehicle_pc_02',
                name: 'Vehicle-PC-02',
                isConnected: true,
                hasUnresolvedViolations: false,
                driverName: 'Arjun',
                driverPhone: '+919876543211',
              ),
              SystemModel(
                id: 'sys_vehicle_pc_03',
                name: 'Vehicle-PC-03',
                isConnected: true,
                hasUnresolvedViolations: false,
                driverName: 'Priya',
                driverPhone: '+919876543212',
              ),
            ];

  @override
  Future<List<SystemModel>> getActiveSystems() async {
    return List.unmodifiable(_systems);
  }

  @override
  Future<SystemModel?> getSystemById(String id) async {
    try {
      return _systems.firstWhere((system) => system.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<SystemModel>> watchActiveSystems() {
    return Stream.value(List.unmodifiable(_systems));
  }

  @override
  Stream<SystemModel?> watchSystemById(String id) {
    try {
      return Stream.value(_systems.firstWhere((system) => system.id == id));
    } catch (_) {
      return Stream.value(null);
    }
  }
}
