import 'package:cloud_firestore/cloud_firestore.dart';

import 'recurrence.dart';

/// Prefix of the synthetic id given to a task shown on the Calendar. Such a
/// row is the task itself (not a schedule document) and must be deleted as a
/// task, never as a schedule item.
const String kTaskRowPrefix = 'task:';

/// Fixed activity types: created by the user and never overwritten by the
/// AI scheduler (class, work, appointment, travel).
/// Flexible types: placed by the AI or the user into free time
/// (task, break, meal, exercise, personal).
class ScheduleTypes {
  static const class_ = 'class';
  static const work = 'work';
  static const appointment = 'appointment';
  static const travel = 'travel';
  static const task = 'task';
  static const breakTime = 'break';
  static const meal = 'meal';
  static const sleep = 'sleep';
  static const exercise = 'exercise';
  static const personal = 'personal';

  static const fixedTypes = [class_, work, appointment, travel, sleep];

  /// Types the user can pick when creating an event.
  static const selectable = [class_, work, appointment, travel, exercise, personal];

  static String label(String type) {
    switch (type) {
      case class_:
        return 'Class';
      case breakTime:
        return 'Break';
      default:
        return type.isEmpty ? '' : type[0].toUpperCase() + type.substring(1);
    }
  }
}

class ScheduleItem {
  final String id;
  final String userId;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String type;
  final String? taskId;
  final bool isAISuggested;
  final bool isFixed;
  final String? note;

  /// Id shared by every occurrence in a repeating series (the first
  /// occurrence's own id). Null for a one-off event.
  final String? recurrenceId;
  final RecurrenceRule recurrence;

  ScheduleItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.type,
    this.taskId,
    this.isAISuggested = false,
    this.isFixed = false,
    this.note,
    this.recurrenceId,
    this.recurrence = RecurrenceRule.none,
  });

  bool get isRecurring => recurrenceId != null;

  /// True for a Calendar row that stands for a task due on that day.
  bool get isTaskRow => id.startsWith(kTaskRowPrefix);

  Duration get duration => endTime.difference(startTime);

  bool overlapsWith(ScheduleItem other) {
    return startTime.isBefore(other.endTime) && other.startTime.isBefore(endTime);
  }

  ScheduleItem copyWith({
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? type,
    String? note,
    bool? isFixed,
    bool clearNote = false,
  }) {
    return ScheduleItem(
      id: id,
      userId: userId,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      taskId: taskId,
      isAISuggested: isAISuggested,
      isFixed: isFixed ?? this.isFixed,
      note: clearNote ? null : (note ?? this.note),
      recurrenceId: recurrenceId,
      recurrence: recurrence,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'type': type,
      'taskId': taskId,
      'isAISuggested': isAISuggested,
      'isFixed': isFixed,
      'note': note,
      'recurrenceId': recurrenceId,
      'recurrence': recurrence.toMap(),
    };
  }

  factory ScheduleItem.fromMap(Map<String, dynamic> map) {
    return ScheduleItem(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      startTime: (map['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (map['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: map['type'] ?? 'task',
      taskId: map['taskId'],
      isAISuggested: map['isAISuggested'] ?? false,
      isFixed: map['isFixed'] ?? ScheduleTypes.fixedTypes.contains(map['type']),
      note: map['note'],
      recurrenceId: map['recurrenceId'],
      recurrence: RecurrenceRule.fromMap(
        map['recurrence'] as Map<String, dynamic>?,
      ),
    );
  }
}
