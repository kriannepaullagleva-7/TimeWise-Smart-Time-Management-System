import 'package:cloud_firestore/cloud_firestore.dart';

import 'recurrence.dart';

enum TaskStatus { completed, overdue, upcoming }

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
  final DateTime createdAt;
  final int? reminderMinutesBefore; // null = no reminder

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
    required this.createdAt,
    this.reminderMinutesBefore,
    this.recurrenceId,
    this.recurrence = RecurrenceRule.none,
  });

  bool get isRecurring => recurrenceId != null;

  TaskStatus get status {
    if (isCompleted) return TaskStatus.completed;
    if (deadline.isBefore(DateTime.now())) return TaskStatus.overdue;
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
    int? reminderMinutesBefore,
    bool clearReminder = false,
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
      createdAt: createdAt,
      reminderMinutesBefore: clearReminder
          ? null
          : (reminderMinutesBefore ?? this.reminderMinutesBefore),
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
      'createdAt': Timestamp.fromDate(createdAt),
      'reminderMinutesBefore': reminderMinutesBefore,
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
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reminderMinutesBefore: map['reminderMinutesBefore'],
      recurrenceId: map['recurrenceId'],
      recurrence: RecurrenceRule.fromMap(
        map['recurrence'] as Map<String, dynamic>?,
      ),
    );
  }
}
