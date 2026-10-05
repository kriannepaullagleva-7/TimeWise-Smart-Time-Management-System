import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

import 'package:timewise/models/recurrence.dart';
import 'package:timewise/models/schedule.dart';
import 'package:timewise/providers/schedule_provider.dart';
import 'package:timewise/services/ai_service.dart';

import 'support/test_support.dart';

ScheduleItem _event(String id, int startHour, int endHour, {bool ai = false, bool fixed = true, DateTime? date}) {
  final d = date ?? DateTime.now().add(const Duration(days: 1));
  return ScheduleItem(
    id: id,
    userId: 'u1',
    title: 'Event $id',
    startTime: DateTime(d.year, d.month, d.day, startHour),
    endTime: DateTime(d.year, d.month, d.day, endHour),
    type: ScheduleTypes.class_,
    isFixed: fixed,
    isAISuggested: ai,
  );
}

void main() {
  late FakeScheduleRepo repo;
  late ScheduleProvider provider;
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  DateTime at(int h, [int m = 0, DateTime? d]) {
    final day = d ?? tomorrow;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  setUp(() {
    repo = FakeScheduleRepo();
    provider = ScheduleProvider(
      scheduleRepository: repo,
      aiService: AIService(apiKey: 'k', client: MockClient((_) async => http.Response('', 500)), retryDelay: Duration.zero),
    );
  });

  group('addFixedEvent', () {
    test('saves a single event with a trimmed note', () async {
      await provider.addFixedEvent(
        userId: 'u1',
        title: 'Lecture',
        startTime: at(9),
        endTime: at(10),
        type: ScheduleTypes.class_,
        note: '  Room 204  ',
      );
      expect(repo.store, hasLength(1));
      expect(repo.store.single.note, 'Room 204');
      expect(repo.store.single.isFixed, isTrue);
      expect(repo.store.single.recurrenceId, isNull);
    });

    test('the Fixed switch is honoured', () async {
      await provider.addFixedEvent(
        userId: 'u1',
        title: 'Flexible nap',
        startTime: at(14),
        endTime: at(15),
        type: ScheduleTypes.personal,
        isFixed: false,
      );
      expect(repo.store.single.isFixed, isFalse);
    });

    test('rejects an end time that is not after the start', () async {
      await expectLater(
        provider.addFixedEvent(userId: 'u1', title: 'x', startTime: at(10), endTime: at(9), type: 'class'),
        throwsA(isA<ScheduleConflictException>()),
      );
      expect(repo.store, isEmpty);
      expect(provider.isLoading, isFalse);
    });

    test('rejects an overlap with the user\'s own event and says which one', () async {
      repo.store.add(_event('a', 9, 11));
      Object? error;
      try {
        await provider.addFixedEvent(userId: 'u1', title: 'x', startTime: at(10), endTime: at(12), type: 'class');
      } catch (e) {
        error = e;
      }
      expect(error, isA<ScheduleConflictException>());
      expect(error.toString(), contains('Event a'));
      expect(repo.store, hasLength(1));
    });

    test('back-to-back events are allowed', () async {
      repo.store.add(_event('a', 9, 10));
      await provider.addFixedEvent(userId: 'u1', title: 'next', startTime: at(10), endTime: at(11), type: 'class');
      expect(repo.store, hasLength(2));
    });

    test('an AI-suggested block does not block a new event', () async {
      repo.store.add(_event('ai', 9, 11, ai: true, fixed: false));
      await provider.addFixedEvent(userId: 'u1', title: 'x', startTime: at(10), endTime: at(12), type: 'class');
      expect(repo.store, hasLength(2));
    });

    test('a repeating event creates every occurrence and checks ALL days before saving anything', () async {
      // Blocker on the 3rd daily occurrence.
      repo.store.add(_event('blocker', 9, 10, date: tomorrow.add(const Duration(days: 2))));
      Object? error;
      try {
        await provider.addFixedEvent(
          userId: 'u1',
          title: 'Daily',
          startTime: at(9),
          endTime: at(10),
          type: 'class',
          recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.daily, count: 5),
        );
      } catch (e) {
        error = e;
      }
      expect(error, isA<ScheduleConflictException>());
      expect(repo.store, hasLength(1), reason: 'nothing may be written when one occurrence conflicts');

      repo.store.clear();
      await provider.addFixedEvent(
        userId: 'u1',
        title: 'Daily',
        startTime: at(9),
        endTime: at(10),
        type: 'class',
        recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.daily, count: 5),
      );
      expect(repo.store, hasLength(5));
      expect(repo.store.map((i) => i.recurrenceId).toSet(), {repo.store.first.id});
    });
  });

  group('updateEvent, delete', () {
    test('editing keeps the series link and does not conflict with itself', () async {
      final original = _event('a', 9, 10).copyWith();
      repo.store.add(original);
      await provider.updateEvent(original, title: 'Renamed', startTime: at(9), endTime: at(10, 30), type: 'class', note: '');
      expect(repo.store.single.title, 'Renamed');
      expect(repo.store.single.endTime, at(10, 30));
      expect(repo.store.single.note, isNull);
    });

    test('moving onto another event is rejected', () async {
      final a = _event('a', 9, 10);
      repo.store.addAll([a, _event('b', 11, 12)]);
      await expectLater(
        provider.updateEvent(a, title: 'a', startTime: at(11), endTime: at(12), type: 'class'),
        throwsA(isA<ScheduleConflictException>()),
      );
    });

    test('deleteScheduleSeries removes only that user\'s series', () async {
      repo.store.addAll([
        _event('s1', 9, 10).copyWith(),
        ScheduleItem(id: 's2', userId: 'u1', title: 'x', startTime: at(9), endTime: at(10), type: 'class', recurrenceId: 'S'),
        ScheduleItem(id: 's3', userId: 'u1', title: 'x', startTime: at(11), endTime: at(12), type: 'class', recurrenceId: 'S'),
      ]);
      await provider.deleteScheduleSeries('u1', 'S');
      expect(repo.store.map((i) => i.id), ['s1']);
    });
  });

  group('AI plan', () {
    test('acceptGeneratedSchedule replaces the day\'s earlier AI blocks and keeps everything else', () async {
      final fixed = _event('fixed', 9, 10);
      final oldAi = _event('old-ai', 13, 14, ai: true, fixed: false);
      repo.store.addAll([fixed, oldAi]);

      await provider.acceptGeneratedSchedule('u1', tomorrow, [
        ScheduleItem(id: '', userId: 'u1', title: 'New block', startTime: at(15), endTime: at(16), type: ScheduleTypes.task, taskId: 't1', isAISuggested: true),
      ]);

      expect(repo.store.map((i) => i.title), containsAll(['Event fixed', 'New block']));
      expect(repo.store.any((i) => i.id == 'old-ai'), isFalse);
      final saved = repo.store.firstWhere((i) => i.title == 'New block');
      expect(saved.id, isNotEmpty);
      expect(saved.isAISuggested, isTrue);
      expect(saved.isFixed, isFalse);
    });

    test('generateAISchedulePreview sends only fixed events and the tasks worth planning', () async {
      repo.store.add(_event('fixed', 9, 10));
      repo.store.add(_event('ai', 11, 12, ai: true, fixed: false));
      String? prompt;
      final p = ScheduleProvider(
        scheduleRepository: repo,
        aiService: AIService(
          apiKey: 'k',
          retryDelay: Duration.zero,
          client: MockClient((req) async {
            prompt = jsonDecode(req.body)['contents'][0]['parts'][0]['text'] as String;
            return http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': 'task|T1|12:00|13:00|ok'}
                      ]
                    }
                  }
                ]
              }),
              200,
            );
          }),
        ),
      );
      final plan = await p.generateAISchedulePreview(
        userId: 'u1',
        tasks: [
          makeTask('t1', title: 'Essay', deadline: at(20), priority: 3),
          makeTask('far', title: 'Far away', deadline: DateTime.now().add(const Duration(days: 60))),
          makeTask('done', title: 'Done already', completed: true, deadline: at(20)),
        ],
        scheduleDate: tomorrow,
        user: testUser,
      );
      expect(plan, hasLength(1));
      expect(prompt, contains('Essay'));
      expect(prompt, isNot(contains('Far away')));
      expect(prompt, isNot(contains('Done already')));
      expect(prompt, contains('Event fixed'));
      expect(prompt, isNot(contains('Event ai')));
      expect(p.isGeneratingSchedule, isFalse);
    });

    test('without an API key the provider refuses with a clear message', () async {
      final p = ScheduleProvider(scheduleRepository: repo, aiService: AIService(apiKey: ''));
      expect(p.isAIConfigured, isFalse);
      await expectLater(
        p.generateAISchedulePreview(userId: 'u1', tasks: [makeTask('t1')], scheduleDate: tomorrow, user: testUser),
        throwsA(isA<AIConfigException>()),
      );
    });
  });
}
