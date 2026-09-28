import 'package:flutter/material.dart';

import '../models/recurrence.dart';
import '../models/schedule.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../repositories/schedule_repository.dart';
import '../repositories/impl/firestore_schedule_repository.dart';
import '../services/ai_service.dart';
import '../utils/app_logger.dart';

/// Thrown when a new/edited schedule item overlaps an existing fixed event.
class ScheduleConflictException implements Exception {
  final String message;
  ScheduleConflictException(this.message);
  @override
  String toString() => message;
}

class ScheduleProvider extends ChangeNotifier {
  static const _module = 'ScheduleProvider';

  final ScheduleRepository _repo;
  final AIService _aiService;

  ScheduleProvider({
    ScheduleRepository? scheduleRepository,
    AIService? aiService,
  })  : _repo = scheduleRepository ?? FirestoreScheduleRepository(),
        _aiService = aiService ?? AIService();

  bool _isLoading = false;
  bool _isGeneratingSchedule = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isGeneratingSchedule => _isGeneratingSchedule;
  bool get isAIConfigured => _aiService.isConfigured;
  String? get errorMessage => _errorMessage;

  // ── Streams ──────────────────────────────────────────────────────────────

  Stream<List<ScheduleItem>> getUserScheduleStream(
    String userId,
    DateTime date,
  ) =>
      _repo.watchDay(userId, date);

  // ── Conflict Check ───────────────────────────────────────────────────────

  Future<void> _assertNoFixedConflict(
    String userId,
    DateTime start,
    DateTime end, {
    String? excludeItemId,
  }) async {
    final existing = await _repo.fetchDay(userId, start);
    final candidate = ScheduleItem(
      id: 'candidate',
      userId: userId,
      title: '',
      startTime: start,
      endTime: end,
      type: ScheduleTypes.personal,
    );
    for (final item in existing) {
      if (item.id == excludeItemId) continue;
      if (candidate.overlapsWith(item)) {
        throw ScheduleConflictException(
          'This overlaps with "${item.title}" (${_fmtRange(item)}).',
        );
      }
    }
  }

  String _fmtRange(ScheduleItem item) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(item.startTime.hour)}:${two(item.startTime.minute)}-'
        '${two(item.endTime.hour)}:${two(item.endTime.minute)}';
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> addFixedEvent({
    required String userId,
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    required String type,
    RecurrenceRule recurrence = RecurrenceRule.none,
  }) async {
    if (!endTime.isAfter(startTime)) {
      throw ScheduleConflictException('End time must be after start time.');
    }

    final duration = endTime.difference(startTime);
    final startTimeOfDay = TimeOfDay.fromDateTime(startTime);
    final dates = recurrence.occurrencesFrom(startTime);

    final occurrenceStarts = dates.map((date) {
      return DateTime(
        date.year,
        date.month,
        date.day,
        startTimeOfDay.hour,
        startTimeOfDay.minute,
      );
    }).toList();

    // Validate conflicts before writing anything.
    for (final start in occurrenceStarts) {
      await _assertNoFixedConflict(userId, start, start.add(duration));
    }

    _begin();
    try {
      final seriesId = _repo.newId();
      final items = [
        for (var i = 0; i < occurrenceStarts.length; i++)
          ScheduleItem(
            id: i == 0 ? seriesId : _repo.newId(),
            userId: userId,
            title: title,
            startTime: occurrenceStarts[i],
            endTime: occurrenceStarts[i].add(duration),
            type: type,
            isFixed: true,
            recurrenceId: recurrence.isRecurring ? seriesId : null,
            recurrence: recurrence,
          ),
      ];

      if (items.length == 1) {
        await _repo.add(items.first);
      } else {
        await _repo.addBatch(items);
      }
      AppLogger.info(_module, 'addFixedEvent: ${items.length} occurrence(s)');
    } catch (e, st) {
      _setError('Could not save event. Please try again.', e, st);
      rethrow;
    } finally {
      _end();
    }
  }

  Future<void> deleteScheduleItem(String scheduleId) async {
    _begin();
    try {
      await _repo.delete(scheduleId);
      AppLogger.info(_module, 'deleteScheduleItem: $scheduleId');
    } catch (e, st) {
      _setError('Could not delete event. Please try again.', e, st);
      rethrow;
    } finally {
      _end();
    }
  }

  Future<void> deleteScheduleSeries(String recurrenceId) async {
    _begin();
    try {
      await _repo.deleteSeries(recurrenceId);
      AppLogger.info(_module, 'deleteScheduleSeries: $recurrenceId');
    } catch (e, st) {
      _setError('Could not delete event series. Please try again.', e, st);
      rethrow;
    } finally {
      _end();
    }
  }

  // ── AI (Future Development) ────────────────────────────────────────────────

  Future<List<ScheduleItem>> generateAISchedulePreview({
    required String userId,
    required List<Task> tasks,
    required DateTime scheduleDate,
    required UserModel user,
  }) async {
    _isGeneratingSchedule = true;
    notifyListeners();
    try {
      final allItems = await _repo.fetchDay(userId, scheduleDate);
      final fixedEvents = allItems.where((i) => i.isFixed).toList();
      return await _aiService.generateSchedule(
        userId: userId,
        tasks: tasks,
        scheduleDate: scheduleDate,
        fixedEvents: fixedEvents,
        user: user,
      );
    } finally {
      _isGeneratingSchedule = false;
      notifyListeners();
    }
  }

  Future<void> acceptGeneratedSchedule(
    String userId,
    DateTime scheduleDate,
    List<ScheduleItem> items,
  ) async {
    _begin();
    try {
      await _repo.clearFlexible(userId, scheduleDate);
      for (final item in items) {
        final withId = ScheduleItem(
          id: _repo.newId(),
          userId: item.userId,
          title: item.title,
          startTime: item.startTime,
          endTime: item.endTime,
          type: item.type,
          taskId: item.taskId,
          isAISuggested: true,
          isFixed: false,
          note: item.note,
        );
        await _repo.add(withId);
      }
    } catch (e, st) {
      _setError('Could not save schedule. Please try again.', e, st);
      rethrow;
    } finally {
      _end();
    }
  }

  // ── State helpers ─────────────────────────────────────────────────────────

  void _begin() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
  }

  void _end() {
    _isLoading = false;
    notifyListeners();
  }

  void _setError(String userMessage, Object error, StackTrace stackTrace) {
    _errorMessage = userMessage;
    AppLogger.error(_module, userMessage, error, stackTrace);
  }
}
