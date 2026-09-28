import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/task.dart';
import '../../utils/app_logger.dart';
import '../task_repository.dart';

/// Production [TaskRepository] backed by Cloud Firestore.
class FirestoreTaskRepository implements TaskRepository {
  static const _col = 'tasks';
  static const _module = 'FirestoreTaskRepository';

  final FirebaseFirestore _db;

  FirestoreTaskRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  @override
  String newId() => _db.collection(_col).doc().id;

  @override
  Stream<List<Task>> watchAll(String userId) {
    return _db
        .collection(_col)
        .where('userId', isEqualTo: userId)
        .orderBy('deadline')
        .snapshots()
        .map((s) => _parseDocs(s.docs))
        .handleError((Object e, StackTrace st) {
      AppLogger.error(_module, 'watchAll stream error', e, st);
    });
  }

  @override
  Stream<List<Task>> watchActive(String userId) {
    return _db
        .collection(_col)
        .where('userId', isEqualTo: userId)
        .where('isCompleted', isEqualTo: false)
        .orderBy('deadline')
        .snapshots()
        .map((s) => _parseDocs(s.docs))
        .handleError((Object e, StackTrace st) {
      AppLogger.error(_module, 'watchActive stream error', e, st);
    });
  }

  @override
  Future<void> add(Task task) async {
    try {
      await _db.collection(_col).doc(task.id).set(task.toMap());
      AppLogger.info(_module, 'Added task ${task.id}');
    } catch (e, st) {
      AppLogger.error(_module, 'add failed', e, st);
      rethrow;
    }
  }

  @override
  Future<void> addBatch(List<Task> tasks) async {
    try {
      for (var i = 0; i < tasks.length; i += 450) {
        final chunk = tasks.skip(i).take(450);
        final batch = _db.batch();
        for (final t in chunk) {
          batch.set(_db.collection(_col).doc(t.id), t.toMap());
        }
        await batch.commit();
      }
      AppLogger.info(_module, 'Batch-added ${tasks.length} tasks');
    } catch (e, st) {
      AppLogger.error(_module, 'addBatch failed', e, st);
      rethrow;
    }
  }

  @override
  Future<void> update(Task task) async {
    try {
      await _db.collection(_col).doc(task.id).set(task.toMap());
      AppLogger.info(_module, 'Updated task ${task.id}');
    } catch (e, st) {
      AppLogger.error(_module, 'update failed', e, st);
      rethrow;
    }
  }

  @override
  Future<void> delete(String taskId) async {
    try {
      await _db.collection(_col).doc(taskId).delete();
      AppLogger.info(_module, 'Deleted task $taskId');
    } catch (e, st) {
      AppLogger.error(_module, 'delete failed', e, st);
      rethrow;
    }
  }

  @override
  Future<List<String>> deleteSeries(String recurrenceId) async {
    try {
      final query = await _db
          .collection(_col)
          .where('recurrenceId', isEqualTo: recurrenceId)
          .get();
      final ids = query.docs.map((d) => d.id).toList();
      for (var i = 0; i < query.docs.length; i += 450) {
        final chunk = query.docs.skip(i).take(450);
        final batch = _db.batch();
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      AppLogger.info(_module, 'Deleted series $recurrenceId (${ids.length} docs)');
      return ids;
    } catch (e, st) {
      AppLogger.error(_module, 'deleteSeries failed', e, st);
      rethrow;
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────

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
