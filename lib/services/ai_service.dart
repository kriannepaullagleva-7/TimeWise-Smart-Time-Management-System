import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/schedule.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../utils/app_exceptions.dart';
import '../utils/app_logger.dart';

export '../utils/app_exceptions.dart' show AIConfigException, AIServiceException;

/// Builds a one-day plan with the Google Gemini API.
///
/// The key is supplied at build time (never stored in source or bundled as an
/// asset):  `flutter run --dart-define=GEMINI_API_KEY=...`  or
/// `--dart-define-from-file=dart_defines.json`.
class AIService {
  static const String _envKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _envModel = String.fromEnvironment('GEMINI_MODEL');
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  /// Models tried in order.
  static const List<String> defaultModels = ['gemini-3.5-flash-lite', 'gemini-3.5-flash', 'gemini-2.5-flash'];

  static const _module = 'AIService';

  /// Pseudo status codes for failures that never reached the server.
  static const int _offline = -1;
  static const int _timedOut = 408;

  final http.Client _client;
  final String _apiKey;
  final List<String> _models;
  final Duration timeout;
  final Duration retryDelay;

  AIService({
    http.Client? client,
    String? apiKey,
    List<String>? models,
    this.timeout = const Duration(seconds: 25),
    this.retryDelay = const Duration(seconds: 2),
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey ?? _envKey,
        _models = models ?? (_envModel.isNotEmpty ? [_envModel, ...defaultModels] : defaultModels);

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<ScheduleItem>> generateSchedule({
    required String userId,
    required List<Task> tasks,
    required DateTime scheduleDate,
    required List<ScheduleItem> fixedEvents,
    required UserModel user,
    DateTime? now,
  }) async {
    if (!isConfigured) {
      throw const AIConfigException(
        'The AI Schedule Assistant is not set up yet. Run the app with '
        '--dart-define=GEMINI_API_KEY=your_key to turn it on.',
      );
    }

    final pendingTasks = tasks.where((t) => !t.isCompleted).toList();
    if (pendingTasks.isEmpty) return [];

    // Planning today: nothing may start in the past.
    final reference = now ?? DateTime.now();
    int? notBefore;
    if (_sameDay(reference, scheduleDate)) {
      notBefore = ((reference.hour * 60 + reference.minute + 4) ~/ 5) * 5;
      if (user.sleepMinutes > user.wakeMinutes && notBefore >= user.sleepMinutes) {
        throw const AIServiceException(
          "It is already past your sleep time today. Plan tomorrow instead.",
        );
      }
    }

    final prompt = buildPrompt(
      tasks: pendingTasks,
      date: scheduleDate,
      fixedEvents: fixedEvents,
      user: user,
      notBeforeMinutes: notBefore,
    );

    final text = await _requestPlanText(prompt);
    final parsed = parseResponse(
      userId: userId,
      response: text,
      scheduleDate: scheduleDate,
      tasks: pendingTasks,
      user: user,
      notBeforeMinutes: notBefore,
    );
    return resolveConflicts(parsed, fixedEvents);
  }

  // ── HTTP ─────────────────────────────────────────────────────────────────

  Future<String> _requestPlanText(String prompt) async {
    AIServiceException? lastError;

    for (final model in _models) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          return await _callModel(model, prompt);
        } on AIServiceException catch (e) {
          lastError = e;
          final status = e.statusCode;
          AppLogger.warning(_module, 'model $model attempt ${attempt + 1} failed ($status)');
          if (status == _offline || status == 401 || status == 403) rethrow; // other models would fail too
          final transient = status == 429 || status == 500 || status == 503;
          if (transient && attempt == 0) {
            await Future<void>.delayed(retryDelay);
            continue;
          }
          break; // not found / bad request / still failing: try the next model
        }
      }
    }
    throw lastError ??
        const AIServiceException('The AI service is not available right now. Please try again later.');
  }

  Future<String> _callModel(String model, String prompt) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/$model:generateContent'),
            headers: {'Content-Type': 'application/json', 'x-goog-api-key': _apiKey},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.4,
                'maxOutputTokens': 2048,
                ..._thinkingConfig(model),
              },
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AIServiceException('The AI took too long to answer. Please try again.', statusCode: _timedOut);
    } on SocketException {
      throw const AIServiceException('No internet connection. Check your network and try again.', statusCode: _offline);
    } on http.ClientException {
      throw const AIServiceException('No internet connection. Check your network and try again.', statusCode: _offline);
    }

    if (response.statusCode != 200) {
      throw AIServiceException(_messageForStatus(response.statusCode), statusCode: response.statusCode);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const AIServiceException('The AI sent a reply the app could not read. Please try again.');
    }
    final text = _extractText(decoded);
    if (text.trim().isEmpty) {
      throw const AIServiceException('The AI did not return a plan. Please try again.');
    }
    return text;
  }

  /// Gemini 3.x and 2.5 models "think" before answering and count those
  /// tokens against the output limit, which truncated plans in testing.
  Map<String, Object> _thinkingConfig(String model) {
    if (model.contains('3.5-flash-lite')) return {};
    if (model.startsWith('gemini-3')) {
      return {
        'thinkingConfig': {'thinkingLevel': 'minimal'},
      };
    }
    if (model.startsWith('gemini-2.5')) {
      return {
        'thinkingConfig': {'thinkingBudget': 0},
      };
    }
    return {};
  }

  String _extractText(Object? decoded) {
    if (decoded is! Map) return '';
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';
    final first = candidates.first;
    if (first is! Map) return '';
    final content = first['content'];
    if (content is! Map) return '';
    final parts = content['parts'];
    if (parts is! List) return '';
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['text'] is String) buffer.writeln(part['text'] as String);
    }
    return buffer.toString();
  }

  String _messageForStatus(int status) {
    switch (status) {
      case 400:
        return 'The AI could not understand the request. Please try again.';
      case 401:
      case 403:
        return 'The AI key was rejected. Check the Gemini API key used to build the app.';
      case 404:
        return 'The AI model is no longer available. The app needs an update.';
      case 429:
        return 'The AI is busy or the free quota is used up. Please try again in a minute.';
      default:
        if (status >= 500) {
          return 'The AI service is busy right now. Please try again in a moment.';
        }
        return 'The AI request failed. Please try again.';
    }
  }

  // ── Prompt ───────────────────────────────────────────────────────────────

  String buildPrompt({
    required List<Task> tasks,
    required DateTime date,
    required List<ScheduleItem> fixedEvents,
    required UserModel user,
    int? notBeforeMinutes,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('You are a time-management assistant building one realistic day plan.');
    buffer.writeln('Date: ${date.toString().split(' ')[0]}');
    buffer.writeln('User wakes at ${user.wakeTime} and sleeps at ${user.sleepTime}.');
    buffer.writeln('Never schedule anything before wake time or after sleep time.');
    if (notBeforeMinutes != null) {
      buffer.writeln('The current time is ${_hhmm(notBeforeMinutes)}. Do not schedule anything that starts before ${_hhmm(notBeforeMinutes)}.');
    }
    final style = _styleHints(user);
    if (style.isNotEmpty) buffer.writeln(style);
    buffer.writeln();

    buffer.writeln('Fixed commitments already on the calendar (do NOT overlap these):');
    if (fixedEvents.isEmpty) {
      buffer.writeln('(none)');
    } else {
      for (final event in fixedEvents) {
        buffer.writeln('- ${event.type}: ${_clean(event.title)} ${_fmt(event.startTime)}-${_fmt(event.endTime)}');
      }
    }
    buffer.writeln();

    buffer.writeln('Tasks to fit into the remaining free time:');
    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      buffer.writeln(
        '[T${i + 1}] ${_clean(t.title)} | priority=${t.priorityText} | '
        'duration=${t.estimatedMinutes}min | deadline=${t.deadline} | '
        'category=${_clean(t.category)}',
      );
    }
    buffer.writeln();

    buffer.writeln('Rules:');
    buffer.writeln('1. Do not overlap the fixed commitments listed above.');
    buffer.writeln('2. Prioritize high-priority tasks and tasks with closer deadlines.');
    buffer.writeln('3. If a task duration is over 90 minutes, you may split it into two blocks with a break between them. Never schedule more total time for a task than its duration.');
    buffer.writeln('4. Insert short breaks (10-15 min) between work blocks longer than 45 minutes.');
    buffer.writeln('5. Include a lunch/dinner meal break if the day spans typical meal times.');
    buffer.writeln('6. Do not schedule tasks that cannot fit before their deadline; skip them instead. A task whose deadline has already passed should be scheduled as early as possible.');
    buffer.writeln('7. Only use time between wake time and sleep time, and never inside a fixed commitment.');
    buffer.writeln();

    buffer.writeln('Respond with ONLY one line per scheduled item, no extra commentary, using exactly this format:');
    buffer.writeln('TYPE|REF_OR_TITLE|HH:mm|HH:mm|short reason');
    buffer.writeln('Where TYPE is one of: task, break, meal, exercise, personal.');
    buffer.writeln('For TYPE=task, REF_OR_TITLE must be the [T#] reference (e.g. T1). For other types, use a short title.');
    buffer.writeln('Example: task|T1|09:00|10:00|High priority, due soon');

    return buffer.toString();
  }

  String _styleHints(UserModel user) {
    final hints = <String>[];
    final style = user.onboarding['scheduleStyle'];
    final help = user.onboarding['aiHelp'];
    if (style != null && style.isNotEmpty) hints.add('Schedule style: $style.');
    if (help != null && help.isNotEmpty) hints.add('How much planning help the user wants: $help.');
    return hints.join(' ');
  }

  /// Task titles come from the user; keep them from breaking the line format.
  String _clean(String s) => s.replaceAll(RegExp(r'[|\r\n]+'), ' ').trim();

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _hhmm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // ── Parsing and validation ───────────────────────────────────────────────

  /// Turns the model's lines into schedule items and discards anything that
  /// breaks the rules the prompt asked for: unknown task references, items
  /// outside the user's wake/sleep window, blocks that end after the task's
  /// deadline, and blocks beyond the task's estimated duration.
  List<ScheduleItem> parseResponse({
    required String userId,
    required String response,
    required DateTime scheduleDate,
    required List<Task> tasks,
    required UserModel user,
    int? notBeforeMinutes,
  }) {
    const validTypes = {
      'task',
      ScheduleTypes.breakTime,
      ScheduleTypes.meal,
      ScheduleTypes.exercise,
      ScheduleTypes.personal,
    };

    final dayStart = DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day);
    final windowStart = _atMinutes(
      scheduleDate,
      notBeforeMinutes == null ? user.wakeMinutes : (notBeforeMinutes > user.wakeMinutes ? notBeforeMinutes : user.wakeMinutes),
    );
    final windowEnd = _atMinutes(scheduleDate, user.sleepMinutes);
    final hasWindow = windowEnd.isAfter(windowStart);

    final scheduledMinutes = <String, int>{};
    final items = <ScheduleItem>[];

    for (final rawLine in response.split('\n')) {
      final line = rawLine.replaceAll('`', '').replaceFirst(RegExp(r'^\s*[-*•]\s*'), '').trim();
      if (!line.contains('|')) continue;
      final parts = line.split('|').map((p) => p.trim()).toList();
      if (parts.length < 4) continue;

      final type = parts[0].toLowerCase();
      if (!validTypes.contains(type)) continue;

      final startTime = _parseTime(parts[2], scheduleDate);
      final endTime = _parseTime(parts[3], scheduleDate);
      if (startTime == null || endTime == null) continue;
      if (!endTime.isAfter(startTime)) continue;
      if (hasWindow && (startTime.isBefore(windowStart) || endTime.isAfter(windowEnd))) continue;

      final note = parts.length > 4 && parts[4].isNotEmpty ? parts.sublist(4).join(' | ') : null;

      var title = parts[1];
      String? taskId;
      if (type == 'task') {
        final match = RegExp(r'^T?(\d+)$', caseSensitive: false).firstMatch(parts[1].replaceAll(RegExp(r'[\[\]\s]'), ''));
        if (match == null) continue;
        final index = int.parse(match.group(1)!) - 1;
        if (index < 0 || index >= tasks.length) continue;
        final task = tasks[index];
        // A block may not finish after the deadline. Tasks that are already
        // overdue (deadline before this day) are planned as early as possible.
        if (task.deadline.isAfter(dayStart) && endTime.isAfter(task.deadline)) continue;
        final minutes = endTime.difference(startTime).inMinutes;
        final total = (scheduledMinutes[task.id] ?? 0) + minutes;
        if (total > task.estimatedMinutes + 15) continue; // more time than the task needs
        scheduledMinutes[task.id] = total;
        taskId = task.id;
        title = task.title;
      }
      if (title.isEmpty) continue;

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

  DateTime _atMinutes(DateTime day, int minutes) =>
      DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

  DateTime? _parseTime(String timeString, DateTime baseDate) {
    final parts = timeString.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
  }

  /// Drops any AI-suggested item that overlaps a fixed commitment or an
  /// earlier AI-suggested item, guaranteeing a conflict-free plan even if
  /// the model's own output does not follow the rules perfectly.
  List<ScheduleItem> resolveConflicts(List<ScheduleItem> suggested, List<ScheduleItem> fixedEvents) {
    final accepted = <ScheduleItem>[];
    for (final item in suggested) {
      final conflictsWithFixed = fixedEvents.any(item.overlapsWith);
      final conflictsWithAccepted = accepted.any(item.overlapsWith);
      if (!conflictsWithFixed && !conflictsWithAccepted) accepted.add(item);
    }
    return accepted;
  }
}
