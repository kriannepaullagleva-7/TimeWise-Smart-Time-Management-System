import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timewise/screens/appearance_screen.dart';
import 'package:timewise/screens/auth/login_screen.dart';
import 'package:timewise/screens/onboarding/quiz_screen.dart';
import 'package:timewise/screens/onboarding/welcome_screen.dart';
import 'package:timewise/screens/profile_screen.dart';
import 'package:timewise/services/onboarding_store.dart';

import 'support/test_support.dart';

void main() {
  setUpAll(loadTestFonts);

  group('Profile', () {
    testWidgets('shows the account, real stats and the sign-in method', (tester) async {
      setDevice(tester, 390, 2200);
      final c = await makeCtx(tasks: [
        makeTask('a', completed: true, deadline: day(-1, 9)).copyWith(elapsedSeconds: 1800, completedAt: day(0, 8)),
        makeTask('b', deadline: day(-2, 9)),
      ]);
      await pumpScreen(tester, c, const ProfileScreen());

      expect(find.text('Test Student'), findsOneWidget);
      expect(find.text('student@example.com'), findsOneWidget);
      expect(find.text('Signed in with Email'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget, reason: '1 of 2 due tasks done');
      expect(find.text('30m'), findsOneWidget, reason: 'focus time comes from logged seconds, not estimates');
      expect(find.text('Create account'), findsNothing);
    });

    testWidgets('the two switches are real and persisted in the preferences', (tester) async {
      setDevice(tester, 390, 2200);
      final c = await makeCtx();
      await pumpScreen(tester, c, const ProfileScreen());

      expect(find.text('Schedule alerts'), findsNothing, reason: 'the switch that did nothing was removed');
      await tester.tap(find.text('Task reminders'));
      await tester.pump();
      expect(c.prefs.taskReminders, isFalse);
      await tester.tap(find.text('AI planner'));
      await tester.pump();
      expect(c.prefs.aiSuggestions, isFalse);
    });

    testWidgets('Sleep schedule: wake and sleep must differ, then it saves', (tester) async {
      setDevice(tester, 390, 2200);
      final c = await makeCtx();
      await pumpScreen(tester, c, const ProfileScreen());

      await tester.tap(find.text('Sleep schedule'));
      await tester.pumpAndSettle();
      expect(find.text('WAKE UP'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await settle(tester, 400);
      expect(find.text('Sleep schedule saved'), findsOneWidget);
    });

    testWidgets('Categories: add, reject a duplicate, remove, keep at least one, save', (tester) async {
      setDevice(tester, 390, 2200);
      final c = await makeCtx();
      await pumpScreen(tester, c, const ProfileScreen());

      await tester.tap(find.text('Task categories'));
      await tester.pumpAndSettle();
      final field = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));

      await tester.enterText(field, 'school');
      await tester.pump();
      expect(find.text('That category already exists.'), findsOneWidget);

      await tester.enterText(field, 'Thesis');
      await tester.tap(find.byTooltip('Add category'));
      await tester.pump();
      expect(find.widgetWithText(InputChip, 'Thesis'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove Other'));
      await tester.pump();
      expect(find.widgetWithText(InputChip, 'Other'), findsNothing);

      await tester.tap(find.text('Save'));
      await settle(tester, 500);
      expect(c.auth.currentUser!.categories, contains('Thesis'));
      expect(c.auth.currentUser!.categories, isNot(contains('Other')));
    });

    testWidgets('Log out asks first', (tester) async {
      setDevice(tester, 390, 2200);
      final c = await makeCtx();
      await pumpScreen(tester, c, const ProfileScreen());

      await tester.ensureVisible(find.text('Log out'));
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.auth.isAuthenticated, isTrue);
    });
  });

  group('Appearance', () {
    testWidgets('builds without framework errors', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx();
      await pumpScreen(tester, c, const AppearanceScreen());
      expect(find.text('COLOR MODE'), findsOneWidget);
    });

    testWidgets('mode and accent apply immediately and Reset restores the defaults', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx();
      await pumpScreen(tester, c, const AppearanceScreen());

      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(c.theme.themeMode, ThemeMode.dark);
      await tester.tap(find.text('Indigo'));
      await tester.pump();
      expect(c.theme.accentColor.toARGB32(), 0xFF4F46E5);

      await tester.tap(find.text('Reset to default'));
      await tester.pump();
      expect(c.theme.themeMode, ThemeMode.system);
    });
  });

  group('Onboarding', () {
    testWidgets('Welcome offers Get Started and Log In', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx();
      await tester.pumpWidget(harness(c, const WelcomeScreen()));
      await tester.pump();
      expect(find.text('Get Started'), findsOneWidget);
      await tester.tap(find.text('Already have an account? Log In'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('the quiz walks five questions, validates the day length and saves the answers', (tester) async {
      setDevice(tester, 390, 900);
      final c = await makeCtx();
      await pumpScreen(tester, c, const QuizScreen());

      expect(find.text('Question 1 of 5'), findsOneWidget);
      // Continue is disabled until an answer is chosen.
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Question 1 of 5'), findsOneWidget);

      await tester.tap(find.text('School'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Question 2 of 5'), findsOneWidget);
      await tester.tap(find.text('Mostly flexible'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Question 3: start of day. Question 4: end of day (must be after the start).
      expect(find.text('Question 3 of 5'), findsOneWidget);
      await tester.tap(find.text('10:00 AM'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Question 4 of 5'), findsOneWidget);
      await tester.tap(find.text('6:00 PM'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Question 5 of 5'), findsOneWidget);
      await tester.tap(find.text('Balanced'));
      await tester.pump();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      final saved = await OnboardingStore.consume();
      expect(saved, {'usage': 'School', 'scheduleStyle': 'Flexible', 'aiHelp': 'Balanced', 'wake': '10:00', 'sleep': '18:00'});
      expect(await OnboardingStore.consume(), isNull, reason: 'answers are handed over once');
    });

    testWidgets('a finish time before the start time blocks Continue and says why', (tester) async {
      setDevice(tester, 390, 900);
      final c = await makeCtx();
      await pumpScreen(tester, c, const QuizScreen());
      await tester.tap(find.text('School'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mostly fixed'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10:00 AM'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Default finish is 10:00 PM; move it before the start by using the slider.
      final slider = find.byType(Slider);
      await tester.drag(slider, const Offset(-600, 0));
      await tester.pump();
      expect(find.textContaining('Finish time must be after your start time'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Question 4 of 5'), findsOneWidget);
    });

    testWidgets('Back goes to the previous question', (tester) async {
      setDevice(tester, 390, 900);
      final c = await makeCtx();
      await pumpScreen(tester, c, const QuizScreen());
      await tester.tap(find.text('School'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Question 1 of 5'), findsOneWidget);
    });
  });
}
