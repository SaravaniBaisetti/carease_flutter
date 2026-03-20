import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sign up a new user. Returns a map with 'user' and 'clusterError'.
  ///
  /// Elder: Creates user doc + new elderCluster (elder owns the cluster).
  /// Caregiver: Creates user doc with clusterIds:[]. Joins cluster via invite code.
  /// Family: Creates user doc with clusterIds:[]. Joins cluster via invite code.
  Future<Map<String, dynamic>> signUp(String email, String password, String role, {String? inviteCode}) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = cred.user!.uid;
    String? clusterError;

    // Step 1: Create user document
    try {
      if (role == "elder") {
        // Elder gets a single cluster ID
        await _firestore.collection('users').doc(uid).set({
          'email': email,
          'role': role,
          'name': '',
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
      } else {
        // Caregiver and Family get an array of cluster IDs
        await _firestore.collection('users').doc(uid).set({
          'email': email,
          'role': role,
          'name': '',
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'clusterIds': <String>[],
        });
      }
    } catch (e) {
      debugPrint('USER DOC CREATION WARNING: $e');
    }

    // Step 2: Cluster setup
    try {
      if (role == "elder") {
        // Elder creates their OWN cluster
        final clusterRef = await _firestore.collection('elderClusters').add({
          'elderId': uid,
          'elderName': '',
          'primaryCaregiverId': null,
          'familyMembers': <String>[],
          'nurseIds': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'active',
        });

        // Save cluster ID to elder's user doc
        await _firestore.collection('users').doc(uid).update({
          'elderClusterId': clusterRef.id,
        });

        debugPrint('SUCCESS: Elder cluster ${clusterRef.id} created for $uid');
      } else if (role == "caregiver" && inviteCode != null) {
        clusterError = await joinClusterAsCaregiver(uid, inviteCode);
      } else if (role == "family" && inviteCode != null) {
        clusterError = await joinClusterAsFamily(uid, inviteCode);
      }
    } catch (e) {
      debugPrint('CLUSTER SETUP ERROR: $e');
      clusterError = e.toString();
    }

    await _updateFCMToken(uid);

    return {
      'user': cred.user,
      'clusterError': clusterError,
    };
  }

  /// Caregiver joins an elder's cluster. Returns null on success.
  Future<String?> joinClusterAsCaregiver(String uid, String clusterId) async {
    try {
      final clusterDoc = await _firestore.collection('elderClusters').doc(clusterId).get();
      if (!clusterDoc.exists) {
        return 'Invalid invite code — cluster does not exist.';
      }

      // Check if cluster already has a caregiver
      final existingCaregiver = clusterDoc.data()?['primaryCaregiverId'];
      if (existingCaregiver != null && existingCaregiver.toString().isNotEmpty) {
        return 'This elder already has a caregiver assigned.';
      }

      // Set this caregiver as the primary caregiver
      await _firestore.collection('elderClusters').doc(clusterId).update({
        'primaryCaregiverId': uid,
      });

      // Add cluster ID to caregiver's clusterIds array
      await _firestore.collection('users').doc(uid).update({
        'clusterIds': FieldValue.arrayUnion([clusterId]),
      });

      debugPrint('SUCCESS: Caregiver $uid joined cluster $clusterId');
      return null;
    } catch (e) {
      debugPrint('JOIN CLUSTER AS CAREGIVER ERROR: $e');
      return 'Failed to join cluster: $e';
    }
  }

  /// Family member joins an elder's cluster. Returns null on success.
  Future<String?> joinClusterAsFamily(String uid, String clusterId) async {
    try {
      final clusterDoc = await _firestore.collection('elderClusters').doc(clusterId).get();
      if (!clusterDoc.exists) {
        return 'Invalid invite code — cluster does not exist.';
      }

      // Add family member to cluster
      await _firestore.collection('elderClusters').doc(clusterId).update({
        'familyMembers': FieldValue.arrayUnion([uid]),
      });

      // Add cluster ID to family member's clusterIds array
      await _firestore.collection('users').doc(uid).update({
        'clusterIds': FieldValue.arrayUnion([clusterId]),
      });

      debugPrint('SUCCESS: Family member $uid joined cluster $clusterId');
      return null;
    } catch (e) {
      debugPrint('JOIN CLUSTER AS FAMILY ERROR: $e');
      return 'Failed to join cluster: $e';
    }
  }

  Future<User?> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _updateFCMToken(cred.user?.uid);
    return cred.user;
  }

  Future<void> _updateFCMToken(String? uid) async {
    if (uid == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
        });
      }
    } catch (e) {
      debugPrint('FCM Token generation error: $e');
    }
  }

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
           await _firestore.collection('users').doc(uid).update({
             'fcmTokens': FieldValue.arrayRemove([token]),
           });
        }
      } catch (e) {}
    }
    await _auth.signOut();
  }
}
