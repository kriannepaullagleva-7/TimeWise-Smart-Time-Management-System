import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:timewise/providers/focus_provider.dart';
import 'package:timewise/providers/task_provider.dart';

import 'support/test_support.dart';

/// A clock the test moves by hand, so no real waiting is needed.
class _Clock {
  DateTime now = DateTime(2026, 10, 5, 9);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeTaskRepo repo;
  late FakeNotifs notifs;
  late TaskProvider tasks;
  late _Clock clock;
  late FocusProvider focus;

  Future<void> setUpAll_({Map<String, Object>? prefs}) async {
    SharedPreferences.setMockInitialValues(prefs ?? {});
    repo = FakeTaskRepo([makeTask('t1', title: 'Study', minutes: 25), makeTask('t2', title: 'Other', minutes: 10)]);
    notifs = FakeNotifs();
    tasks = TaskProvider(taskRepository: repo, notificationService: notifs)..attachUser('u1');
    clock = _Clock();
    focus = FocusProvider(notifications: notifs, clock: clock.call)..updateTaskProvider(tasks);
    await _flush();
  }

  tearDown(() => focus.dispose());

  test('starting a session runs a countdown from the estimated time', () async {
    await setUpAll_();
    await focus.startFocus(tasks.byId('t1')!);
    expect(focus.state, FocusState.running);
    expect(focus.totalSeconds, 25 * 60);
    expect(focus.remainingSeconds, 25 * 60);
    expect(focus.hasSession, isTrue);
  });

  test('elapsed time comes from the clock, so a busy or backgrounded app loses nothing', () async {
    await setUpAll_();
    await focus.startFocus(tasks.byId('t1')!);
    clock.advance(const Duration(minutes: 10));
    expect(focus.elapsedSeconds, 600);
    expect(focus.remainingSeconds, 15 * 60);
    expect(focus.progress, closeTo(0.4, 0.001));
  });

  test('pause freezes the time and writes the focus time to the task', () async {
    await setUpAll_();
    await focus.startFocus(tasks.byId('t1')!);
    clock.advance(const Duration(minutes: 5));
    await focus.pauseFocus();
    clock.advance(const Duration(minutes: 30));
    expect(focus.state, FocusState.paused);
    expect(focus.elapsedSeconds, 300);
    expect(repo.store.firstWhere((t) => t.id == 't1').elapsedSeconds, 300);
  });

  test('resume continues from where it paused', () async {
    await setUpAll_();
    await focus.startFocus(tasks.byId('t1')!);
    clock.advance(const Duration(minutes: 5));
    await focus.pauseFocus();
    focus.resumeFocus();
    clock.advance(const Duration(minutes: 2));
    expect(focus.elapsedSeconds, 7 * 60);
  });

  test('stop saves the focus time and clears the session', () async {
    await setUpAll_();
    await focus.startFocus(tasks.byId('t1')!);
    clock.advance(const Duration(minutes: 8));
    await focus.stopFocus();
    expect(focus.hasSession, isFalse);
    expect(focus.state, FocusState.stopped);
    expect(repo.store.firstWhere((t) => t.id == 't1').elapsedSeconds, 480);
    expect(notifs.focusEndAt, isNull);
  });

  test('starting another task closes the first and saves its time', () async {
    await setUpAll_();
    await focus.startFocus(tasks.byId('t1')!);
    clock.advance(const Duration(minutes: 3));
    await focus.startFocus(tasks.byId('t2')!);
    expect(focus.currentTask!.id, 't2');
    expect(repo.store.firstWhere((t) => t.id == 't1').elapsedSeconds, 180);
  });

  test('starting the same task again continues instead of restarting', () async {
    await setUpAll_();
    await focus.startFocus(tasks.byId('t1')!);
    clock.advance(const Duration(minutes: 4));
    await focus.startFocus(tasks.byId('t1')!);
    expect(focus.elapsedSeconds, 240);
  });

  test('a task whose estimate is already used up opens as finished and can be extended', () async {
    await setUpAll_();
    final used = tasks.byId('t2')!.copyWith(elapsedSeconds: 10 * 60);
    await focus.startFocus(used);
    expect(focus.state, FocusState.finished);
    focus.extendFocus(15);
    expect(focus.state, FocusState.running);
    expect(focus.totalSeconds, 25 * 60);
    expect(focus.remainingSeconds, 15 * 60);
  });

  test('the end-of-session notification is scheduled for the moment the time is up', () async {
    await setUpAll_();
    await focus.startFocus(tasks.byId('t1')!);
    await _flush();
    expect(notifs.focusEndAt, clock.now.add(const Duration(minutes: 25)));
  });

  test('a saved session is restored as paused with the time it had', () async {
    await setUpAll_(prefs: {
      'focus_task_id': 't1',
      'focus_state': 'running',
      'focus_total_seconds': 1500,
      'focus_base_elapsed': 60,
      'focus_run_started_ms': DateTime(2026, 10, 5, 9).millisecondsSinceEpoch,
      'focus_last_tick_ms': DateTime(2026, 10, 5, 9, 2).millisecondsSinceEpoch,
    });
    await _flush();
    expect(focus.hasSession, isTrue);
    expect(focus.state, FocusState.paused);
    expect(focus.currentTask!.id, 't1');
    expect(focus.elapsedSeconds, 60 + 120);
  });

  test('a saved session for a deleted task is discarded', () async {
    await setUpAll_(prefs: {
      'focus_task_id': 'gone',
      'focus_state': 'paused',
      'focus_total_seconds': 600,
      'focus_base_elapsed': 0,
    });
    await _flush();
    expect(focus.hasSession, isFalse);
  });

  test('closing a restored session never lowers the focus time already logged on the task', () async {
    SharedPreferences.setMockInitialValues({
      'focus_task_id': 't1',
      'focus_state': 'paused',
      'focus_total_seconds': 1500,
      'focus_base_elapsed': 0, // stale counter
    });
    repo = FakeTaskRepo([makeTask('t1', minutes: 25).copyWith(elapsedSeconds: 180)]);
    notifs = FakeNotifs();
    tasks = TaskProvider(taskRepository: repo, notificationService: notifs)..attachUser('u1');
    clock = _Clock();
    focus = FocusProvider(notifications: notifs, clock: clock.call)..updateTaskProvider(tasks);
    await _flush();

    expect(focus.elapsedSeconds, 180);
    await focus.stopFocus();
    expect(repo.store.single.elapsedSeconds, 180);
  });

  test('stopping when no session exists is harmless', () async {
    await setUpAll_();
    await focus.stopFocus();
    expect(focus.hasSession, isFalse);
  });

}
