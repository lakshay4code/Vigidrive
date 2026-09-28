import 'package:cloud_firestore/cloud_firestore.dart';

/// User profile model representing a registered driver or fleet manager in Firestore.
/// Stored in `users/{uid}`.
final class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    required this.createdAt,
  });

  /// Creates a [UserModel] from a Firestore document snapshot.
  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    DateTime parsedCreatedAt;
    final rawTimestamp = data['createdAt'];
    if (rawTimestamp is Timestamp) {
      parsedCreatedAt = rawTimestamp.toDate();
    } else if (rawTimestamp is String) {
      parsedCreatedAt = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return UserModel(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String?,
      createdAt: parsedCreatedAt,
    );
  }

  /// Converts this [UserModel] to a Firestore map payload.
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email &&
          displayName == other.displayName &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      uid.hashCode ^
      email.hashCode ^
      displayName.hashCode ^
      createdAt.hashCode;
}
