import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/schedule.dart';
import '../../utils/app_logger.dart';
import '../schedule_repository.dart';

/// Production [ScheduleRepository] backed by Cloud Firestore.
class FirestoreScheduleRepository implements ScheduleRepository {
  static const _col = 'schedules';
  static const _module = 'FirestoreScheduleRepository';
  static const _ackTimeout = Duration(seconds: 5);

  final FirebaseFirestore _db;

  FirestoreScheduleRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _items => _db.collection(_col);

  @override
  String newId() => _items.doc().id;

  Query<Map<String, dynamic>> _range(String userId, DateTime start, DateTime end) {
    return _items
        .where('userId', isEqualTo: userId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThan: Timestamp.fromDate(end))
        .orderBy('startTime');
  }

  @override
  Stream<List<ScheduleItem>> watchDay(String userId, DateTime date) {
    final (start, end) = _dayBounds(date);
    return watchRange(userId, start, end);
  }

  @override
  Stream<List<ScheduleItem>> watchRange(String userId, DateTime start, DateTime end) {
    return _range(userId, start, end).snapshots().map((s) => _parseDocs(s.docs));
  }

  @override
  Future<List<ScheduleItem>> fetchRange(String userId, DateTime start, DateTime end) async {
    final snapshot = await _range(userId, start, end).get();
    return _parseDocs(snapshot.docs);
  }

  @override
  Future<List<ScheduleItem>> fetchDay(String userId, DateTime date) {
    final (start, end) = _dayBounds(date);
    return fetchRange(userId, start, end);
  }

  @override
  Future<void> add(ScheduleItem item) =>
      _commit(_items.doc(item.id).set(item.toMap()), 'add schedule item ${item.id}');

  @override
  Future<void> addBatch(List<ScheduleItem> items) async {
    for (var i = 0; i < items.length; i += 450) {
      final batch = _db.batch();
      for (final item in items.skip(i).take(450)) {
        batch.set(_items.doc(item.id), item.toMap());
      }
      await _commit(batch.commit(), 'batch add ${items.length} schedule items');
    }
  }

  @override
  Future<void> update(ScheduleItem item) =>
      _commit(_items.doc(item.id).set(item.toMap()), 'update schedule item ${item.id}');

  @override
  Future<void> delete(String scheduleId) =>
      _commit(_items.doc(scheduleId).delete(), 'delete schedule item $scheduleId');

  @override
  Future<void> deleteSeries(String userId, String recurrenceId) async {
    final query = await _items
        .where('userId', isEqualTo: userId)
        .where('recurrenceId', isEqualTo: recurrenceId)
        .get();
    for (var i = 0; i < query.docs.length; i += 450) {
      final batch = _db.batch();
      for (final doc in query.docs.skip(i).take(450)) {
        batch.delete(doc.reference);
      }
      await _commit(batch.commit(), 'delete schedule series $recurrenceId');
    }
  }

  @override
  Future<void> replaceAiSuggestions(String userId, DateTime date, List<ScheduleItem> items) async {
    final (start, end) = _dayBounds(date);
    final existing = await _range(userId, start, end).get();
    final batch = _db.batch();
    for (final doc in existing.docs) {
      if (doc.data()['isAISuggested'] == true) batch.delete(doc.reference);
    }
    for (final item in items) {
      batch.set(_items.doc(item.id), item.toMap());
    }
    await _commit(batch.commit(), 'replace AI plan for $date');
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

  (DateTime, DateTime) _dayBounds(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    return (start, DateTime(date.year, date.month, date.day + 1));
  }

  List<ScheduleItem> _parseDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final result = <ScheduleItem>[];
    for (final doc in docs) {
      try {
        result.add(ScheduleItem.fromMap(doc.data()));
      } catch (e) {
        AppLogger.warning(_module, 'Skipped malformed schedule doc ${doc.id}', e);
      }
    }
    return result;
  }
}
