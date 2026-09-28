import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/violation_model.dart';
import 'violations_repository.dart';

/// Cloud Firestore implementation of [ViolationsRepository].
/// Reads violation records from `systems/{systemId}/violations/{violationId}`.
class FirebaseViolationsRepository implements ViolationsRepository {
  final FirebaseFirestore _firestore;

  FirebaseViolationsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _violationsCollection(
    String systemId,
  ) {
    return _firestore
        .collection('systems')
        .doc(systemId)
        .collection('violations');
  }

  @override
  Future<List<ViolationModel>> getViolationsForSystem(String systemId) async {
    try {
      debugPrint(
        '[FirebaseViolationsRepository] getViolationsForSystem query: $systemId',
      );
      final snapshot = await _violationsCollection(systemId)
          .orderBy('timestamp', descending: true)
          .get();

      debugPrint(
        '[FirebaseViolationsRepository] loaded ${snapshot.docs.length} violations for $systemId',
      );
      return snapshot.docs
          .map((doc) => ViolationModel.fromFirestore(doc))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[FirebaseViolationsRepository] getViolations error: $e');
      throw Exception('Failed to fetch violations for system $systemId: $e');
    }
  }

  @override
  Future<List<ViolationModel>> getRecentViolations(
    String systemId, {
    int limit = 3,
  }) async {
    try {
      debugPrint(
        '[FirebaseViolationsRepository] getRecentViolations (limit: $limit) query: $systemId',
      );
      final snapshot = await _violationsCollection(systemId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      debugPrint(
        '[FirebaseViolationsRepository] loaded ${snapshot.docs.length} recent violations for $systemId',
      );
      return snapshot.docs
          .map((doc) => ViolationModel.fromFirestore(doc))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[FirebaseViolationsRepository] getRecentViolations error: $e');
      throw Exception(
        'Failed to fetch recent violations for system $systemId: $e',
      );
    }
  }

  @override
  Stream<List<ViolationModel>> watchViolationsForSystem(String systemId) {
    debugPrint(
      '[FirebaseViolationsRepository] watchViolationsForSystem stream: $systemId',
    );
    return _violationsCollection(systemId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint(
        '[FirebaseViolationsRepository] watchViolations received ${snapshot.docs.length} for $systemId',
      );
      return snapshot.docs
          .map((doc) => ViolationModel.fromFirestore(doc))
          .toList(growable: false);
    }).handleError((Object error) {
      debugPrint('[FirebaseViolationsRepository] watchViolations stream error: $error');
      throw error;
    });
  }

  @override
  Stream<List<ViolationModel>> watchRecentViolations(
    String systemId, {
    int limit = 3,
  }) {
    debugPrint(
      '[FirebaseViolationsRepository] watchRecentViolations stream: $systemId (limit: $limit)',
    );
    return _violationsCollection(systemId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      debugPrint(
        '[FirebaseViolationsRepository] watchRecent received ${snapshot.docs.length} for $systemId',
      );
      return snapshot.docs
          .map((doc) => ViolationModel.fromFirestore(doc))
          .toList(growable: false);
    }).handleError((Object error) {
      debugPrint(
        '[FirebaseViolationsRepository] watchRecent stream error: $error',
      );
      throw error;
    });
  }
}

/// Alias for backwards compatibility with earlier references.
typedef FirestoreViolationsRepository = FirebaseViolationsRepository;
