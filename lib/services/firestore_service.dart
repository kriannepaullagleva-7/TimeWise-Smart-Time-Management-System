import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task.dart';
import '../models/schedule.dart';
import '../models/user.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String newTaskId() => _firestore.collection('tasks').doc().id;
  String newScheduleId() => _firestore.collection('schedules').doc().id;

  // ===== USER OPERATIONS =====
  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  Future<void> updateUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  // ===== TASK OPERATIONS =====
  Future<void> addTask(Task task) async {
    await _firestore.collection('tasks').doc(task.id).set(task.toMap());
  }

  Future<void> updateTask(Task task) async {
    await _firestore.collection('tasks').doc(task.id).set(task.toMap());
  }

  Future<void> deleteTask(String taskId) async {
    await _firestore.collection('tasks').doc(taskId).delete();
  }

  /// Writes every occurrence of a recurring task series in chunked batches
  /// (Firestore caps a single batch at 500 writes).
  Future<void> addTasksBatch(List<Task> tasks) async {
    for (var i = 0; i < tasks.length; i += 450) {
      final chunk = tasks.skip(i).take(450);
      final batch = _firestore.batch();
      for (final task in chunk) {
        batch.set(_firestore.collection('tasks').doc(task.id), task.toMap());
      }
      await batch.commit();
    }
  }

  /// Deletes every task sharing [recurrenceId] and returns the deleted ids
  /// so the caller can cancel their reminders.
  Future<List<String>> deleteTaskSeries(String recurrenceId) async {
    final query = await _firestore
        .collection('tasks')
        .where('recurrenceId', isEqualTo: recurrenceId)
        .get();

    final ids = query.docs.map((d) => d.id).toList();
    for (var i = 0; i < query.docs.length; i += 450) {
      final chunk = query.docs.skip(i).take(450);
      final batch = _firestore.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    return ids;
  }

  Stream<List<Task>> getUserTasks(String userId) {
    return _firestore
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .orderBy('deadline')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Task.fromMap(doc.data())).toList(),
        );
  }

  Stream<List<Task>> getActiveTasks(String userId) {
    return _firestore
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .where('isCompleted', isEqualTo: false)
        .orderBy('deadline')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Task.fromMap(doc.data())).toList(),
        );
  }

  // ===== SCHEDULE OPERATIONS =====
  Future<void> addScheduleItem(ScheduleItem item) async {
    await _firestore.collection('schedules').doc(item.id).set(item.toMap());
  }

  Future<void> updateScheduleItem(ScheduleItem item) async {
    await _firestore.collection('schedules').doc(item.id).set(item.toMap());
  }

  Future<void> deleteScheduleItem(String scheduleId) async {
    await _firestore.collection('schedules').doc(scheduleId).delete();
  }

  /// Writes every occurrence of a recurring event series in chunked batches
  /// (Firestore caps a single batch at 500 writes).
  Future<void> addScheduleItemsBatch(List<ScheduleItem> items) async {
    for (var i = 0; i < items.length; i += 450) {
      final chunk = items.skip(i).take(450);
      final batch = _firestore.batch();
      for (final item in chunk) {
        batch.set(_firestore.collection('schedules').doc(item.id), item.toMap());
      }
      await batch.commit();
    }
  }

  /// Deletes every schedule item sharing [recurrenceId].
  Future<void> deleteScheduleSeries(String recurrenceId) async {
    final query = await _firestore
        .collection('schedules')
        .where('recurrenceId', isEqualTo: recurrenceId)
        .get();

    for (var i = 0; i < query.docs.length; i += 450) {
      final chunk = query.docs.skip(i).take(450);
      final batch = _firestore.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Stream<List<ScheduleItem>> getUserSchedule(String userId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection('schedules')
        .where('userId', isEqualTo: userId)
        .where(
          'startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('startTime')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ScheduleItem.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<List<ScheduleItem>> getUserScheduleOnce(
    String userId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('schedules')
        .where('userId', isEqualTo: userId)
        .where(
          'startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('startTime')
        .get();

    return snapshot.docs.map((doc) => ScheduleItem.fromMap(doc.data())).toList();
  }

  /// Removes only the non-fixed items (previous AI suggestions / task
  /// blocks) scheduled for [date], preserving user-created fixed events
  /// such as classes, work and appointments.
  Future<void> clearFlexibleSchedule(String userId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final query = await _firestore
        .collection('schedules')
        .where('userId', isEqualTo: userId)
        .where(
          'startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
        .where('isFixed', isEqualTo: false)
        .get();

    for (var doc in query.docs) {
      await doc.reference.delete();
    }
  }
}
