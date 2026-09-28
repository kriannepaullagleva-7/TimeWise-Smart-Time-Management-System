import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:timewise/models/user.dart';
import 'package:timewise/providers/auth_provider.dart';
import 'package:timewise/screens/auth/login_screen.dart';
import 'package:timewise/services/auth_service.dart';

/// Fake [AuthService] so widget tests never touch real Firebase plugins.
class _FakeAuthService implements AuthService {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<UserModel?> signInWithEmail(String email, String password) async =>
      null;

  @override
  Future<UserModel?> signUpWithEmail(
    String email,
    String name,
    String password,
  ) async => null;

  @override
  Future<UserModel?> signInWithGoogle() async => null;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<UserModel?> getUserProfile(String uid) async => null;

  @override
  Future<void> updateUserProfile(UserModel user) async {}

  @override
  Future<UserModel?> signInAnonymously() async => null;
}

void main() {
  testWidgets('LoginScreen shows the sign-in form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(authService: _FakeAuthService()),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('TimeWise'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
  });

  testWidgets('LoginScreen validates empty fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(authService: _FakeAuthService()),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });
}
