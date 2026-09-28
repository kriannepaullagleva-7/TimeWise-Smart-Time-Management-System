import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/schedule.dart';
import '../../utils/app_logger.dart';
import '../schedule_repository.dart';

/// Production [ScheduleRepository] backed by Cloud Firestore.
class FirestoreScheduleRepository implements ScheduleRepository {
  static const _col = 'schedules';
  static const _module = 'FirestoreScheduleRepository';

  final FirebaseFirestore _db;

  FirestoreScheduleRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  @override
  String newId() => _db.collection(_col).doc().id;

  @override
  Stream<List<ScheduleItem>> watchDay(String userId, DateTime date) {
    final (start, end) = _dayBounds(date);
    return _db
        .collection(_col)
        .where('userId', isEqualTo: userId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThan: Timestamp.fromDate(end))
        .orderBy('startTime')
        .snapshots()
        .map((s) => _parseDocs(s.docs))
        .handleError((Object e, StackTrace st) {
      AppLogger.error(_module, 'watchDay stream error', e, st);
    });
  }

  @override
  Future<List<ScheduleItem>> fetchDay(String userId, DateTime date) async {
    final (start, end) = _dayBounds(date);
    try {
      final snapshot = await _db
          .collection(_col)
          .where('userId', isEqualTo: userId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('startTime', isLessThan: Timestamp.fromDate(end))
          .orderBy('startTime')
          .get();
      return _parseDocs(snapshot.docs);
    } catch (e, st) {
      AppLogger.error(_module, 'fetchDay failed', e, st);
      rethrow;
    }
  }

  @override
  Future<void> add(ScheduleItem item) async {
    try {
      await _db.collection(_col).doc(item.id).set(item.toMap());
      AppLogger.info(_module, 'Added schedule item ${item.id}');
    } catch (e, st) {
      AppLogger.error(_module, 'add failed', e, st);
      rethrow;
    }
  }

  @override
  Future<void> addBatch(List<ScheduleItem> items) async {
    try {
      for (var i = 0; i < items.length; i += 450) {
        final chunk = items.skip(i).take(450);
        final batch = _db.batch();
        for (final item in chunk) {
          batch.set(_db.collection(_col).doc(item.id), item.toMap());
        }
        await batch.commit();
      }
      AppLogger.info(_module, 'Batch-added ${items.length} schedule items');
    } catch (e, st) {
      AppLogger.error(_module, 'addBatch failed', e, st);
      rethrow;
    }
  }

  @override
  Future<void> update(ScheduleItem item) async {
    try {
      await _db.collection(_col).doc(item.id).set(item.toMap());
      AppLogger.info(_module, 'Updated schedule item ${item.id}');
    } catch (e, st) {
      AppLogger.error(_module, 'update failed', e, st);
      rethrow;
    }
  }

  @override
  Future<void> delete(String scheduleId) async {
    try {
      await _db.collection(_col).doc(scheduleId).delete();
      AppLogger.info(_module, 'Deleted schedule item $scheduleId');
    } catch (e, st) {
      AppLogger.error(_module, 'delete failed', e, st);
      rethrow;
    }
  }

  @override
  Future<void> deleteSeries(String recurrenceId) async {
    try {
      final query = await _db
          .collection(_col)
          .where('recurrenceId', isEqualTo: recurrenceId)
          .get();
      for (var i = 0; i < query.docs.length; i += 450) {
        final chunk = query.docs.skip(i).take(450);
        final batch = _db.batch();
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      AppLogger.info(_module, 'Deleted schedule series $recurrenceId');
    } catch (e, st) {
      AppLogger.error(_module, 'deleteSeries failed', e, st);
      rethrow;
    }
  }

  @override
  Future<void> clearFlexible(String userId, DateTime date) async {
    final (start, end) = _dayBounds(date);
    try {
      final query = await _db
          .collection(_col)
          .where('userId', isEqualTo: userId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('startTime', isLessThan: Timestamp.fromDate(end))
          .where('isFixed', isEqualTo: false)
          .get();
      for (final doc in query.docs) {
        await doc.reference.delete();
      }
      AppLogger.info(_module, 'Cleared flexible schedule for $date');
    } catch (e, st) {
      AppLogger.error(_module, 'clearFlexible failed', e, st);
      rethrow;
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  (DateTime, DateTime) _dayBounds(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    return (start, start.add(const Duration(days: 1)));
  }

  List<ScheduleItem> _parseDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final result = <ScheduleItem>[];
    for (final doc in docs) {
      try {
        result.add(ScheduleItem.fromMap(doc.data()));
      } catch (e) {
        AppLogger.warning(
          _module,
          'Skipped malformed schedule doc ${doc.id}',
          e,
        );
      }
    }
    return result;
  }
}
