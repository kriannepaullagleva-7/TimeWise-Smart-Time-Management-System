// Shared fakes and helpers for the TimeWise tests.
//
// No Firebase, network or API key is needed: Firestore and notifications are
// replaced by in-memory fakes and Gemini by a mocked HTTP client.
import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:timewise/models/schedule.dart';
import 'package:timewise/models/task.dart';
import 'package:timewise/models/user.dart';
import 'package:timewise/providers/auth_provider.dart';
import 'package:timewise/providers/focus_provider.dart';
import 'package:timewise/providers/preferences_provider.dart';
import 'package:timewise/providers/schedule_provider.dart';
import 'package:timewise/providers/task_provider.dart';
import 'package:timewise/providers/theme_provider.dart';
import 'package:timewise/repositories/schedule_repository.dart';
import 'package:timewise/repositories/task_repository.dart';
import 'package:timewise/services/ai_service.dart';
import 'package:timewise/services/auth_service.dart';
import 'package:timewise/services/notification_service.dart';
import 'package:timewise/theme/app_colors.dart';
import 'package:timewise/theme/app_theme.dart';

// ── Fonts ──────────────────────────────────────────────────────────────────
// flutter_test draws text with the very wide "Ahem" font unless real fonts are
// loaded, which makes overflow tests fail for the wrong reason. This loads
// Roboto and Material Icons from the Flutter SDK (FLUTTER_ROOT).
bool _fontsLoaded = false;

Future<void> loadTestFonts() async {
  if (_fontsLoaded) return;
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/dev/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> bytes(String f) async => ByteData.sublistView(File('$dir/$f').readAsBytesSync());
  final roboto = FontLoader('Roboto');
  for (final f in ['regular', 'medium', 'bold', 'black', 'light', 'italic']) {
    roboto.addFont(bytes('roboto-$f.ttf'));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(bytes('materialicons-regular.otf'));
  await icons.load();
  _fontsLoaded = true;
}

/// Makes every text style that does not name a font family use Roboto.
ThemeData withRoboto(ThemeData t) {
  TextStyle roboto(TextStyle? s) => (s ?? const TextStyle()).copyWith(fontFamily: 'Roboto');
  ButtonStyle? fix(ButtonStyle? b) => b?.copyWith(textStyle: WidgetStatePropertyAll(roboto(b.textStyle?.resolve({}))));
  return t.copyWith(
    textTheme: t.textTheme.apply(fontFamily: 'Roboto'),
    elevatedButtonTheme: ElevatedButtonThemeData(style: fix(t.elevatedButtonTheme.style)),
    filledButtonTheme: FilledButtonThemeData(style: fix(t.filledButtonTheme.style)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: fix(t.outlinedButtonTheme.style)),
    textButtonTheme: TextButtonThemeData(style: fix(t.textButtonTheme.style)),
    chipTheme: t.chipTheme.copyWith(labelStyle: roboto(t.chipTheme.labelStyle)),
  );
}

// ── Fakes ──────────────────────────────────────────────────────────────────

class FakeAuth implements AuthService {
  final UserModel user;
  final List<String> resetEmails = [];
  FakeAuth(this.user);

  @override
  User? get currentUser => null;
  @override
  String get signInMethod => 'Email';
  @override
  Stream<User?> get authStateChanges => const Stream.empty();
  @override
  Future<UserModel?> signInWithEmail(String e, String p) async => user;
  @override
  Future<UserModel?> signUpWithEmail(String e, String n, String p) async => user;
  @override
  Future<UserModel?> signInWithGoogle() async => user;

  @override
  Future<void> sendPasswordResetEmail(String email) async => resetEmails.add(email);
  @override
  Future<void> signOut() async {}
  @override
  Future<UserModel?> getUserProfile(String uid) async => user;
  @override
  Future<UserModel?> ensureProfile(User u) async => user;
  @override
  Future<void> updateUserProfile(UserModel u) async {}
}

class FakeNotifs implements NotificationService {
  final scheduled = <String>[];
  final cancelled = <int>[];
  int cancelAllCalls = 0;
  bool permissionGranted = true;
  int permissionRequests = 0;
  DateTime? focusEndAt;

  @override
  Future<void> initNotifications() async {}
  @override
  Future<bool> ensurePermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> scheduleTaskReminder(int id, String t, DateTime time) async => scheduled.add(t);
  @override
  Future<void> scheduleFocusEnd(DateTime endsAt, String taskTitle) async => focusEndAt = endsAt;
  @override
  Future<void> cancelFocusEnd() async => focusEndAt = null;
  @override
  Future<void> cancelNotification(int id) async => cancelled.add(id);
  @override
  Future<void> cancelAllNotifications() async => cancelAllCalls++;
  @override
  Future<void> showInstantNotification(String t, String b) async {}
}

/// In-memory task repository that behaves like a live Firestore query: every
/// write re-emits the list. Set [failWrites] to simulate a Firestore error.
class FakeTaskRepo implements TaskRepository {
  final List<Task> store;
  final Duration latency;
  bool failWrites = false;
  bool failStream = false;
  int watchAllCalls = 0;
  int _n = 0;
  final _changes = StreamController<void>.broadcast();

  FakeTaskRepo([List<Task>? initial, this.latency = Duration.zero]) : store = initial ?? [];

  List<Task> _sorted() => List.of(store)..sort((a, b) => a.deadline.compareTo(b.deadline));

  void _check() {
    if (failWrites) throw Exception('simulated write failure');
  }

  void _changed() => _changes.add(null);

  @override
  Stream<List<Task>> watchAll(String userId) async* {
    watchAllCalls++;
    if (latency != Duration.zero) await Future<void>.delayed(latency);
    if (failStream) throw Exception('simulated query failure');
    yield _sorted();
    await for (final _ in _changes.stream) {
      yield _sorted();
    }
  }

  @override
  String newId() => 'id-${_n++}';

  @override
  Future<void> add(Task t) async {
    _check();
    store.add(t);
    _changed();
  }

  @override
  Future<void> addBatch(List<Task> ts) async {
    _check();
    store.addAll(ts);
    _changed();
  }

  /// Mirrors FirestoreTaskRepository.update(): a full-document overwrite.
  @override
  Future<void> update(Task t) async {
    _check();
    final i = store.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      store[i] = t;
    } else {
      store.add(t);
    }
    _changed();
  }

  @override
  Future<void> setCompletion(String taskId, {required bool completed, DateTime? completedAt}) async {
    _check();
    final i = store.indexWhere((t) => t.id == taskId);
    if (i < 0) return;
    store[i] = store[i].copyWith(isCompleted: completed, completedAt: completedAt, clearCompletedAt: completedAt == null);
    _changed();
  }

  @override
  Future<void> setElapsed(String taskId, int seconds) async {
    _check();
    final i = store.indexWhere((t) => t.id == taskId);
    if (i >= 0) store[i] = store[i].copyWith(elapsedSeconds: seconds);
    _changed();
  }

  @override
  Future<void> setSubtasks(String taskId, List<Subtask> subtasks) async {
    _check();
    final i = store.indexWhere((t) => t.id == taskId);
    if (i >= 0) store[i] = store[i].copyWith(subtasks: subtasks);
    _changed();
  }

  @override
  Future<void> delete(String id) async {
    _check();
    store.removeWhere((t) => t.id == id);
    _changed();
  }

  @override
  Future<List<String>> deleteSeries(String userId, String recurrenceId) async {
    _check();
    final ids = store.where((t) => t.userId == userId && t.recurrenceId == recurrenceId).map((t) => t.id).toList();
    store.removeWhere((t) => t.userId == userId && t.recurrenceId == recurrenceId);
    _changed();
    return ids;
  }
}

class FakeScheduleRepo implements ScheduleRepository {
  final List<ScheduleItem> store;
  int _n = 0;
  int watchDayCalls = 0;
  final _changes = StreamController<void>.broadcast();

  FakeScheduleRepo([List<ScheduleItem>? initial]) : store = initial ?? [];

  static bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<ScheduleItem> _inRange(DateTime start, DateTime end) =>
      (store.where((i) => !i.startTime.isBefore(start) && i.startTime.isBefore(end)).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime)));

  Stream<List<ScheduleItem>> _live(List<ScheduleItem> Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  Stream<List<ScheduleItem>> watchDay(String userId, DateTime date) {
    watchDayCalls++;
    final start = DateTime(date.year, date.month, date.day);
    return _live(() => _inRange(start, DateTime(date.year, date.month, date.day + 1)));
  }

  @override
  Stream<List<ScheduleItem>> watchRange(String userId, DateTime start, DateTime end) => _live(() => _inRange(start, end));

  @override
  Future<List<ScheduleItem>> fetchRange(String userId, DateTime start, DateTime end) async => _inRange(start, end);

  @override
  Future<List<ScheduleItem>> fetchDay(String userId, DateTime date) async =>
      _inRange(DateTime(date.year, date.month, date.day), DateTime(date.year, date.month, date.day + 1));

  @override
  String newId() => 's-${_n++}';

  @override
  Future<void> add(ScheduleItem i) async {
    store.add(i);
    _changes.add(null);
  }

  @override
  Future<void> addBatch(List<ScheduleItem> items) async {
    store.addAll(items);
    _changes.add(null);
  }

  @override
  Future<void> update(ScheduleItem i) async {
    final idx = store.indexWhere((x) => x.id == i.id);
    if (idx >= 0) store[idx] = i;
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    store.removeWhere((i) => i.id == id);
    _changes.add(null);
  }

  @override
  Future<void> deleteSeries(String userId, String recurrenceId) async {
    store.removeWhere((i) => i.userId == userId && i.recurrenceId == recurrenceId);
    _changes.add(null);
  }

  @override
  Future<void> replaceAiSuggestions(String userId, DateTime date, List<ScheduleItem> items) async {
    store.removeWhere((i) => i.isAISuggested && _same(i.startTime, date));
    store.addAll(items);
    _changes.add(null);
  }
}

// ── Sample data ────────────────────────────────────────────────────────────

final testUser = UserModel(
  uid: 'u1',
  email: 'student@example.com',
  name: 'Test Student',
  createdAt: DateTime(2026, 9, 1),
);

DateTime day(int offset, int h, [int m = 0]) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + offset, h, m);
}

DateTime today(int h, [int m = 0]) => day(0, h, m);

Task makeTask(
  String id, {
  String title = 'Task',
  DateTime? deadline,
  int priority = 2,
  int minutes = 60,
  bool completed = false,
  String? recurrenceId,
  String category = 'School',
}) =>
    Task(
      id: id,
      userId: 'u1',
      title: title == 'Task' ? 'Task $id' : title,
      deadline: deadline ?? day(3, 12),
      priority: priority,
      category: category,
      estimatedMinutes: minutes,
      isCompleted: completed,
      createdAt: DateTime(2026, 9, 1),
      recurrenceId: recurrenceId,
    );

List<Task> seedTasks() {
  final now = DateTime.now();
  return [
    Task(
      id: 't1',
      userId: 'u1',
      title: 'Research Paper',
      deadline: today(23, 30),
      priority: 3,
      category: 'School',
      estimatedMinutes: 120,
      createdAt: now,
      subtasks: [Subtask(id: 'a', title: 'Outline', isCompleted: true), Subtask(id: 'b', title: 'Draft')],
    ),
    Task(id: 't2', userId: 'u1', title: 'Flutter Project', deadline: day(1, 15), priority: 3, category: 'Work', estimatedMinutes: 180, createdAt: now),
    Task(id: 't3', userId: 'u1', title: 'Math Problem Set', deadline: day(2, 21, 30), priority: 2, category: 'Study', estimatedMinutes: 60, createdAt: now),
  ];
}

List<ScheduleItem> seedSchedule() => [
      ScheduleItem(id: 's1', userId: 'u1', title: 'CS101 Class', startTime: today(13, 30), endTime: today(15, 30), type: ScheduleTypes.class_, isFixed: true),
      // An AI-generated block that belongs to task t1.
      ScheduleItem(id: 's2', userId: 'u1', title: 'Research Paper', startTime: today(16), endTime: today(17), type: ScheduleTypes.task, taskId: 't1', isAISuggested: true),
    ];

// ── App harness ────────────────────────────────────────────────────────────

class Ctx {
  final AuthProvider auth;
  final TaskProvider tasks;
  final ScheduleProvider schedule;
  final FocusProvider focus;
  final ThemeProvider theme;
  final PreferencesProvider prefs;
  final FakeTaskRepo taskRepo;
  final FakeScheduleRepo scheduleRepo;
  final FakeNotifs notifs;
  final FakeAuth authService;
  Ctx(this.auth, this.tasks, this.schedule, this.focus, this.theme, this.prefs, this.taskRepo, this.scheduleRepo, this.notifs, this.authService);
}

Future<Ctx> makeCtx({
  List<Task>? tasks,
  List<ScheduleItem>? schedule,
  Duration latency = Duration.zero,
  bool failStream = false,
  AIService? ai,
}) async {
  SharedPreferences.setMockInitialValues({});
  final taskRepo = FakeTaskRepo(tasks ?? seedTasks(), latency)..failStream = failStream;
  final schRepo = FakeScheduleRepo(schedule ?? seedSchedule());
  final notifs = FakeNotifs();
  final authService = FakeAuth(testUser);
  final auth = AuthProvider(authService: authService, takeOnboarding: () async => null);
  await auth.signIn('x@y.z', 'pw123456');
  final tp = TaskProvider(taskRepository: taskRepo, notificationService: notifs)..attachUser('u1');
  final sp = ScheduleProvider(
    scheduleRepository: schRepo,
    aiService: ai ?? AIService(apiKey: 'test-key', client: _NoNetwork(), retryDelay: Duration.zero),
  );
  // Let the first snapshot arrive (microtasks only, so it also works under fake async).
  if (latency == Duration.zero) {
    for (var i = 0; i < 12; i++) {
      await Future<void>.value();
    }
  }
  final fp = FocusProvider(notifications: notifs)..updateTaskProvider(tp);
  return Ctx(auth, tp, sp, fp, ThemeProvider(), PreferencesProvider(), taskRepo, schRepo, notifs, authService);
}

/// A client that fails loudly if a test forgets to mock the AI request.
class _NoNetwork extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => throw StateError('unexpected network call: ${request.url}');
}

final navigatorKey = GlobalKey<NavigatorState>();

/// Providers + MaterialApp around [home].
Widget harness(Ctx c, Widget home) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: c.auth),
        ChangeNotifierProvider<PreferencesProvider>.value(value: c.prefs),
        ChangeNotifierProvider<TaskProvider>.value(value: c.tasks),
        ChangeNotifierProvider<ScheduleProvider>.value(value: c.schedule),
        ChangeNotifierProvider<FocusProvider>.value(value: c.focus),
        ChangeNotifierProvider<ThemeProvider>.value(value: c.theme),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: withRoboto(AppTheme.light(accentColor: AppColors.primary)),
        darkTheme: withRoboto(AppTheme.dark(accentColor: AppColors.primary)),
        home: home,
      ),
    );

/// Shows [screen] on top of an empty root route, like the real app pushes it,
/// so `Navigator.pop` after saving behaves as it does on a device.
Future<void> pumpScreen(WidgetTester tester, Ctx c, Widget screen, {int settleMs = 400}) async {
  await tester.pumpWidget(harness(c, const Scaffold(body: SizedBox.expand())));
  unawaited(navigatorKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => screen)));
  await settle(tester, settleMs);
}

void setDevice(WidgetTester tester, double w, double h, {double textScale = 1.0}) {
  tester.view.physicalSize = Size(w * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

/// Collects framework errors (RenderFlex overflow, assertion failures)
/// without failing the test, so a test can assert on them.
class ErrorSink {
  final List<String> errors = [];
  FlutterExceptionHandler? _old;
  void install() {
    _old = FlutterError.onError;
    addTearDown(restore);
    FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
  }

  void restore() => FlutterError.onError = _old;
}

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}
