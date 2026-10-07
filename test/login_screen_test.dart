import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:timewise/providers/auth_provider.dart';
import 'package:timewise/screens/auth/login_screen.dart';
import 'package:timewise/theme/app_colors.dart';
import 'package:timewise/theme/app_theme.dart';

import 'support/test_support.dart';

Future<FakeAuth> _pumpLogin(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final service = FakeAuth(testUser);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(authService: service, takeOnboarding: () async => null),
      child: MaterialApp(
        theme: withRoboto(AppTheme.light(accentColor: AppColors.primary)),
        home: const LoginScreen(),
      ),
    ),
  );
  await tester.pump();
  return service;
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('shows the sign-in form with Google option', (tester) async {
    setDevice(tester, 390, 844);
    await _pumpLogin(tester);

    expect(find.text('TimeWise'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('empty form shows a message under each field', (tester) async {
    setDevice(tester, 390, 844);
    await _pumpLogin(tester);

    await tester.tap(find.text('Sign In').last);
    await tester.pump();

    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('a malformed email is explained', (tester) async {
    setDevice(tester, 390, 844);
    await _pumpLogin(tester);

    await tester.enterText(find.byType(TextField).first, 'not-an-email');
    await tester.enterText(find.byType(TextField).last, 'secret1');
    await tester.tap(find.text('Sign In').last);
    await tester.pump();

    expect(find.textContaining('Enter a valid email'), findsOneWidget);
  });

  testWidgets('Sign Up asks for a name and a password of at least 6 characters', (tester) async {
    setDevice(tester, 390, 844);
    await _pumpLogin(tester);

    await tester.tap(find.text('Sign Up').first);
    await tester.pump();
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'a@b.co');
    await tester.enterText(find.byType(TextField).last, '123');
    await tester.tap(find.text('Create Account'));
    await tester.pump();

    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Use at least 6 characters.'), findsOneWidget);
  });

  testWidgets('password can be revealed', (tester) async {
    setDevice(tester, 390, 844);
    await _pumpLogin(tester);

    TextField password() => tester.widget<TextField>(find.byType(TextField).last);
    expect(password().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(password().obscureText, isFalse);
  });

  testWidgets('Forgot password: validates the email, then sends the reset link', (tester) async {
    setDevice(tester, 390, 844);
    final service = await _pumpLogin(tester);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsOneWidget);

    await tester.tap(find.text('Send link'));
    await tester.pump();
    expect(find.textContaining('Enter your email address'), findsOneWidget);
    expect(service.resetEmails, isEmpty);

    await tester.enterText(find.byType(TextField).last, 'student@example.com');
    await tester.tap(find.text('Send link'));
    await tester.pumpAndSettle();

    expect(service.resetEmails, ['student@example.com']);
    expect(find.textContaining('a reset link is on its way'), findsOneWidget);
  });
}
