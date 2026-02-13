import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> signUp(String email, String password, String role) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      // 1️⃣ Create user document
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // 2️⃣ If caregiver, create elderCluster
      if (role == "caregiver") {
        final clusterRef = await _firestore.collection('elderClusters').add({
          'primaryCaregiverId': uid,
          'elderId': null,
          'nurseId': null,
          'familyMembers': [],
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'active'
        });

        // 3️⃣ Save clusterId in user document
        await _firestore.collection('users').doc(uid).update({
          'elderClusterId': clusterRef.id,
        });
      }

      return cred.user;
    } catch (e) {
      print("SIGNUP ERROR: $e");
      rethrow;
    }
  }

  Future<User?> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return cred.user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
