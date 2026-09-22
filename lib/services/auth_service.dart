import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // GoogleSignIn.instance is a process-wide singleton that must be
  // initialized exactly once before use; cache the future so concurrent or
  // repeated sign-in attempts all await the same initialization.
  static Future<void>? _googleSignInInit;

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInit ??= GoogleSignIn.instance.initialize();
  }

  Future<UserModel?> signUpWithEmail(
    String email,
    String name,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User user = result.user!;
      UserModel userModel = UserModel(
        uid: user.uid,
        email: email,
        name: name,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
      return userModel;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user!;
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        // Firestore profile is missing (e.g. account created before this
        // record existed). Recreate a minimal one instead of crashing.
        final userModel = UserModel(
          uid: user.uid,
          email: user.email ?? email,
          name: user.displayName ?? email.split('@').first,
          createdAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
        return userModel;
      }

      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  Future<void> updateUserProfile(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();

      final GoogleSignInAccount googleUser;
      try {
        googleUser = await GoogleSignIn.instance.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) return null;
        rethrow;
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleUser.authentication.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User user = result.user!;

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        UserModel userModel = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? 'User',
          profileImageUrl: user.photoURL,
          createdAt: DateTime.now(),
        );
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toMap());
        return userModel;
      }

      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      // Best-effort: throws if GoogleSignIn was never initialized, which is
      // normal for a user who only ever signed in with email/password.
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Not fatal: Firebase sign-out above already succeeded.
    }
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
