import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/system_model.dart';
import 'systems_repository.dart';

/// Cloud Firestore implementation of [SystemsRepository].
/// Reads monitoring systems from the `systems` collection scoped to the authenticated user.
class FirebaseSystemsRepository implements SystemsRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final String? ownerUid;

  FirebaseSystemsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.ownerUid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get currentOwnerUid => ownerUid ?? _auth.currentUser?.uid;

  Query<Map<String, dynamic>> _userSystemsQuery() {
    final uid = currentOwnerUid;
    if (uid == null || uid.isEmpty) {
      // Unauthenticated query safety: matches nothing
      return _firestore
          .collection('systems')
          .where('ownerUid', isEqualTo: '__UNAUTHENTICATED__');
    }
    return _firestore.collection('systems').where('ownerUid', isEqualTo: uid);
  }

  @override
  Future<List<SystemModel>> getActiveSystems() async {
    try {
      final uid = currentOwnerUid;
      debugPrint(
        '[FirebaseSystemsRepository] getActiveSystems query for owner: ${uid != null ? "AUTHENTICATED" : "NULL"}',
      );
      final snapshot = await _userSystemsQuery().get();
      debugPrint(
        '[FirebaseSystemsRepository] getActiveSystems loaded ${snapshot.docs.length} systems',
      );
      return snapshot.docs
          .map((doc) => SystemModel.fromFirestore(doc))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[FirebaseSystemsRepository] getActiveSystems error: $e');
      throw Exception('Failed to fetch active systems: $e');
    }
  }

  @override
  Future<SystemModel?> getSystemById(String id) async {
    try {
      final doc = await _firestore.collection('systems').doc(id).get();
      if (!doc.exists) return null;
      final system = SystemModel.fromFirestore(doc);

      // Verify ownership before returning
      final uid = currentOwnerUid;
      if (uid != null && system.ownerUid != null && system.ownerUid != uid) {
        return null;
      }
      return system;
    } catch (e) {
      debugPrint('[FirebaseSystemsRepository] getSystemById error: $e');
      throw Exception('Failed to fetch system $id: $e');
    }
  }

  @override
  Stream<List<SystemModel>> watchActiveSystems() {
    final uid = currentOwnerUid;
    debugPrint(
      '[FirebaseSystemsRepository] watchActiveSystems stream started for owner: ${uid != null ? "AUTHENTICATED" : "NULL"}',
    );
    return _userSystemsQuery().snapshots().map((snapshot) {
      debugPrint(
        '[FirebaseSystemsRepository] watchActiveSystems received ${snapshot.docs.length} systems',
      );
      return snapshot.docs
          .map((doc) => SystemModel.fromFirestore(doc))
          .toList(growable: false);
    }).handleError((Object error) {
      debugPrint('[FirebaseSystemsRepository] watchActiveSystems stream error: $error');
      throw error;
    });
  }

  @override
  Stream<SystemModel?> watchSystemById(String id) {
    return _firestore.collection('systems').doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      final system = SystemModel.fromFirestore(doc);
      final uid = currentOwnerUid;
      if (uid != null && system.ownerUid != null && system.ownerUid != uid) {
        return null;
      }
      return system;
    }).handleError((Object error) {
      debugPrint('[FirebaseSystemsRepository] watchSystemById stream error: $error');
      throw error;
    });
  }
}

/// Alias for backwards compatibility with earlier references.
typedef FirestoreSystemsRepository = FirebaseSystemsRepository;
