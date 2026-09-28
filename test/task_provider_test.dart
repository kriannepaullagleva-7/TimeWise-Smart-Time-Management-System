import 'package:flutter_test/flutter_test.dart';
import 'package:timewise/models/task.dart';
import 'package:timewise/providers/task_provider.dart';
import 'package:timewise/repositories/task_repository.dart';
import 'package:timewise/services/notification_service.dart';

// ── Fake Repository ─────────────────────────────────────────────────────────

/// In-memory [TaskRepository] for use in widget / unit tests.
/// No Firebase connection required.
class FakeTaskRepository implements TaskRepository {
  final List<Task> _store = [];
  int _idCounter = 0;

  @override
  String newId() => 'fake-id-${_idCounter++}';

  @override
  Stream<List<Task>> watchAll(String userId) =>
      Stream.value(List.unmodifiable(_store));

  @override
  Stream<List<Task>> watchActive(String userId) => Stream.value(
        _store.where((t) => !t.isCompleted).toList(),
      );

  @override
  Future<void> add(Task task) async => _store.add(task);

  @override
  Future<void> addBatch(List<Task> tasks) async => _store.addAll(tasks);

  @override
  Future<void> update(Task task) async {
    final i = _store.indexWhere((t) => t.id == task.id);
    if (i >= 0) _store[i] = task;
  }

  @override
  Future<void> delete(String taskId) async =>
      _store.removeWhere((t) => t.id == taskId);

  @override
  Future<List<String>> deleteSeries(String recurrenceId) async {
    final toDelete =
        _store.where((t) => t.recurrenceId == recurrenceId).toList();
    final ids = toDelete.map((t) => t.id).toList();
    _store.removeWhere((t) => t.recurrenceId == recurrenceId);
    return ids;
  }

  /// Expose store for assertions.
  List<Task> get all => List.unmodifiable(_store);
}

// ── Fake Notification Service stub (no-op) ──────────────────────────────────

class FakeNotificationService implements NotificationService {
  final List<String> scheduled = [];
  final List<int> cancelled = [];

  @override
  Future<void> initNotifications() async {}

  @override
  Future<void> scheduleTaskReminder(int id, String taskTitle, DateTime time) async {
    scheduled.add('$id:$taskTitle');
  }

  @override
  Future<void> cancelNotification(int id) async => cancelled.add(id);

  @override
  Future<void> cancelAllNotifications() async {}

  @override
  Future<void> showInstantNotification(String title, String body) async {}
}

// ── Helper ───────────────────────────────────────────────────────────────────

Task _makeTask(String id, {bool completed = false, String? recurrenceId}) =>
    Task(
      id: id,
      userId: 'u-1',
      title: 'Task $id',
      deadline: DateTime(2026, 12, 31),
      priority: 2,
      category: 'Work',
      estimatedMinutes: 60,
      isCompleted: completed,
      createdAt: DateTime(2026, 1, 1),
      recurrenceId: recurrenceId,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late FakeTaskRepository repo;
  late FakeNotificationService notifications;
  late TaskProvider provider;

  setUp(() {
    repo = FakeTaskRepository();
    notifications = FakeNotificationService();
    provider = TaskProvider(
      taskRepository: repo,
      notificationService: notifications,
    );
  });

  group('TaskProvider.addTask', () {
    test('persists task to repository', () async {
      final task = _makeTask('t-1');
      await provider.addTask(task);
      expect(repo.all, contains(task));
    });

    test('isLoading is false after successful add', () async {
      await provider.addTask(_makeTask('t-1'));
      expect(provider.isLoading, false);
    });

    test('schedules reminder when reminderMinutesBefore is set', () async {
      final withReminder = Task(
        id: 't-r',
        userId: 'u-1',
        title: 'Remind me',
        deadline: DateTime.now().add(const Duration(hours: 2)),
        priority: 2,
        category: 'Work',
        estimatedMinutes: 30,
        createdAt: DateTime.now(),
        reminderMinutesBefore: 30,
      );
      await provider.addTask(withReminder);
      expect(notifications.scheduled, isNotEmpty);
    });
  });

  group('TaskProvider.updateTask', () {
    test('updates existing task in repository', () async {
      final task = _makeTask('t-1');
      await provider.addTask(task);

      final updated = task.copyWith(isCompleted: true);
      await provider.updateTask(updated);
      expect(repo.all.first.isCompleted, true);
    });
  });

  group('TaskProvider.deleteTask', () {
    test('removes task from repository', () async {
      final task = _makeTask('t-1');
      await provider.addTask(task);
      await provider.deleteTask('t-1');
      expect(repo.all, isEmpty);
    });

    test('cancels notification on deletion', () async {
      await provider.addTask(_makeTask('t-1'));
      await provider.deleteTask('t-1');
      expect(notifications.cancelled, isNotEmpty);
    });
  });

  group('TaskProvider.deleteTaskSeries', () {
    test('removes all occurrences in a series', () async {
      for (final id in ['s-1', 's-2', 's-3']) {
        await provider.addTask(_makeTask(id, recurrenceId: 'series-A'));
      }
      await provider.addTask(_makeTask('other')); // not in series

      await provider.deleteTaskSeries('series-A');
      expect(repo.all.length, 1);
      expect(repo.all.first.id, 'other');
    });
  });

  group('TaskProvider.completeTask / reopenTask', () {
    test('completeTask marks task as completed', () async {
      final task = _makeTask('t-1');
      await provider.addTask(task);
      await provider.completeTask(task);
      expect(repo.all.first.isCompleted, true);
    });

    test('reopenTask marks task as incomplete', () async {
      final task = _makeTask('t-1', completed: true);
      await provider.addTask(task);
      await provider.reopenTask(task);
      expect(repo.all.first.isCompleted, false);
    });
  });

  group('TaskProvider state', () {
    test('errorMessage is null after a successful operation', () async {
      await provider.addTask(_makeTask('t-1'));
      expect(provider.errorMessage, isNull);
    });
  });
}
