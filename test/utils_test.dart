import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timewise/models/schedule.dart';
import 'package:timewise/models/user.dart';
import 'package:timewise/theme/app_colors.dart';
import 'package:timewise/theme/app_styles.dart';
import 'package:timewise/utils/day_usage.dart';
import 'package:timewise/utils/feedback.dart';
import 'package:timewise/utils/app_exceptions.dart';
import 'package:timewise/utils/validators.dart';

void main() {
  group('DayUsage', () {
    final day = DateTime(2026, 10, 5);
    ScheduleItem item(String id, int sh, int sm, int eh, int em, {String type = 'class', bool fixed = false, bool ai = false}) => ScheduleItem(
          id: id,
          userId: 'u',
          title: id,
          startTime: DateTime(2026, 10, 5, sh, sm),
          endTime: DateTime(2026, 10, 5, eh, em),
          type: type,
          isFixed: fixed,
          isAISuggested: ai,
        );

    test('counts every minute once: 16 h awake, 135 min busy => 825 min free', () {
      final usage = DayUsage.compute(
        [
          item('class', 9, 0, 10, 0, fixed: true),
          item('task', 11, 0, 12, 0, type: 'task', ai: true),
          item('break', 12, 0, 12, 15, type: 'break', ai: true),
        ],
        day,
        wakeMinutes: 7 * 60,
        sleepMinutes: 23 * 60,
      );
      expect(usage.awakeMinutes, 960);
      expect(usage.fixedMinutes, 60);
      expect(usage.aiMinutes, 60);
      expect(usage.breakMinutes, 15);
      expect(usage.freeMinutes, 825);
    });

    test('overlapping items are not double counted and fixed wins', () {
      final usage = DayUsage.compute(
        [item('a', 9, 0, 11, 0, fixed: true), item('b', 10, 0, 12, 0, type: 'task', ai: true)],
        day,
        wakeMinutes: 7 * 60,
        sleepMinutes: 23 * 60,
      );
      expect(usage.fixedMinutes, 120);
      expect(usage.aiMinutes, 60);
      expect(usage.busyMinutes, 180);
    });

    test('time outside the waking window is ignored', () {
      final usage = DayUsage.compute([item('night', 1, 0, 3, 0, fixed: true), item('late', 22, 0, 23, 30, fixed: true)], day, wakeMinutes: 7 * 60, sleepMinutes: 23 * 60);
      expect(usage.fixedMinutes, 60);
    });

    test('a sleep time before the wake time means the day runs past midnight', () {
      final usage = DayUsage.compute(const [], day, wakeMinutes: 10 * 60, sleepMinutes: 2 * 60);
      expect(usage.awakeMinutes, 16 * 60);
      expect(usage.freeMinutes, 16 * 60);
    });

    test('Calendar task rows are not counted as busy time', () {
      final row = item('${kTaskRowPrefix}x', 9, 0, 11, 0, type: 'task');
      final usage = DayUsage.compute([row], day, wakeMinutes: 7 * 60, sleepMinutes: 23 * 60);
      expect(usage.busyMinutes, 0);
    });
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('plain'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email('a b@c.com'), isNotNull);
      expect(Validators.email('student@umindanao.edu.ph'), isNull);
      expect(Validators.email('  me@x.io  '), isNull);
    });

    test('new password needs 6 characters', () {
      expect(Validators.newPassword(''), isNotNull);
      expect(Validators.newPassword('12345'), isNotNull);
      expect(Validators.newPassword('123456'), isNull);
    });

    test('existing password only needs to be present', () {
      expect(Validators.existingPassword(''), isNotNull);
      expect(Validators.existingPassword('x'), isNull);
    });

    test('name', () {
      expect(Validators.name('   '), isNotNull);
      expect(Validators.name('Jane Doe'), isNull);
      expect(Validators.name('x' * 51), isNotNull);
    });
  });

  group('colour contrast', () {
    test('contrastRatio matches the WCAG definition', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
      expect(contrastRatio(Colors.white, Colors.white), closeTo(1, 0.001));
    });

    test('readableOn reaches 4.5:1 for every status colour on its tint, light and dark', () {
      for (final background in [const Color(0xFFF0F4FA), const Color(0xFF222222), Colors.white, const Color(0xFF181818)]) {
        for (final base in [AppColors.success, AppColors.warning, AppColors.error, AppColors.secondary, AppColors.primary, const Color(0xFF10B981), const Color(0xFFF59E0B)]) {
          final fg = readableOn(base, background);
          expect(contrastRatio(fg, background), greaterThanOrEqualTo(4.5), reason: '$base on $background');
        }
      }
    });

    test('every accent preset keeps 4.5:1 with the white text placed on it', () {
      for (final preset in AppColors.accentPresets) {
        expect(contrastRatio(Colors.white, preset.color), greaterThanOrEqualTo(4.5), reason: preset.name);
      }
    });

    test('the AI gradient ends keep 4.5:1 with white text', () {
      for (final color in AppColors.aiGradient.colors) {
        expect(contrastRatio(Colors.white, color), greaterThanOrEqualTo(4.5), reason: '$color');
      }
    });

    test('category colours are stable per name and shared by synonyms', () {
      expect(categoryColor('School'), categoryColor('study'));
      expect(categoryColor('Gym trip'), categoryColor('gym trip'.toUpperCase().toLowerCase()));
      expect(categoryColor('Custom A'), categoryColor('Custom A'));
    });
  });

  group('friendlyError', () {
    test('uses the message of app errors', () {
      expect(friendlyError(const ScheduleConflictException('Overlaps with X')), 'Overlaps with X');
      expect(friendlyError(const AIServiceException('The AI is busy')), 'The AI is busy');
    });

    test('never shows technical text for unknown errors', () {
      final text = friendlyError(StateError('boom: stack trace here'));
      expect(text, isNot(contains('boom')));
      expect(text, isNotEmpty);
    });
  });

  group('UserModel', () {
    test('minutesOf parses HH:mm and falls back when malformed', () {
      expect(UserModel.minutesOf('07:30', 0), 450);
      expect(UserModel.minutesOf('7', 99), 99);
      expect(UserModel.minutesOf('25:00', 99), 99);
      expect(UserModel.minutesOf('aa:bb', 99), 99);
    });

    test('defaults: wake 07:00, sleep 23:00, five categories', () {
      final u = UserModel(uid: 'u', email: '', name: 'n', createdAt: DateTime(2026));
      expect(u.wakeMinutes, 420);
      expect(u.sleepMinutes, 1380);
      expect(u.categories, kDefaultCategories);
    });
  });

  group('ScheduleTypes', () {
    test('labels', () {
      expect(ScheduleTypes.label('class'), 'Class');
      expect(ScheduleTypes.label('appointment'), 'Appointment');
      expect(ScheduleTypes.label('break'), 'Break');
    });

    test('ScheduleItem.overlapsWith treats touching blocks as non-overlapping', () {
      ScheduleItem at(int s, int e) => ScheduleItem(
            id: 'x',
            userId: 'u',
            title: 't',
            startTime: DateTime(2026, 1, 1, s),
            endTime: DateTime(2026, 1, 1, e),
            type: 'class',
          );
      expect(at(9, 10).overlapsWith(at(10, 11)), isFalse);
      expect(at(9, 11).overlapsWith(at(10, 12)), isTrue);
    });
  });
}
