import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/task.dart';
import '../../utils/app_logger.dart';
import '../task_repository.dart';

/// Production [TaskRepository] backed by Cloud Firestore.
class FirestoreTaskRepository implements TaskRepository {
  static const _col = 'tasks';
  static const _module = 'FirestoreTaskRepository';

  /// With offline persistence on, a write future only completes when the
  /// server acknowledges it. Waiting longer than this would freeze forms on a
  /// bad connection, so the app carries on (the write stays queued locally
  /// and syncs when the connection returns).
  static const _ackTimeout = Duration(seconds: 5);

  final FirebaseFirestore _db;

  FirestoreTaskRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tasks => _db.collection(_col);

  @override
  String newId() => _tasks.doc().id;

  @override
  Stream<List<Task>> watchAll(String userId) {
    return _tasks
        .where('userId', isEqualTo: userId)
        .orderBy('deadline')
        .snapshots()
        .map((s) => _parseDocs(s.docs));
  }

  @override
  Future<void> add(Task task) =>
      _commit(_tasks.doc(task.id).set(task.toMap()), 'add task ${task.id}');

  @override
  Future<void> addBatch(List<Task> tasks) async {
    for (var i = 0; i < tasks.length; i += 450) {
      final batch = _db.batch();
      for (final t in tasks.skip(i).take(450)) {
        batch.set(_tasks.doc(t.id), t.toMap());
      }
      await _commit(batch.commit(), 'batch add ${tasks.length} tasks');
    }
  }

  @override
  Future<void> update(Task task) =>
      _commit(_tasks.doc(task.id).set(task.toMap()), 'update task ${task.id}');

  @override
  Future<void> setCompletion(String taskId, {required bool completed, DateTime? completedAt}) {
    return _commit(
      _tasks.doc(taskId).update({
        'isCompleted': completed,
        'completedAt': completedAt == null ? null : Timestamp.fromDate(completedAt),
      }),
      'set completion $taskId',
    );
  }

  @override
  Future<void> setElapsed(String taskId, int seconds) =>
      _commit(_tasks.doc(taskId).update({'elapsedSeconds': seconds}), 'set elapsed $taskId');

  @override
  Future<void> setSubtasks(String taskId, List<Subtask> subtasks) => _commit(
        _tasks.doc(taskId).update({'subtasks': subtasks.map((s) => s.toMap()).toList()}),
        'set subtasks $taskId',
      );

  @override
  Future<void> delete(String taskId) => _commit(_tasks.doc(taskId).delete(), 'delete task $taskId');

  @override
  Future<List<String>> deleteSeries(String userId, String recurrenceId) async {
    final query = await _tasks
        .where('userId', isEqualTo: userId)
        .where('recurrenceId', isEqualTo: recurrenceId)
        .get();
    final ids = query.docs.map((d) => d.id).toList();
    for (var i = 0; i < query.docs.length; i += 450) {
      final batch = _db.batch();
      for (final doc in query.docs.skip(i).take(450)) {
        batch.delete(doc.reference);
      }
      await _commit(batch.commit(), 'delete series $recurrenceId');
    }
    AppLogger.info(_module, 'Deleted series $recurrenceId (${ids.length} docs)');
    return ids;
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<void> _commit(Future<void> write, String what) async {
    try {
      await write.timeout(_ackTimeout);
    } on TimeoutException {
      AppLogger.warning(_module, '$what not acknowledged in ${_ackTimeout.inSeconds}s; queued offline');
      write.catchError((Object e, StackTrace st) {
        AppLogger.error(_module, 'late failure: $what', e, st);
      });
    }
  }

  List<Task> _parseDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final result = <Task>[];
    for (final doc in docs) {
      try {
        result.add(Task.fromMap(doc.data()));
      } catch (e) {
        // One corrupt document must never crash the whole stream.
        AppLogger.warning(_module, 'Skipped malformed task doc ${doc.id}', e);
      }
    }
    return result;
  }
}
