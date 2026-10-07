import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/onboarding_store.dart';
import '../utils/app_logger.dart';

class AuthProvider extends ChangeNotifier {
  static const _module = 'AuthProvider';

  final AuthService _authService;
  final Future<Map<String, String>?> Function() _takeOnboarding;
  StreamSubscription<User?>? _authSub;

  AuthProvider({
    AuthService? authService,
    Future<Map<String, String>?> Function()? takeOnboarding,
  })  : _authService = authService ?? AuthService(),
        _takeOnboarding = takeOnboarding ?? OnboardingStore.consume {
    // Keep currentUser in sync with Firebase Auth's persisted session so a
    // returning user (app relaunch, no explicit sign-in call) still has
    // their profile loaded.
    _authSub = _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser == null) {
        _currentUser = null;
        _authReady = true;
        notifyListeners();
        return;
      }
      if (_currentUser?.uid != firebaseUser.uid) {
        // An interactive sign-in / sign-up is running: it creates the profile
        // itself and sets _currentUser. Building a placeholder profile here
        // would race with it (and briefly show "Guest User").
        if (_isLoading) return;
        UserModel? profile;
        try {
          profile = await _authService.ensureProfile(firebaseUser);
        } catch (e, st) {
          AppLogger.error(_module, 'Could not load profile', e, st);
        }
        _currentUser = profile ??
            UserModel(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? '',
              name: firebaseUser.displayName ?? 'User',
              createdAt: DateTime.now(),
            );
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

  /// Signed in AND the profile is loaded.
  bool get isAuthenticated => _currentUser != null;

  /// "Email", "Google" or "Guest".
  String get signInMethod => _authService.signInMethod;

  /// True once the initial Firebase auth state (and, if signed in, the
  /// matching Firestore profile) has been resolved at least once.
  bool get isReady => _authReady;

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
        case 'credential-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'The password is too weak. Use at least 6 characters.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled for the app yet.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'requires-recent-login':
          return 'Please sign in again, then repeat this action.';
        default:
          return 'Authentication failed. Please try again.';
      }
    }
    if (e is PlatformException) {
      final text = '${e.code} ${e.message}';
      if (text.contains('ApiException: 10') || text.contains('DEVELOPER_ERROR')) {
        return 'Google sign-in is not set up for this build. Add the app\'s SHA-1 fingerprint in the Firebase console.';
      }
      if (e.code == 'network_error') return 'Network error. Please check your connection.';
      return 'Google sign-in failed. Please try again.';
    }
    if (e is FirebaseException && e.code == 'permission-denied') {
      return 'The database refused the request. Check the Firestore security rules.';
    }
    return 'An unexpected error occurred.';
  }

  /// Runs an interactive auth call with shared loading / error handling.
  Future<bool> _run(Future<UserModel?> Function() action, {bool cleanupOnFailure = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final profile = await action();
      if (profile == null) {
        // The user cancelled (for example the Google account picker).
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _currentUser = await _applyOnboarding(profile);
      _authReady = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.error(_module, 'Authentication failed', e, st);
      _errorMessage = _handleAuthError(e);
      _isLoading = false;
      if (cleanupOnFailure && _authService.currentUser != null) {
        // The account was created but the profile could not be written: sign
        // out so the app is never left half signed in.
        try {
          await _authService.signOut();
        } catch (_) {}
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String email, String name, String password) =>
      _run(() => _authService.signUpWithEmail(email, name, password), cleanupOnFailure: true);

  Future<bool> signIn(String email, String password) =>
      _run(() => _authService.signInWithEmail(email, password));

  Future<bool> signInWithGoogle() => _run(() => _authService.signInWithGoogle(), cleanupOnFailure: true);

  /// Copies the quiz answers (taken before sign-in) into the new profile.
  Future<UserModel> _applyOnboarding(UserModel profile) async {
    try {
      final answers = await _takeOnboarding();
      if (answers == null || answers.isEmpty) return profile;
      final updated = profile.copyWith(
        wakeTime: answers['wake'] ?? profile.wakeTime,
        sleepTime: answers['sleep'] ?? profile.sleepTime,
        onboarding: {
          ...profile.onboarding,
          for (final key in ['usage', 'scheduleStyle', 'aiHelp'])
            if (answers[key] != null) key: answers[key]!,
        },
      );
      await _authService.updateUserProfile(updated);
      return updated;
    } catch (e, st) {
      AppLogger.error(_module, 'Could not apply onboarding answers', e, st);
      return profile;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _errorMessage = null;
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (e, st) {
      AppLogger.error(_module, 'Password reset failed', e, st);
      _errorMessage = _handleAuthError(e);
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
    _errorMessage = null;
    try {
      await _authService.updateUserProfile(updated);
      _currentUser = updated;
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.error(_module, 'Profile update failed', e, st);
      _errorMessage = _handleAuthError(e);
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
