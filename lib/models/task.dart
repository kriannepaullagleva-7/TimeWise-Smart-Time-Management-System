import 'package:cloud_firestore/cloud_firestore.dart';

import 'recurrence.dart';

enum TaskStatus { completed, overdue, inProgress, upcoming }

class Subtask {
  final String id;
  final String title;
  final bool isCompleted;

  Subtask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  Subtask copyWith({
    String? title,
    bool? isCompleted,
  }) {
    return Subtask(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
    };
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class Task {
  final String id;
  final String userId;
  final String title;
  final String description;
  final DateTime deadline;
  final int priority; // 1=Low, 2=Medium, 3=High
  final String category;
  final int estimatedMinutes;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final int? reminderMinutesBefore; // null = no reminder
  final List<Subtask> subtasks;
  final int elapsedSeconds;

  /// Id shared by every occurrence in a repeating series (the first
  /// occurrence's own id). Null for a one-off task.
  final String? recurrenceId;
  final RecurrenceRule recurrence;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    required this.deadline,
    required this.priority,
    required this.category,
    required this.estimatedMinutes,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    this.reminderMinutesBefore,
    this.subtasks = const [],
    this.elapsedSeconds = 0,
    this.recurrenceId,
    this.recurrence = RecurrenceRule.none,
  });

  bool get isRecurring => recurrenceId != null;

  TaskStatus get status {
    if (isCompleted) return TaskStatus.completed;
    if (deadline.isBefore(DateTime.now())) return TaskStatus.overdue;
    if (elapsedSeconds > 0) return TaskStatus.inProgress;
    return TaskStatus.upcoming;
  }

  DateTime? get reminderTime => reminderMinutesBefore == null
      ? null
      : deadline.subtract(Duration(minutes: reminderMinutesBefore!));

  static String priorityLabel(int priority) {
    switch (priority) {
      case 1:
        return 'Low';
      case 3:
        return 'High';
      case 2:
      default:
        return 'Medium';
    }
  }

  String get priorityText => priorityLabel(priority);

  Task copyWith({
    String? title,
    String? description,
    DateTime? deadline,
    int? priority,
    String? category,
    int? estimatedMinutes,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    int? reminderMinutesBefore,
    bool clearReminder = false,
    List<Subtask>? subtasks,
    int? elapsedSeconds,
  }) {
    return Task(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt,
      reminderMinutesBefore: clearReminder
          ? null
          : (reminderMinutesBefore ?? this.reminderMinutesBefore),
      subtasks: subtasks ?? this.subtasks,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      recurrenceId: recurrenceId,
      recurrence: recurrence,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'deadline': Timestamp.fromDate(deadline),
      'priority': priority,
      'category': category,
      'estimatedMinutes': estimatedMinutes,
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'reminderMinutesBefore': reminderMinutesBefore,
      'subtasks': subtasks.map((e) => e.toMap()).toList(),
      'elapsedSeconds': elapsedSeconds,
      'recurrenceId': recurrenceId,
      'recurrence': recurrence.toMap(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      deadline: (map['deadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
      priority: map['priority'] ?? 2,
      category: map['category'] ?? 'General',
      estimatedMinutes: map['estimatedMinutes'] ?? 60,
      isCompleted: map['isCompleted'] ?? false,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reminderMinutesBefore: map['reminderMinutesBefore'],
      subtasks: map['subtasks'] != null
          ? (map['subtasks'] as List)
              .map((e) => Subtask.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : [],
      elapsedSeconds: map['elapsedSeconds'] ?? 0,
      recurrenceId: map['recurrenceId'],
      recurrence: RecurrenceRule.fromMap(
        map['recurrence'] as Map<String, dynamic>?,
      ),
    );
  }
}
