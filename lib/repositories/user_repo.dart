import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_app/models/user.dart';

class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> streamUser(String userId) {
    return _db
        .collection('apps/group-chat/users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.data() == null
          ? null
          : User.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  Future<void> createOrUpdateUser(User user) async {
    Map<String, dynamic> userMap = user.toMap();
    await _db
        .collection('apps/group-chat/users')
        .doc(user.id)
        .set(userMap); // write to local cache immediately
  }

  Future<User?> getUserByEmail(String email) async {
    QuerySnapshot querySnapshot = await _db
        .collection('apps/group-chat/users')
        .where('email', isEqualTo: email)
        .get();
    if (querySnapshot.docs.isEmpty) {
      return null;
    }
    return User.fromMap(querySnapshot.docs.first.data() as Map<String, dynamic>,
        querySnapshot.docs.first.id);
  }

    /// Registers/updates the device notification token for a user.
  Future<void> updateFcmToken(String userId, String token) async {
    await _db
        .collection('apps/group-chat/users')
        .doc(userId)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }

  /// Removes the device notification token so no further notifications are
  /// delivered to a logged-out session.
  Future<void> removeFcmToken(String userId) async {
    await _db
        .collection('apps/group-chat/users')
        .doc(userId)
        .set({'fcmToken': FieldValue.delete()}, SetOptions(merge: true));
  }

  /// Updates the user's online presence and last seen time.
  Future<void> updatePresence(String userId, bool isOnline) async {
    await _db.collection('apps/group-chat/users').doc(userId).set({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Records logout activity: marks the user offline, updates last seen and
  /// keeps a history of logout times.
  Future<void> recordLogout(String userId) async {
    await _db.collection('apps/group-chat/users').doc(userId).set({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
      'lastLogoutAt': FieldValue.serverTimestamp(),
      'logoutHistory': FieldValue.arrayUnion([Timestamp.now()]),
    }, SetOptions(merge: true));
  }

}
