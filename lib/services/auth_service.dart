// ignore_for_file: use_build_context_synchronously
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stable v6 GoogleSignIn constructor — does NOT require SHA-1 pre-registration
  // for the sign-in flow to be initiated (SHA-1 still needed for actual authentication
  // to succeed on Android; add it in Firebase Console when ready).
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ─── Email / Password ───────────────────────────────────────────────────────

  Future<UserModel?> signUpWithEmail(
    String email,
    String name,
    String password,
  ) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = result.user!;
    // Update Firebase Auth display name so it shows everywhere
    await user.updateDisplayName(name.trim());

    final userModel = UserModel(
      uid: user.uid,
      email: email.trim(),
      name: name.trim(),
      createdAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
    return userModel;
  }

  Future<UserModel?> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = result.user!;
    return _getOrCreateProfile(user, fallbackEmail: email.trim());
  }

  // ─── Google Sign-In ──────────────────────────────────────────────────────────

  Future<UserModel?> signInWithGoogle() async {
    // Begin interactive sign-in process
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    // User cancelled the sign-in dialog — return null (not an error)
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    final user = result.user!;

    return _getOrCreateProfile(
      user,
      fallbackName: googleUser.displayName ?? 'User',
      photoUrl: googleUser.photoUrl,
    );
  }

  // ─── Anonymous / Guest ───────────────────────────────────────────────────────

  Future<UserModel?> signInAnonymously() async {
    final result = await _auth.signInAnonymously();
    final user = result.user!;

    final doc =
        await _firestore.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      final userModel = UserModel(
        uid: user.uid,
        // Store a placeholder email so the schema (which requires String email) stays valid
        email: 'guest@timewise.app',
        name: 'Guest',
        createdAt: DateTime.now(),
      );
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toMap());
      return userModel;
    }

    return UserModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  // ─── Profile helpers ────────────────────────────────────────────────────────

  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('getUserProfile error: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  // ─── Password Reset ──────────────────────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ─── Sign Out ────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    // Sign out from Google first (best-effort)
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('Google sign-out error (non-fatal): $e');
    }
    // Always sign out from Firebase
    await _auth.signOut();
  }

  // ─── Accessors ───────────────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── Private helpers ─────────────────────────────────────────────────────────

  Future<UserModel?> _getOrCreateProfile(
    User user, {
    String? fallbackEmail,
    String? fallbackName,
    String? photoUrl,
  }) async {
    final doc =
        await _firestore.collection('users').doc(user.uid).get();

    if (doc.exists) {
      var existing = UserModel.fromMap(doc.data() as Map<String, dynamic>);
      bool changed = false;
      
      if (photoUrl != null && photoUrl != existing.profileImageUrl) {
        existing = existing.copyWith(profileImageUrl: photoUrl);
        changed = true;
      }
      
      if (fallbackName != null && fallbackName != 'User' && fallbackName != existing.name) {
        existing = existing.copyWith(name: fallbackName);
        changed = true;
      }
      
      if (changed) {
        await _firestore.collection('users').doc(user.uid).set(existing.toMap());
      }
      return existing;
    }

    // Profile missing — create a minimal one so the app never crashes
    final userModel = UserModel(
      uid: user.uid,
      email: user.email ?? fallbackEmail ?? '',
      name: user.displayName ?? fallbackName ?? user.email?.split('@').first ?? 'User',
      profileImageUrl: user.photoURL ?? photoUrl,
      createdAt: DateTime.now(),
    );
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(userModel.toMap());
    return userModel;
  }
}
