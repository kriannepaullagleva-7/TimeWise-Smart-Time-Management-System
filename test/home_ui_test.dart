import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:timewise/models/schedule.dart';
import 'package:timewise/screens/dashboard_screen.dart';
import 'package:timewise/screens/home_screen.dart';
import 'package:timewise/screens/schedule/schedule_screen.dart';
import 'package:timewise/screens/tasks/focus_screen.dart';
import 'package:timewise/screens/tasks/task_detail_screen.dart';
import 'package:timewise/services/ai_service.dart';

import 'support/test_support.dart';

void main() {
  setUpAll(loadTestFonts);

  group('Dashboard', () {
    testWidgets('greets by name and states the real situation (no canned text)', (tester) async {
      setDevice(tester, 390, 1400);
      final c = await makeCtx();
      await pumpScreen(tester, c, DashboardScreen(onNavigateToTab: (_) {}));

      expect(find.textContaining(', Test'), findsOneWidget);
      expect(find.textContaining('3 pending tasks'), findsOneWidget);
      for (final canned in ['peak focus window', 'Math Problem Set at 9:30 PM', 'Flutter Project at 3:15 PM']) {
        expect(find.textContaining(canned), findsNothing);
      }
      expect(find.byType(TextField), findsNothing, reason: 'there is no fake chat box any more');
    });

    testWidgets('free time counts every scheduled item once (13.8 h free)', (tester) async {
      setDevice(tester, 390, 1400);
      final items = [
        ScheduleItem(id: 'f', userId: 'u1', title: 'Class', startTime: today(9), endTime: today(10), type: 'class', isFixed: true),
        ScheduleItem(id: 'a', userId: 'u1', title: 'Task', startTime: today(11), endTime: today(12), type: 'task', isAISuggested: true),
        ScheduleItem(id: 'b', userId: 'u1', title: 'Break', startTime: today(12), endTime: today(12, 15), type: 'break', isAISuggested: true),
      ];
      final c = await makeCtx(schedule: items);
      await pumpScreen(tester, c, DashboardScreen(onNavigateToTab: (_) {}));
      expect(find.text('13.8 h free'), findsOneWidget);
    });

    testWidgets('lists today\'s schedule and the most urgent pending tasks', (tester) async {
      setDevice(tester, 390, 2000);
      final c = await makeCtx();
      await pumpScreen(tester, c, DashboardScreen(onNavigateToTab: (_) {}));
      expect(find.text('CS101 Class'), findsOneWidget);
      expect(find.text('Flutter Project'), findsOneWidget);
    });

    testWidgets('a rebuild does not open extra Firestore listeners', (tester) async {
      setDevice(tester, 390, 1400);
      final c = await makeCtx();
      await pumpScreen(tester, c, DashboardScreen(onNavigateToTab: (_) {}));
      final tasksBefore = c.taskRepo.watchAllCalls;
      final daysBefore = c.scheduleRepo.watchDayCalls;

      await c.prefs.setAiSuggestions(false); // rebuilds the dashboard
      await c.prefs.setAiSuggestions(true);
      await settle(tester, 300);
      expect(c.taskRepo.watchAllCalls, tasksBefore);
      expect(c.scheduleRepo.watchDayCalls, daysBefore);
    });

    testWidgets('the AI card is hidden when the AI planner switch is off', (tester) async {
      setDevice(tester, 390, 1400);
      final c = await makeCtx();
      await pumpScreen(tester, c, DashboardScreen(onNavigateToTab: (_) {}));
      expect(find.text('AI SCHEDULE'), findsOneWidget);
      await c.prefs.setAiSuggestions(false);
      await settle(tester, 300);
      expect(find.text('AI SCHEDULE'), findsNothing);
    });

    testWidgets('Plan today with nothing pending says so instead of calling the AI', (tester) async {
      setDevice(tester, 390, 1400);
      final c = await makeCtx(tasks: []);
      await pumpScreen(tester, c, DashboardScreen(onNavigateToTab: (_) {}));
      await tester.tap(find.text('Plan today'));
      await settle(tester, 300);
      expect(find.textContaining('No pending tasks to plan'), findsOneWidget);
    });

    testWidgets('without an API key the planner explains how to enable it', (tester) async {
      setDevice(tester, 390, 1400);
      final c = await makeCtx(ai: AIService(apiKey: ''));
      await pumpScreen(tester, c, DashboardScreen(onNavigateToTab: (_) {}));
      await tester.tap(find.text('Plan tomorrow'));
      await settle(tester, 300);
      expect(find.textContaining('not set up in this build'), findsOneWidget);
    });

    testWidgets('shows a retry state when the tasks cannot be loaded', (tester) async {
      setDevice(tester, 390, 1400);
      final c = await makeCtx(failStream: true);
      await pumpScreen(tester, c, DashboardScreen(onNavigateToTab: (_) {}));
      expect(find.text('Could not load your tasks'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('quick actions switch tabs', (tester) async {
      setDevice(tester, 390, 1400);
      final c = await makeCtx();
      int? tab;
      await pumpScreen(tester, c, DashboardScreen(onNavigateToTab: (i) => tab = i));
      await tester.tap(find.text('Calendar').first);
      expect(tab, 2);
      await tester.tap(find.text('Tasks').first);
      expect(tab, 1);
    });
  });

  group('Home shell', () {
    testWidgets('the + button offers Task and Event', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx();
      await tester.pumpWidget(harness(c, const HomeScreen()));
      await settle(tester, 500);

      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pumpAndSettle();
      expect(find.text('ADD NEW'), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
    });

    testWidgets('bottom tabs switch screens and Back from another tab returns to Home first', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx();
      await tester.pumpWidget(harness(c, const HomeScreen()));
      await settle(tester, 500);

      await tester.tap(find.text('Tasks').last);
      await settle(tester, 300);
      expect(find.text('My Tasks'), findsOneWidget);

      await tester.tap(find.text('Profile').last);
      await settle(tester, 300);
      expect(find.text('Signed in with Email'), findsOneWidget);

      final handled = await tester.binding.handlePopRoute();
      await settle(tester, 300);
      expect(handled, isTrue);
      expect(find.textContaining('Good '), findsWidgets, reason: 'Back returns to the Home tab');
    });

    testWidgets('a running focus session shows a strip that reopens Focus mode', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx();
      await c.focus.startFocus(c.tasks.byId('t1')!);
      await tester.pumpWidget(harness(c, const HomeScreen()));
      await settle(tester, 500);

      expect(find.textContaining('left'), findsWidgets);
      await tester.tap(find.text('Research Paper').last);
      await settle(tester, 500);
      expect(find.byType(FocusScreen), findsOneWidget);
      await c.focus.stopFocus();
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('Calendar', () {
    testWidgets('shows the day\'s events with their kind', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx();
      await pumpScreen(tester, c, const ScheduleScreen());
      expect(find.text('CS101 Class'), findsOneWidget);
      expect(find.text('Fixed'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
    });

    testWidgets('empty day: friendly empty state', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(tasks: [], schedule: []);
      await pumpScreen(tester, c, const ScheduleScreen());
      expect(find.text('Nothing planned'), findsOneWidget);
    });

    testWidgets('Week / Month toggle changes the grid', (tester) async {
      setDevice(tester, 390, 1200);
      final c = await makeCtx();
      await pumpScreen(tester, c, const ScheduleScreen());
      final weekHeight = tester.getSize(find.byType(ScheduleScreen)).height;
      expect(weekHeight, greaterThan(0));
      final before = find.text('1').evaluate().length;
      await tester.tap(find.text('Month'));
      await settle(tester, 300);
      expect(find.text('1').evaluate().length, greaterThanOrEqualTo(before));
      expect(find.text('28'), findsWidgets);
    });

    testWidgets('deleting an AI block never deletes the real task', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx();
      await pumpScreen(tester, c, const ScheduleScreen());

      await tester.tap(find.text('Research Paper'));
      await tester.pumpAndSettle();
      expect(find.text('Edit event'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete event?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester, 400);

      expect(c.scheduleRepo.store.any((i) => i.id == 's2'), isFalse);
      expect(c.taskRepo.store.any((t) => t.id == 't1'), isTrue, reason: 'task t1 must survive');
    });

    testWidgets('a repeating event offers this occurrence or the series', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(schedule: [
        for (var i = 0; i < 3; i++)
          ScheduleItem(id: 'r$i', userId: 'u1', title: 'Weekly lab', startTime: day(i * 7, 9), endTime: day(i * 7, 10), type: 'class', isFixed: true, recurrenceId: 'r0'),
      ]);
      await pumpScreen(tester, c, const ScheduleScreen());

      await tester.tap(find.text('Weekly lab'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete repeating event'), findsOneWidget);
      await tester.tap(find.text('Entire series'));
      await settle(tester, 400);
      expect(c.scheduleRepo.store, isEmpty);
    });

    testWidgets('a task due today appears as a Due row that opens the task', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(tasks: [makeTask('d', title: 'Hand in essay', deadline: today(20))], schedule: []);
      await pumpScreen(tester, c, const ScheduleScreen());

      expect(find.text('Hand in essay'), findsOneWidget);
      expect(find.text('Due'), findsOneWidget);
      await tester.tap(find.text('Hand in essay'));
      await settle(tester, 500);
      expect(find.byType(TaskDetailScreen), findsOneWidget);
    });

    testWidgets('AI Schedule with nothing to plan says so', (tester) async {
      setDevice(tester, 390, 844);
      final c = await makeCtx(tasks: [], schedule: []);
      await pumpScreen(tester, c, const ScheduleScreen());
      await tester.tap(find.text('AI Schedule'));
      await settle(tester, 300);
      expect(find.textContaining('No pending tasks to plan'), findsOneWidget);
    });
  });

  group('AI plan review', () {
    AIService planner(String reply, {int status = 200, void Function()? onCall, Duration delay = Duration.zero}) => AIService(
          apiKey: 'k',
          retryDelay: Duration.zero,
          client: MockClient((req) async {
            onCall?.call();
            if (delay > Duration.zero) await Future<void>.delayed(delay);
            return http.Response(
              status == 200 ? '{"candidates":[{"content":{"parts":[{"text":${_json(reply)}}]}}]}' : '{"error":{}}',
              status,
            );
          }),
        );

    Future<Ctx> openPreview(WidgetTester tester, {AIService? ai}) async {
      setDevice(tester, 390, 1600);
      final c = await makeCtx(
        tasks: [makeTask('t1', title: 'Essay', deadline: day(1, 20), minutes: 120, priority: 3)],
        schedule: [],
        ai: ai ?? planner('task|T1|09:00|10:00|due soon\nbreak|Stretch|10:00|10:15|rest'),
      );
      await pumpScreen(tester, c, DashboardScreen(onNavigateToTab: (_) {}));
      await tester.tap(find.text('Plan tomorrow'));
      await tester.pump();
      await settle(tester, 800);
      return c;
    }

    testWidgets('shows the analysing dialog, then the plan with a summary', (tester) async {
      setDevice(tester, 390, 1600);
      final c = await makeCtx(
        tasks: [makeTask('t1', title: 'Essay', deadline: day(1, 20), minutes: 120, priority: 3)],
        schedule: [],
        ai: planner('task|T1|09:00|10:00|due soon', delay: const Duration(milliseconds: 400)),
      );
      await pumpScreen(tester, c, DashboardScreen(onNavigateToTab: (_) {}));
      await tester.tap(find.text('Plan tomorrow'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('AI is analyzing your schedule'), findsOneWidget);
      await settle(tester, 800);
      expect(find.text('Review AI Plan'), findsOneWidget);
      expect(find.text('Essay'), findsWidgets);
      expect(find.textContaining('1 block'), findsOneWidget);
    });

    testWidgets('Accept Plan saves the blocks as AI items for that day', (tester) async {
      final c = await openPreview(tester);
      expect(find.text('Review AI Plan'), findsOneWidget);
      await tester.tap(find.text('Accept Plan'));
      await settle(tester, 800);

      expect(c.scheduleRepo.store.length, 2);
      expect(c.scheduleRepo.store.every((i) => i.isAISuggested && !i.isFixed), isTrue);
      expect(find.text('AI plan saved to your calendar'), findsOneWidget);
      expect(find.text('Review AI Plan'), findsNothing);
    });

    testWidgets('a block can be removed before accepting', (tester) async {
      final c = await openPreview(tester);
      await tester.tap(find.text('Stretch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from plan'));
      await tester.pumpAndSettle();
      expect(find.text('Stretch'), findsNothing);
      await tester.tap(find.text('Accept Plan'));
      await settle(tester, 800);
      expect(c.scheduleRepo.store.length, 1);
    });

    testWidgets('Regenerate asks the AI again', (tester) async {
      var calls = 0;
      await openPreview(tester, ai: planner('task|T1|09:00|10:00|ok', onCall: () => calls++));
      expect(calls, 1);
      await tester.tap(find.text('Regenerate'));
      await settle(tester, 800);
      expect(calls, 2);
    });

    testWidgets('an AI failure is a readable message and nothing is saved', (tester) async {
      setDevice(tester, 390, 1600);
      final c = await makeCtx(
        tasks: [makeTask('t1', title: 'Essay', deadline: day(1, 20))],
        schedule: [],
        ai: planner('', status: 503),
      );
      await pumpScreen(tester, c, DashboardScreen(onNavigateToTab: (_) {}));
      await tester.tap(find.text('Plan tomorrow'));
      await tester.pump();
      await settle(tester, 800);
      expect(find.textContaining('busy right now'), findsOneWidget);
      expect(find.text('Review AI Plan'), findsNothing);
      expect(c.scheduleRepo.store, isEmpty);
    });
  });
}

String _json(String s) => '"${s.replaceAll('\n', r'\n')}"';
