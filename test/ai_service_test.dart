// AIService tests with a mocked HTTP client: no network and no API key needed.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:timewise/models/schedule.dart';
import 'package:timewise/models/task.dart';
import 'package:timewise/services/ai_service.dart';

import 'support/test_support.dart';

String _reply(String text) => jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text}
            ]
          }
        }
      ]
    });

Task _task(String id, String title, int hour, {int minutes = 60, int priority = 3}) => Task(
      id: id,
      userId: 'u1',
      title: title,
      deadline: today(hour),
      priority: priority,
      category: 'School',
      estimatedMinutes: minutes,
      createdAt: DateTime.now(),
    );

AIService _service(http.Client client, {String? key = 'test-key', List<String>? models}) =>
    AIService(client: client, apiKey: key, models: models, retryDelay: Duration.zero);

/// Planning a FUTURE day so the "never before now" rule does not interfere.
final _planDay = DateTime.now().add(const Duration(days: 1));
DateTime _at(int h, [int m = 0]) => DateTime(_planDay.year, _planDay.month, _planDay.day, h, m);

Task _dueTask(String id, {int dueHour = 22, int minutes = 60, String title = 'Research Paper'}) => Task(
      id: id,
      userId: 'u1',
      title: title,
      deadline: _at(dueHour),
      priority: 3,
      category: 'School',
      estimatedMinutes: minutes,
      createdAt: DateTime.now(),
    );

Future<List<ScheduleItem>> _generate(
  AIService service, {
  List<Task>? tasks,
  List<ScheduleItem>? fixed,
  DateTime? date,
  DateTime? now,
}) {
  return service.generateSchedule(
    userId: 'u1',
    tasks: tasks ?? [_dueTask('t1')],
    scheduleDate: date ?? _planDay,
    fixedEvents: fixed ?? [],
    user: testUser, // wake 07:00, sleep 23:00
    now: now,
  );
}

void main() {
  group('configuration', () {
    test('isConfigured is false without a key and never throws', () {
      expect(_service(MockClient((_) async => http.Response('', 200)), key: '').isConfigured, isFalse);
    });

    test('without a key the planner explains how to enable it', () async {
      final service = _service(MockClient((_) async => http.Response('', 200)), key: '');
      await expectLater(_generate(service), throwsA(isA<AIConfigException>()));
    });

    test('nothing to plan returns an empty plan without calling the API', () async {
      var calls = 0;
      final service = _service(MockClient((_) async {
        calls++;
        return http.Response('', 200);
      }));
      expect(await _generate(service, tasks: []), isEmpty);
      expect(calls, 0);
    });
  });

  group('request', () {
    test('uses a currently served model and sends the key in a header, not the URL', () async {
      http.Request? sent;
      final service = _service(MockClient((req) async {
        sent = req;
        return http.Response(_reply('task|T1|09:00|10:00|ok'), 200);
      }));
      await _generate(service);
      expect(sent, isNotNull);
      expect(sent!.url.path, contains('gemini-3.5-flash-lite'));
      expect(sent!.url.path, isNot(contains('gemini-2.0')));
      expect(sent!.url.queryParameters.containsKey('key'), isFalse);
      expect(sent!.headers['x-goog-api-key'], 'test-key');
    });

    test('falls back to the next model when the first is gone (404)', () async {
      final paths = <String>[];
      final service = _service(MockClient((req) async {
        paths.add(req.url.path);
        if (paths.length == 1) return http.Response('{"error":{"code":404}}', 404);
        return http.Response(_reply('task|T1|09:00|10:00|ok'), 200);
      }));
      final plan = await _generate(service);
      expect(paths.length, 2);
      expect(paths.first, contains('flash-lite'));
      expect(paths.last, isNot(contains('flash-lite')));
      expect(plan, hasLength(1));
    });

    test('retries the same model once on a busy server (503)', () async {
      var calls = 0;
      final service = _service(MockClient((req) async {
        calls++;
        return calls == 1 ? http.Response('busy', 503) : http.Response(_reply('task|T1|09:00|10:00|ok'), 200);
      }));
      expect(await _generate(service), hasLength(1));
      expect(calls, 2);
    });

    test('a rejected key (403) fails at once with a readable message', () async {
      var calls = 0;
      final service = _service(MockClient((req) async {
        calls++;
        return http.Response('{"error":{"message":"API key not valid"}}', 403);
      }));
      Object? error;
      try {
        await _generate(service);
      } catch (e) {
        error = e;
      }
      expect(error, isA<AIServiceException>());
      expect(error.toString(), contains('key was rejected'));
      expect(error.toString(), isNot(contains('{')));
      expect(calls, 1);
    });

    test('an HTTP error never leaks the raw JSON body to the user', () async {
      final service = _service(MockClient((req) async => http.Response(jsonEncode({'error': {'code': 400, 'message': 'bad'}}), 400)));
      Object? error;
      try {
        await _generate(service);
      } catch (e) {
        error = e;
      }
      expect(error, isA<AIServiceException>());
      expect(error.toString(), isNot(contains('{"error"')));
    });

    test('a truncated reply gives a readable error, not a Dart runtime error', () async {
      final service = _service(MockClient((req) async => http.Response(
          jsonEncode({'candidates': [{'finishReason': 'MAX_TOKENS', 'content': {'role': 'model'}}]}), 200)));
      Object? error;
      try {
        await _generate(service);
      } catch (e) {
        error = e;
      }
      expect(error, isA<AIServiceException>());
      expect(error.toString(), contains('did not return a plan'));
    });

    test('no connection is reported as such', () async {
      final service = _service(MockClient((req) async => throw http.ClientException('offline')));
      Object? error;
      try {
        await _generate(service);
      } catch (e) {
        error = e;
      }
      expect(error.toString(), contains('No internet connection'));
    });

    test('a slow server times out with a message', () async {
      final service = AIService(
        client: MockClient((req) => Future<http.Response>.delayed(const Duration(seconds: 2), () => http.Response('', 200))),
        apiKey: 'k',
        timeout: const Duration(milliseconds: 50),
        retryDelay: Duration.zero,
      );
      await expectLater(_generate(service), throwsA(isA<AIServiceException>()));
    });
  });

  group('reply validation', () {
    AIService serviceReplying(String text) => _service(MockClient((req) async => http.Response(_reply(text), 200)));

    test('items outside the wake/sleep window are dropped', () async {
      final plan = await _generate(
        serviceReplying('task|T1|02:00|03:00|middle of the night\ntask|T2|09:00|10:00|fine'),
        tasks: [_task('t1', 'A', 22), _task('t2', 'B', 22)],
      );
      expect(plan.map((i) => i.title), ['B']);
    });

    test('a block that would end after its task deadline is dropped', () async {
      // Task A is due 10:00 on the planned day; the model places it 14:00-15:00.
      final plan = await _generate(
        serviceReplying('task|T1|14:00|15:00|late'),
        tasks: [_dueTask('t1', dueHour: 10, title: 'A')],
      );
      expect(plan, isEmpty);
    });

    test('more time than the task needs is dropped', () async {
      final plan = await _generate(
        serviceReplying('task|T1|09:00|10:00|a\ntask|T1|11:00|13:00|too much'),
        tasks: [_dueTask('t1', title: 'A')],
      );
      expect(plan, hasLength(1));
    });

    test('overlaps with a fixed event and unknown task references are dropped', () async {
      final plan = await _generate(
        serviceReplying('task|T1|13:30|14:30|overlaps class\ntask|T9|16:00|17:00|unknown\nmeal|Lunch|12:00|12:30|ok'),
        fixed: [
          ScheduleItem(id: 'f', userId: 'u1', title: 'Class', startTime: _at(13, 30), endTime: _at(15, 30), type: ScheduleTypes.class_, isFixed: true),
        ],
      );
      expect(plan.map((i) => i.title), ['Lunch']);
    });

    test('two AI blocks never overlap each other', () async {
      final plan = await _generate(serviceReplying('break|Rest|09:00|09:30|a\nbreak|Nap|09:15|09:45|b'));
      expect(plan.map((i) => i.title), ['Rest']);
    });

    test('markdown bullets, back-ticks and bad lines are tolerated', () async {
      final plan = await _generate(
        serviceReplying('Here is your plan:\n- `task|T1|09:00|10:00|ok`\nnonsense\ntask|T1|xx:yy|10:00|bad time'),
        tasks: [_dueTask('t1', minutes: 120, title: 'A')],
      );
      expect(plan, hasLength(1));
      expect(plan.single.taskId, 't1');
      expect(plan.single.isAISuggested, isTrue);
      expect(plan.single.isFixed, isFalse);
    });

    test('an overdue task may be planned as early as possible', () async {
      final overdue = Task(
        id: 't1',
        userId: 'u1',
        title: 'Late',
        deadline: _at(0).subtract(const Duration(days: 3)),
        priority: 3,
        category: 'School',
        estimatedMinutes: 60,
        createdAt: DateTime.now(),
      );
      final plan = await _generate(serviceReplying('task|T1|08:00|09:00|overdue'), tasks: [overdue]);
      expect(plan, hasLength(1));
    });
  });

  group('planning today', () {
    test('never schedules before the current time', () async {
      final now = DateTime(2026, 10, 5, 15, 3);
      final day = DateTime(2026, 10, 5);
      String? prompt;
      final service = _service(MockClient((req) async {
        prompt = (jsonDecode(req.body)['contents'][0]['parts'][0]['text']) as String;
        return http.Response(_reply('task|T1|09:00|10:00|in the past\ntask|T1|16:00|17:00|ok'), 200);
      }));
      final plan = await _generate(
        service,
        date: day,
        now: now,
        tasks: [
          Task(id: 't1', userId: 'u1', title: 'A', deadline: DateTime(2026, 10, 5, 22), priority: 3, category: 'School', estimatedMinutes: 120, createdAt: now),
        ],
      );
      expect(prompt, contains('Do not schedule anything that starts before 15:05'));
      expect(plan.map((i) => i.startTime.hour), [16]);
    });

    test('after the sleep time it tells the user to plan tomorrow', () async {
      final service = _service(MockClient((req) async => http.Response(_reply(''), 200)));
      Object? error;
      try {
        await _generate(service, date: DateTime(2026, 10, 5), now: DateTime(2026, 10, 5, 23, 30));
      } catch (e) {
        error = e;
      }
      expect(error.toString(), contains('Plan tomorrow'));
    });

    test('the prompt carries wake/sleep times, fixed events and sanitized titles', () {
      final service = _service(MockClient((req) async => http.Response('', 200)));
      final prompt = service.buildPrompt(
        tasks: [_dueTask('t1', dueHour: 20, minutes: 45, title: 'Evil|title\nwith newline')],
        date: _planDay,
        fixedEvents: [ScheduleItem(id: 'f', userId: 'u1', title: 'Class', startTime: _at(9), endTime: _at(10), type: 'class', isFixed: true)],
        user: testUser.copyWith(onboarding: {'scheduleStyle': 'Flexible', 'aiHelp': 'Balanced'}),
      );
      expect(prompt, contains('07:00'));
      expect(prompt, contains('23:00'));
      expect(prompt, contains('class: Class 09:00-10:00'));
      expect(prompt, contains('[T1] Evil title with newline'));
      expect(prompt, contains('Schedule style: Flexible'));
    });
  });
}
