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
        _currentUser = await _authService.getUserProfile(firebaseUser.uid);
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
      _errorMessage = e.toString();
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
      _errorMessage = e.toString();
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
      _errorMessage = e.toString();
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
      _errorMessage = e.toString();
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
      _errorMessage = e.toString();
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
