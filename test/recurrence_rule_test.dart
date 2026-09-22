import 'package:flutter_test/flutter_test.dart';
import 'package:timewise/models/recurrence.dart';

void main() {
  group('RecurrenceRule.occurrencesFrom', () {
    test('non-recurring rule returns just the first date', () {
      const rule = RecurrenceRule.none;
      final result = rule.occurrencesFrom(DateTime(2026, 1, 1));
      expect(result, [DateTime(2026, 1, 1)]);
    });

    test('daily with interval and count', () {
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        interval: 2,
        count: 4,
      );
      final result = rule.occurrencesFrom(DateTime(2026, 1, 1));
      expect(result, [
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 3),
        DateTime(2026, 1, 5),
        DateTime(2026, 1, 7),
      ]);
    });

    test('daily stops at endDate', () {
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        endDate: DateTime(2026, 1, 3),
      );
      final result = rule.occurrencesFrom(DateTime(2026, 1, 1));
      expect(result, [
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 2),
        DateTime(2026, 1, 3),
      ]);
    });

    test('weekly on specific weekdays skips ahead to the first matching day', () {
      // 2026-01-01 is a Thursday, which isn't in the Mon/Wed/Fri pattern, so
      // the series should start at the next matching day rather than force
      // the anchor date in (matches how calendar apps typically behave).
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        daysOfWeek: {1, 3, 5}, // Mon, Wed, Fri
        count: 4,
      );
      final result = rule.occurrencesFrom(DateTime(2026, 1, 1));
      expect(result, [
        DateTime(2026, 1, 2), // Fri
        DateTime(2026, 1, 5), // Mon
        DateTime(2026, 1, 7), // Wed
        DateTime(2026, 1, 9), // Fri
      ]);
    });

    test('weekly always includes the anchor date when it matches the pattern', () {
      // 2026-01-05 is a Monday, which is in the pattern.
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        daysOfWeek: {1, 3, 5}, // Mon, Wed, Fri
        count: 3,
      );
      final result = rule.occurrencesFrom(DateTime(2026, 1, 5));
      expect(result, [
        DateTime(2026, 1, 5), // Mon
        DateTime(2026, 1, 7), // Wed
        DateTime(2026, 1, 9), // Fri
      ]);
    });

    test('weekly with interval 2 skips every other week', () {
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
        daysOfWeek: {1}, // Monday
        count: 3,
      );
      final result = rule.occurrencesFrom(DateTime(2026, 1, 5)); // Monday
      expect(result, [
        DateTime(2026, 1, 5),
        DateTime(2026, 1, 19),
        DateTime(2026, 2, 2),
      ]);
    });

    test('monthly clamps day-of-month overflow to the last day of shorter months', () {
      final rule = RecurrenceRule(
        frequency: RecurrenceFrequency.monthly,
        count: 4,
      );
      final result = rule.occurrencesFrom(DateTime(2026, 1, 31));
      expect(result, [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28), // 2026 is not a leap year
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
      ]);
    });

    test('default rolling cap applies when neither endDate nor count is set', () {
      final rule = RecurrenceRule(frequency: RecurrenceFrequency.daily);
      final result = rule.occurrencesFrom(DateTime(2026, 1, 1));
      expect(result.length, 60);
    });

    test('summary describes the rule in plain language', () {
      expect(RecurrenceRule.none.summary, 'Does not repeat');
      expect(
        const RecurrenceRule(frequency: RecurrenceFrequency.daily).summary,
        'Every day',
      );
      expect(
        const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          interval: 2,
          daysOfWeek: {1, 3},
        ).summary,
        'Every 2 weeks on Mon, Wed',
      );
    });
  });
}
