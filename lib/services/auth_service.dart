import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // google_sign_in 6.x: the sign-in flow starts without SHA-1 registration,
  // but authentication only succeeds on Android once the app's SHA-1 is added
  // in the Firebase console.
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ─── Email / Password ───────────────────────────────────────────────────────

  Future<UserModel?> signUpWithEmail(String email, String name, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = result.user!;
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
    return _getOrCreateProfile(result.user!, fallbackEmail: email.trim());
  }

  // ─── Google Sign-In ──────────────────────────────────────────────────────────

  Future<UserModel?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    // User cancelled the sign-in dialog — return null (not an error)
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    return _getOrCreateProfile(
      result.user!,
      fallbackName: googleUser.displayName ?? 'User',
      photoUrl: googleUser.photoUrl,
    );
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

  /// Returns the stored profile, creating a minimal one when it is missing.
  Future<UserModel?> ensureProfile(User user) => _getOrCreateProfile(user);

  Future<void> updateUserProfile(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
    final current = _auth.currentUser;
    if (current != null && current.uid == user.uid && current.displayName != user.name && user.name.isNotEmpty) {
      await current.updateDisplayName(user.name);
    }
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
    await _auth.signOut();
  }

  // ─── Accessors ───────────────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;

  /// "Guest", "Google" or "Email" for the signed-in account.
  String get signInMethod {
    final user = _auth.currentUser;
    if (user == null) return '';
    if (user.isAnonymous) return 'Guest';
    final ids = user.providerData.map((p) => p.providerId).toList();
    if (ids.contains('google.com')) return 'Google';
    return 'Email';
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── Private helpers ─────────────────────────────────────────────────────────

  Future<UserModel?> _getOrCreateProfile(
    User user, {
    String? fallbackEmail,
    String? fallbackName,
    String? photoUrl,
  }) async {
    final doc = await _firestore.collection('users').doc(user.uid).get();

    if (doc.exists) {
      var existing = UserModel.fromMap(doc.data() as Map<String, dynamic>);
      var changed = false;

      // Only fill gaps: never overwrite a name or photo the user chose.
      if (photoUrl != null && existing.profileImageUrl == null) {
        existing = existing.copyWith(profileImageUrl: photoUrl);
        changed = true;
      }
      if (fallbackName != null && fallbackName != 'User' && existing.name.isEmpty) {
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
    await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
    return userModel;
  }
}
