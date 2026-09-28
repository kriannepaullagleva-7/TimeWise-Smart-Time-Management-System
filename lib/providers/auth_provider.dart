import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  StreamSubscription<User?>? _authSub;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    // Keep currentUser in sync with Firebase Auth's persisted session so a
    // returning user (app relaunch, no explicit sign-in call) still has
    // their profile loaded instead of a null user / empty uid.
    _authSub = _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser == null) {
        _currentUser = null;
        _authReady = true;
        notifyListeners();
        return;
      }
      if (_currentUser?.uid != firebaseUser.uid) {
        UserModel? profile = await _authService.getUserProfile(firebaseUser.uid);
        profile ??= UserModel(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? 'guest_${firebaseUser.uid.substring(0, 5)}@guest.com',
          name: firebaseUser.displayName ?? 'Guest User',
          createdAt: DateTime.now(),
        );
        _currentUser = profile;
      }
      _authReady = true;
      notifyListeners();
    });
  }

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _authReady = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _authService.currentUser != null;

  String _handleAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Invalid email or password.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'operation-not-allowed':
          return 'Operation not allowed. Please contact support.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        default:
          return 'Authentication failed. Please try again.';
      }
    }
    return 'An unexpected error occurred.';
  }

  /// True once the initial Firebase auth state (and, if signed in, the
  /// matching Firestore profile) has been resolved at least once.
  bool get isReady => _authReady;

  Future<bool> signUp(String email, String name, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signUpWithEmail(email, name, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _handleAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signInWithEmail(email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _handleAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signInWithGoogle();
      _isLoading = false;
      notifyListeners();
      return _currentUser != null;
    } catch (e) {
      _errorMessage = _handleAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInAsGuest() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signInAnonymously();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _handleAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = _handleAuthError(e);
      notifyListeners();
    }
  }

  Future<bool> updateProfile(UserModel updated) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.updateUserProfile(updated);
      _currentUser = updated;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _handleAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Stream<User?> get authStateChanges => _authService.authStateChanges;

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
