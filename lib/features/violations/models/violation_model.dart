import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a single violation event from a monitoring system.
final class ViolationModel {
  final String id;
  final String systemId;
  final DateTime timestamp;
  final String type;
  final double durationSeconds;
  final double? confidence;
  final String driverName;
  final String? recordingPath;
  final bool resolved;

  const ViolationModel({
    required this.id,
    required this.systemId,
    required this.timestamp,
    required this.type,
    required this.durationSeconds,
    this.confidence,
    required this.driverName,
    this.recordingPath,
    this.resolved = false,
  });

  ViolationModel copyWith({
    String? id,
    String? systemId,
    DateTime? timestamp,
    String? type,
    double? durationSeconds,
    double? confidence,
    String? driverName,
    String? recordingPath,
    bool? resolved,
  }) {
    return ViolationModel(
      id: id ?? this.id,
      systemId: systemId ?? this.systemId,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      confidence: confidence ?? this.confidence ?? this.confidence,
      driverName: driverName ?? this.driverName,
      recordingPath: recordingPath ?? this.recordingPath,
      resolved: resolved ?? this.resolved,
    );
  }

  /// Creates a [ViolationModel] from a Map payload.
  factory ViolationModel.fromMap(
    Map<String, dynamic> data, {
    required String id,
    String? fallbackSystemId,
  }) {
    DateTime parsedTimestamp;
    final rawTimestamp = data['timestamp'];
    if (rawTimestamp is Timestamp) {
      parsedTimestamp = rawTimestamp.toDate();
    } else if (rawTimestamp is DateTime) {
      parsedTimestamp = rawTimestamp;
    } else if (rawTimestamp is int) {
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    } else if (rawTimestamp is String) {
      parsedTimestamp = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else {
      parsedTimestamp = DateTime.now();
    }

    return ViolationModel(
      id: id,
      systemId: data['systemId'] as String? ?? fallbackSystemId ?? '',
      timestamp: parsedTimestamp,
      type: data['type'] as String? ?? 'Drowsiness detected',
      durationSeconds: (data['durationSeconds'] as num?)?.toDouble() ?? 0.0,
      confidence: (data['confidence'] as num?)?.toDouble(),
      driverName: data['driverName'] as String? ?? '',
      recordingPath: data['recordingPath'] as String? ?? data['recordingUrl'] as String?,
      resolved: data['resolved'] as bool? ?? false,
    );
  }

  /// Creates a [ViolationModel] from a Firestore document snapshot.
  factory ViolationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ViolationModel.fromMap(
      doc.data() ?? {},
      id: doc.id,
      fallbackSystemId: doc.reference.parent.parent?.id,
    );
  }

  /// Converts this [ViolationModel] to a Firestore map payload.
  Map<String, dynamic> toFirestore() {
    return {
      'systemId': systemId,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      'durationSeconds': durationSeconds,
      'confidence': confidence,
      'driverName': driverName,
      'recordingPath': recordingPath,
      'resolved': resolved,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViolationModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          systemId == other.systemId &&
          timestamp == other.timestamp &&
          type == other.type &&
          durationSeconds == other.durationSeconds &&
          confidence == other.confidence &&
          driverName == other.driverName &&
          recordingPath == other.recordingPath &&
          resolved == other.resolved;

  @override
  int get hashCode =>
      id.hashCode ^
      systemId.hashCode ^
      timestamp.hashCode ^
      type.hashCode ^
      durationSeconds.hashCode ^
      confidence.hashCode ^
      driverName.hashCode ^
      recordingPath.hashCode ^
      resolved.hashCode;
}
