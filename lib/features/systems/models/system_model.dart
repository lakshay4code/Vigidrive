import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a connected drowsiness monitoring system (e.g. vehicle PC).
final class SystemModel {
  final String id;
  final String name;
  final bool isConnected;
  final bool hasUnresolvedViolations;
  final String? driverName;
  final String? driverPhone;
  final String? ownerUid;

  const SystemModel({
    required this.id,
    required this.name,
    this.isConnected = true,
    this.hasUnresolvedViolations = false,
    this.driverName,
    this.driverPhone,
    this.ownerUid,
  });

  SystemModel copyWith({
    String? id,
    String? name,
    bool? isConnected,
    bool? hasUnresolvedViolations,
    String? driverName,
    String? driverPhone,
    String? ownerUid,
  }) {
    return SystemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isConnected: isConnected ?? this.isConnected,
      hasUnresolvedViolations:
          hasUnresolvedViolations ?? this.hasUnresolvedViolations,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      ownerUid: ownerUid ?? this.ownerUid,
    );
  }

  /// Creates a [SystemModel] from a Map payload.
  factory SystemModel.fromMap(
    Map<String, dynamic> data, {
    required String id,
  }) {
    // Support boolean isOnline, isConnected, and string connectionStatus
    bool connected = true;
    if (data.containsKey('isOnline') && data['isOnline'] is bool) {
      connected = data['isOnline'] as bool;
    } else if (data.containsKey('isConnected') && data['isConnected'] is bool) {
      connected = data['isConnected'] as bool;
    } else if (data.containsKey('connectionStatus')) {
      final status = (data['connectionStatus'] as String?)?.toUpperCase();
      connected = status == 'ACTIVE' || status == 'ONLINE';
    }

    return SystemModel(
      id: id,
      name: data['name'] as String? ?? 'Unnamed System',
      isConnected: connected,
      hasUnresolvedViolations: data['hasUnresolvedViolations'] as bool? ?? false,
      driverName: data['driverName'] as String?,
      driverPhone: data['driverPhone'] as String?,
      ownerUid: data['ownerUid'] as String?,
    );
  }

  /// Creates a [SystemModel] from a Firestore document snapshot.
  factory SystemModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return SystemModel.fromMap(doc.data() ?? {}, id: doc.id);
  }

  /// Converts this [SystemModel] to a Firestore map payload.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'isOnline': isConnected,
      'isConnected': isConnected,
      'connectionStatus': isConnected ? 'ACTIVE' : 'INACTIVE',
      'hasUnresolvedViolations': hasUnresolvedViolations,
      'driverName': driverName,
      'driverPhone': driverPhone,
      if (ownerUid != null) 'ownerUid': ownerUid,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SystemModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          isConnected == other.isConnected &&
          hasUnresolvedViolations == other.hasUnresolvedViolations &&
          driverName == other.driverName &&
          driverPhone == other.driverPhone &&
          ownerUid == other.ownerUid;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      isConnected.hashCode ^
      hasUnresolvedViolations.hashCode ^
      driverName.hashCode ^
      driverPhone.hashCode ^
      ownerUid.hashCode;
}
