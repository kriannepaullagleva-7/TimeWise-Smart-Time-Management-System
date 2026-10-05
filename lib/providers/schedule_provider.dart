import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/recurrence.dart';
import '../models/schedule.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../repositories/impl/firestore_schedule_repository.dart';
import '../repositories/schedule_repository.dart';
import '../services/ai_service.dart';
import '../utils/app_exceptions.dart';
import '../utils/app_logger.dart';
import 'task_provider.dart';

export '../utils/app_exceptions.dart' show ScheduleConflictException;

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

  Stream<List<ScheduleItem>> watchDay(String userId, DateTime date) => _repo.watchDay(userId, date);

  Stream<List<ScheduleItem>> watchRange(String userId, DateTime start, DateTime end) =>
      _repo.watchRange(userId, start, end);

  // ── Conflict check ───────────────────────────────────────────────────────

  /// Throws when any of the [starts]/[duration] windows overlaps an item the
  /// user created. AI-suggested blocks do not count: the AI plans around the
  /// user's events, never the other way round. One range query covers the whole
  /// series instead of one query per occurrence.
  Future<void> _assertNoConflict(
    String userId,
    List<DateTime> starts,
    Duration duration, {
    String? excludeItemId,
  }) async {
    if (starts.isEmpty) return;
    final first = starts.reduce((a, b) => a.isBefore(b) ? a : b);
    final last = starts.reduce((a, b) => a.isAfter(b) ? a : b);
    final rangeStart = DateTime(first.year, first.month, first.day);
    final rangeEnd = DateTime(last.year, last.month, last.day + 1);

    final existing = (await _repo.fetchRange(userId, rangeStart, rangeEnd))
        .where((i) => !i.isAISuggested && i.id != excludeItemId)
        .toList();

    final isSeries = starts.length > 1;
    for (final start in starts) {
      final candidate = ScheduleItem(
        id: 'candidate',
        userId: userId,
        title: '',
        startTime: start,
        endTime: start.add(duration),
        type: ScheduleTypes.personal,
      );
      for (final item in existing) {
        if (candidate.overlapsWith(item)) {
          final when = isSeries ? ' on ${DateFormat('EEE, MMM d').format(start)}' : '';
          throw ScheduleConflictException(
            'This overlaps with "${item.title}" (${_fmtRange(item)})$when.',
          );
        }
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
    bool isFixed = true,
    String? note,
  }) async {
    if (!endTime.isAfter(startTime)) {
      throw const ScheduleConflictException('End time must be after start time.');
    }

    final duration = endTime.difference(startTime);
    final startTimeOfDay = TimeOfDay.fromDateTime(startTime);
    final dates = recurrence.occurrencesFrom(startTime);
    final occurrenceStarts = dates
        .map((d) => DateTime(d.year, d.month, d.day, startTimeOfDay.hour, startTimeOfDay.minute))
        .toList();

    // Validate conflicts before writing anything.
    await _assertNoConflict(userId, occurrenceStarts, duration);

    _begin();
    try {
      final seriesId = _repo.newId();
      final cleanNote = (note == null || note.trim().isEmpty) ? null : note.trim();
      final items = [
        for (var i = 0; i < occurrenceStarts.length; i++)
          ScheduleItem(
            id: i == 0 ? seriesId : _repo.newId(),
            userId: userId,
            title: title,
            startTime: occurrenceStarts[i],
            endTime: occurrenceStarts[i].add(duration),
            type: type,
            isFixed: isFixed,
            note: cleanNote,
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

  /// Edits ONE occurrence (the series link is kept).
  Future<void> updateEvent(
    ScheduleItem original, {
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    required String type,
    String? note,
    bool? isFixed,
  }) async {
    if (!endTime.isAfter(startTime)) {
      throw const ScheduleConflictException('End time must be after start time.');
    }
    await _assertNoConflict(
      original.userId,
      [startTime],
      endTime.difference(startTime),
      excludeItemId: original.id,
    );

    _begin();
    try {
      final cleanNote = (note == null || note.trim().isEmpty) ? null : note.trim();
      await _repo.update(
        original.copyWith(
          title: title,
          startTime: startTime,
          endTime: endTime,
          type: type,
          isFixed: isFixed,
          note: cleanNote,
          clearNote: cleanNote == null,
        ),
      );
    } catch (e, st) {
      _setError('Could not update event. Please try again.', e, st);
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

  Future<void> deleteScheduleSeries(String userId, String recurrenceId) async {
    _begin();
    try {
      await _repo.deleteSeries(userId, recurrenceId);
      AppLogger.info(_module, 'deleteScheduleSeries: $recurrenceId');
    } catch (e, st) {
      _setError('Could not delete event series. Please try again.', e, st);
      rethrow;
    } finally {
      _end();
    }
  }

  // ── AI schedule ────────────────────────────────────────────────────────────

  /// Asks the AI for a plan for [scheduleDate]. Only tasks worth planning that
  /// day are sent (see [TaskProvider.planningCandidates]).
  Future<List<ScheduleItem>> generateAISchedulePreview({
    required String userId,
    required List<Task> tasks,
    required DateTime scheduleDate,
    required UserModel user,
  }) async {
    if (!_aiService.isConfigured) {
      throw const AIConfigException(
        'The AI Schedule Assistant is not set up yet. Run the app with '
        '--dart-define=GEMINI_API_KEY=your_key to turn it on.',
      );
    }
    _isGeneratingSchedule = true;
    notifyListeners();
    try {
      final allItems = await _repo.fetchDay(userId, scheduleDate);
      final fixedEvents = allItems.where((i) => i.isFixed).toList();
      final candidates = TaskProvider.planningCandidates(tasks, scheduleDate);
      return await _aiService.generateSchedule(
        userId: userId,
        tasks: candidates,
        scheduleDate: scheduleDate,
        fixedEvents: fixedEvents,
        user: user,
      );
    } finally {
      _isGeneratingSchedule = false;
      notifyListeners();
    }
  }

  /// Saves the reviewed plan: replaces the day's earlier AI blocks with
  /// [items] in one atomic batch.
  Future<void> acceptGeneratedSchedule(
    String userId,
    DateTime scheduleDate,
    List<ScheduleItem> items,
  ) async {
    _begin();
    try {
      final withIds = [
        for (final item in items)
          ScheduleItem(
            id: _repo.newId(),
            userId: userId,
            title: item.title,
            startTime: item.startTime,
            endTime: item.endTime,
            type: item.type,
            taskId: item.taskId,
            isAISuggested: true,
            isFixed: false,
            note: item.note,
          ),
      ];
      await _repo.replaceAiSuggestions(userId, scheduleDate, withIds);
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
