import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_test/flutter_test.dart';

import 'package:timewise/models/user.dart';
import 'package:timewise/providers/auth_provider.dart';

import 'support/test_support.dart';

/// Auth service whose calls can be made to fail with a given Firebase error.
class _FailingAuth extends FakeAuth {
  Object? error;
  _FailingAuth() : super(testUser);

  @override
  Future<UserModel?> signInWithEmail(String e, String p) async => error == null ? super.signInWithEmail(e, p) : throw error!;
  @override
  Future<void> sendPasswordResetEmail(String email) async => error == null ? super.sendPasswordResetEmail(email) : throw error!;
}

void main() {
  test('signIn loads the profile and marks the provider ready', () async {
    final auth = AuthProvider(authService: FakeAuth(testUser), takeOnboarding: () async => null);
    expect(auth.isReady, isFalse);
    expect(await auth.signIn('a@b.co', 'secret1'), isTrue);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.currentUser!.uid, 'u1');
    expect(auth.isReady, isTrue);
    expect(auth.errorMessage, isNull);
  });

  test('quiz answers saved before sign-in are copied into the new profile', () async {
    final service = FakeAuth(testUser);
    final auth = AuthProvider(
      authService: service,
      takeOnboarding: () async => {'wake': '06:00', 'sleep': '22:00', 'usage': 'School', 'scheduleStyle': 'Fixed', 'aiHelp': 'Full'},
    );
    await auth.signUp('a@b.co', 'Name', 'secret1');
    final u = auth.currentUser!;
    expect(u.wakeTime, '06:00');
    expect(u.sleepTime, '22:00');
    expect(u.onboarding, {'usage': 'School', 'scheduleStyle': 'Fixed', 'aiHelp': 'Full'});
  });

  group('error messages are plain sentences', () {
    Future<String?> failWith(String code) async {
      final service = _FailingAuth()..error = FirebaseAuthException(code: code);
      final auth = AuthProvider(authService: service, takeOnboarding: () async => null);
      expect(await auth.signIn('a@b.co', 'x'), isFalse);
      expect(auth.isAuthenticated, isFalse);
      return auth.errorMessage;
    }

    test('wrong credentials', () async {
      expect(await failWith('invalid-credential'), 'Invalid email or password.');
      expect(await failWith('wrong-password'), 'Invalid email or password.');
      expect(await failWith('user-not-found'), 'Invalid email or password.');
    });

    test('network, throttling, disabled', () async {
      expect(await failWith('network-request-failed'), contains('connection'));
      expect(await failWith('too-many-requests'), contains('later'));
      expect(await failWith('user-disabled'), contains('disabled'));
    });

    test('unknown codes get a generic message without the code', () async {
      final message = await failWith('some-new-code');
      expect(message, 'Authentication failed. Please try again.');
    });
  });

  test('password reset reports success and failure', () async {
    final service = _FailingAuth();
    final auth = AuthProvider(authService: service, takeOnboarding: () async => null);
    expect(await auth.sendPasswordReset('a@b.co'), isTrue);
    expect(service.resetEmails, ['a@b.co']);

    service.error = FirebaseAuthException(code: 'invalid-email');
    expect(await auth.sendPasswordReset('bad'), isFalse);
    expect(auth.errorMessage, contains('not valid'));
  });



  test('updateProfile stores the new profile in memory on success', () async {
    final auth = AuthProvider(authService: FakeAuth(testUser), takeOnboarding: () async => null);
    await auth.signIn('a@b.co', 'x');
    expect(await auth.updateProfile(auth.currentUser!.copyWith(categories: ['A', 'B'])), isTrue);
    expect(auth.currentUser!.categories, ['A', 'B']);
  });

  test('signOut clears the user', () async {
    final auth = AuthProvider(authService: FakeAuth(testUser), takeOnboarding: () async => null);
    await auth.signIn('a@b.co', 'x');
    await auth.signOut();
    expect(auth.isAuthenticated, isFalse);
  });
}
