import 'package:flutter/material.dart';

import '../models/recurrence.dart';
import '../models/schedule.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/firestore_service.dart';
import '../services/ai_service.dart';

/// Thrown when a new/edited schedule item overlaps an existing fixed event.
class ScheduleConflictException implements Exception {
  final String message;
  ScheduleConflictException(this.message);
  @override
  String toString() => message;
}

class ScheduleProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final AIService _aiService;

  ScheduleProvider({
    FirestoreService? firestoreService,
    AIService? aiService,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _aiService = aiService ?? AIService();

  bool _isLoading = false;
  bool _isGeneratingSchedule = false;

  bool get isLoading => _isLoading;
  bool get isGeneratingSchedule => _isGeneratingSchedule;
  bool get isAIConfigured => _aiService.isConfigured;

  Stream<List<ScheduleItem>> getUserScheduleStream(
    String userId,
    DateTime date,
  ) {
    return _firestoreService.getUserSchedule(userId, date);
  }

  Future<void> _assertNoFixedConflict(
    String userId,
    DateTime start,
    DateTime end, {
    String? excludeItemId,
  }) async {
    final existing = await _firestoreService.getUserScheduleOnce(userId, start);
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

  /// Adds a user-defined fixed activity (class, work, appointment, travel,
  /// personal commitment). Rejects it if it, or any occurrence when
  /// [recurrence] repeats it, overlaps anything already on the schedule.
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

    for (final start in occurrenceStarts) {
      await _assertNoFixedConflict(userId, start, start.add(duration));
    }

    _isLoading = true;
    notifyListeners();
    try {
      final seriesId = _firestoreService.newScheduleId();
      final items = [
        for (var i = 0; i < occurrenceStarts.length; i++)
          ScheduleItem(
            id: i == 0 ? seriesId : _firestoreService.newScheduleId(),
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
        await _firestoreService.addScheduleItem(items.first);
      } else {
        await _firestoreService.addScheduleItemsBatch(items);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteScheduleItem(String scheduleId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firestoreService.deleteScheduleItem(scheduleId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes every occurrence of the repeating series [recurrenceId]
  /// belongs to.
  Future<void> deleteScheduleSeries(String recurrenceId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firestoreService.deleteScheduleSeries(recurrenceId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Asks the AI for a plan without saving anything, so the caller can show
  /// a preview and let the user accept, edit, or regenerate it.
  Future<List<ScheduleItem>> generateAISchedulePreview({
    required String userId,
    required List<Task> tasks,
    required DateTime scheduleDate,
    required UserModel user,
  }) async {
    _isGeneratingSchedule = true;
    notifyListeners();

    try {
      final allItems = await _firestoreService.getUserScheduleOnce(userId, scheduleDate);
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

  /// Persists a (possibly user-edited) generated plan, replacing only the
  /// previous AI-suggested items for that day so fixed events are kept.
  Future<void> acceptGeneratedSchedule(
    String userId,
    DateTime scheduleDate,
    List<ScheduleItem> items,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firestoreService.clearFlexibleSchedule(userId, scheduleDate);
      for (final item in items) {
        final withId = ScheduleItem(
          id: _firestoreService.newScheduleId(),
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
        await _firestoreService.addScheduleItem(withId);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
