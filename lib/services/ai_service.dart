import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/schedule.dart';
import '../models/task.dart';
import '../models/user.dart';

/// Thrown when the AI schedule assistant cannot run, e.g. because no API
/// key was supplied at build time.
class AIConfigException implements Exception {
  final String message;
  AIConfigException(this.message);
  @override
  String toString() => message;
}

class AIService {
  // The key is never hardcoded in source. Provide it at build/run time with:
  //   flutter run --dart-define=GEMINI_API_KEY=your_key_here
  // See README.md for details. This keeps the key out of source control,
  // though for full protection in production a server-side proxy (e.g. a
  // Cloud Function) that holds the key is recommended instead of shipping
  // it inside the compiled app.
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<ScheduleItem>> generateSchedule({
    required String userId,
    required List<Task> tasks,
    required DateTime scheduleDate,
    required List<ScheduleItem> fixedEvents,
    required UserModel user,
  }) async {
    if (!isConfigured) {
      throw AIConfigException(
        'AI Schedule Assistant is not configured. Run the app with '
        '--dart-define=GEMINI_API_KEY=your_key to enable it.',
      );
    }

    final pendingTasks = tasks.where((t) => !t.isCompleted).toList();
    if (pendingTasks.isEmpty) {
      return [];
    }

    final prompt = _buildPrompt(
      tasks: pendingTasks,
      date: scheduleDate,
      fixedEvents: fixedEvents,
      user: user,
    );

    final response = await http
        .post(
          Uri.parse('$_apiUrl?key=$_apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 1500},
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
        'AI request failed (${response.statusCode}): ${response.body}',
      );
    }

    final result = jsonDecode(response.body);
    final candidates = result['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('AI returned no schedule suggestions.');
    }
    final text = candidates[0]['content']['parts'][0]['text'] as String;

    final parsed = _parseResponse(
      userId: userId,
      response: text,
      scheduleDate: scheduleDate,
      tasks: pendingTasks,
    );

    return _resolveConflicts(parsed, fixedEvents);
  }

  String _buildPrompt({
    required List<Task> tasks,
    required DateTime date,
    required List<ScheduleItem> fixedEvents,
    required UserModel user,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      'You are a time-management assistant building one realistic day plan.',
    );
    buffer.writeln('Date: ${date.toString().split(' ')[0]}');
    buffer.writeln('User wakes at ${user.wakeTime} and sleeps at ${user.sleepTime}.');
    buffer.writeln(
      'Never schedule anything before wake time or after sleep time.',
    );
    buffer.writeln();

    buffer.writeln('Fixed commitments already on the calendar (do NOT overlap these):');
    if (fixedEvents.isEmpty) {
      buffer.writeln('(none)');
    } else {
      for (final event in fixedEvents) {
        buffer.writeln(
          '- ${event.type}: ${event.title} ${_fmt(event.startTime)}-${_fmt(event.endTime)}',
        );
      }
    }
    buffer.writeln();

    buffer.writeln('Tasks to fit into the remaining free time:');
    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      buffer.writeln(
        '[T${i + 1}] ${t.title} | priority=${t.priorityText} | '
        'duration=${t.estimatedMinutes}min | deadline=${t.deadline} | '
        'category=${t.category}',
      );
    }
    buffer.writeln();

    buffer.writeln('Rules:');
    buffer.writeln('1. Do not overlap the fixed commitments listed above.');
    buffer.writeln('2. Prioritize high-priority tasks and tasks with closer deadlines.');
    buffer.writeln('3. If a task duration is over 90 minutes, you may split it into two blocks with a break between them.');
    buffer.writeln('4. Insert short breaks (10-15 min) between work blocks longer than 45 minutes.');
    buffer.writeln('5. Include a lunch/dinner meal break if the day spans typical meal times.');
    buffer.writeln('6. Do not schedule tasks that cannot fit before their deadline; skip them instead.');
    buffer.writeln('7. Only use time between wake time and sleep time, and never inside a fixed commitment.');
    buffer.writeln();

    buffer.writeln('Respond with ONLY one line per scheduled item, no extra commentary, using exactly this format:');
    buffer.writeln('TYPE|REF_OR_TITLE|HH:mm|HH:mm|short reason');
    buffer.writeln('Where TYPE is one of: task, break, meal, exercise, personal.');
    buffer.writeln('For TYPE=task, REF_OR_TITLE must be the [T#] reference (e.g. T1). For other types, use a short title.');
    buffer.writeln('Example: task|T1|09:00|10:00|High priority, due soon');

    return buffer.toString();
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  List<ScheduleItem> _parseResponse({
    required String userId,
    required String response,
    required DateTime scheduleDate,
    required List<Task> tasks,
  }) {
    final items = <ScheduleItem>[];
    final lines = response.split('\n').where((l) => l.contains('|'));

    const validTypes = {
      'task',
      ScheduleTypes.breakTime,
      ScheduleTypes.meal,
      ScheduleTypes.exercise,
      ScheduleTypes.personal,
    };

    for (final line in lines) {
      final parts = line.split('|').map((p) => p.trim()).toList();
      if (parts.length < 4) continue;

      final type = parts[0].toLowerCase();
      if (!validTypes.contains(type)) continue;

      final startTime = _parseTime(parts[2], scheduleDate);
      final endTime = _parseTime(parts[3], scheduleDate);
      if (startTime == null || endTime == null) continue;
      if (!endTime.isAfter(startTime)) continue;

      final note = parts.length > 4 ? parts[4] : null;

      String title = parts[1];
      String? taskId;
      if (type == 'task') {
        final match = RegExp(r'^T(\d+)$').firstMatch(parts[1].toUpperCase());
        if (match == null) continue;
        final index = int.parse(match.group(1)!) - 1;
        if (index < 0 || index >= tasks.length) continue;
        taskId = tasks[index].id;
        title = tasks[index].title;
      }

      items.add(
        ScheduleItem(
          id: '', // assigned by the caller once the user accepts the plan
          userId: userId,
          title: title,
          startTime: startTime,
          endTime: endTime,
          type: type == 'task' ? ScheduleTypes.task : type,
          taskId: taskId,
          isAISuggested: true,
          isFixed: false,
          note: note,
        ),
      );
    }

    items.sort((a, b) => a.startTime.compareTo(b.startTime));
    return items;
  }

  DateTime? _parseTime(String timeString, DateTime baseDate) {
    final parts = timeString.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
  }

  /// Drops any AI-suggested item that overlaps a fixed commitment or an
  /// earlier AI-suggested item, guaranteeing a conflict-free plan even if
  /// the model's own output does not follow the rules perfectly.
  List<ScheduleItem> _resolveConflicts(
    List<ScheduleItem> suggested,
    List<ScheduleItem> fixedEvents,
  ) {
    final accepted = <ScheduleItem>[];
    for (final item in suggested) {
      final conflictsWithFixed = fixedEvents.any(item.overlapsWith);
      final conflictsWithAccepted = accepted.any(item.overlapsWith);
      if (!conflictsWithFixed && !conflictsWithAccepted) {
        accepted.add(item);
      }
    }
    return accepted;
  }
}
