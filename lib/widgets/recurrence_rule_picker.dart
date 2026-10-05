import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/recurrence.dart';
import '../theme/app_styles.dart';
import 'ui.dart';

enum _EndMode { never, onDate, afterCount }

/// Form section for building a [RecurrenceRule]: frequency, interval,
/// weekday selection (weekly only) and an end condition. Fully controlled —
/// the parent owns the [value] and receives updates via [onChanged].
class RecurrenceRulePicker extends StatelessWidget {
  final RecurrenceRule value;
  final ValueChanged<RecurrenceRule> onChanged;
  final DateTime firstDate;

  const RecurrenceRulePicker({
    required this.value,
    required this.onChanged,
    required this.firstDate,
    super.key,
  });

  static const _frequencyLabels = {
    RecurrenceFrequency.daily: 'Daily',
    RecurrenceFrequency.weekly: 'Weekly',
    RecurrenceFrequency.monthly: 'Monthly',
  };

  static const _weekdays = [
    (1, 'M', 'Monday'),
    (2, 'T', 'Tuesday'),
    (3, 'W', 'Wednesday'),
    (4, 'T', 'Thursday'),
    (5, 'F', 'Friday'),
    (6, 'S', 'Saturday'),
    (7, 'S', 'Sunday'),
  ];

  _EndMode get _endMode {
    if (value.count != null) return _EndMode.afterCount;
    if (value.endDate != null) return _EndMode.onDate;
    return _EndMode.never;
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value.endDate ?? firstDate.add(const Duration(days: 30)),
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 3650)),
    );
    if (picked != null) onChanged(value.copyWith(endDate: picked, clearCount: true));
  }

  @override
  Widget build(BuildContext context) {
    final unit = switch (value.frequency) {
      RecurrenceFrequency.daily => value.interval == 1 ? 'day' : 'days',
      RecurrenceFrequency.weekly => value.interval == 1 ? 'week' : 'weeks',
      RecurrenceFrequency.monthly => value.interval == 1 ? 'month' : 'months',
      RecurrenceFrequency.none => '',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Repeat'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _frequencyLabels.entries)
              PillChip(
                label: entry.value,
                selected: value.frequency == entry.key,
                onTap: () => onChanged(
                  RecurrenceRule(
                    frequency: entry.key,
                    interval: 1,
                    daysOfWeek: entry.key == RecurrenceFrequency.weekly ? {firstDate.weekday} : const {},
                  ),
                ),
              ),
          ],
        ),
        if (value.isRecurring) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Every', style: context.body),
              const SizedBox(width: 8),
              _Stepper(
                value: value.interval,
                min: 1,
                max: 30,
                label: 'interval',
                onChanged: (v) => onChanged(value.copyWith(interval: v)),
              ),
              const SizedBox(width: 8),
              Text(unit, style: context.body),
            ],
          ),
          if (value.frequency == RecurrenceFrequency.weekly) ...[
            const SizedBox(height: 16),
            const SectionLabel('On'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (index, letter, name) in _weekdays)
                  _DayToggle(
                    letter: letter,
                    name: name,
                    selected: value.daysOfWeek.contains(index),
                    onTap: () {
                      final days = Set<int>.from(value.daysOfWeek);
                      if (days.contains(index)) {
                        if (days.length > 1) days.remove(index);
                      } else {
                        days.add(index);
                      }
                      onChanged(value.copyWith(daysOfWeek: days));
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const SectionLabel('Ends'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PillChip(
                label: 'Never',
                selected: _endMode == _EndMode.never,
                onTap: () => onChanged(value.copyWith(clearEndDate: true, clearCount: true)),
              ),
              PillChip(
                label: 'On date',
                selected: _endMode == _EndMode.onDate,
                onTap: () => onChanged(
                  value.copyWith(endDate: firstDate.add(const Duration(days: 30)), clearCount: true),
                ),
              ),
              PillChip(
                label: 'After',
                selected: _endMode == _EndMode.afterCount,
                onTap: () => onChanged(value.copyWith(count: 10, clearEndDate: true)),
              ),
            ],
          ),
          if (_endMode == _EndMode.onDate) ...[
            const SizedBox(height: 12),
            PickerField(
              label: 'Last occurrence',
              value: DateFormat('EEE, MMM d, yyyy').format(value.endDate!),
              icon: Icons.event,
              onTap: () => _pickEndDate(context),
            ),
          ],
          if (_endMode == _EndMode.afterCount) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _Stepper(
                  value: value.count ?? 10,
                  min: 1,
                  max: 200,
                  label: 'occurrences',
                  onChanged: (v) => onChanged(value.copyWith(count: v)),
                ),
                const SizedBox(width: 8),
                Text('occurrences', style: context.body),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.repeat, size: 16, color: context.cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text(value.summary, style: context.label)),
            ],
          ),
        ],
      ],
    );
  }
}

/// Round weekday button (44 px) with the full day name for screen readers.
class _DayToggle extends StatelessWidget {
  final String letter;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _DayToggle({required this.letter, required this.name, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: Material(
        color: selected ? context.primary : context.cs.surfaceContainer,
        shape: CircleBorder(side: BorderSide(color: selected ? context.primary : context.cs.outline, width: 1.5)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 44,
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: selected ? Colors.white : context.cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// − value + control with 48 px buttons.
class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final String label;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Decrease $label',
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 44,
          child: Text('$value', textAlign: TextAlign.center, style: context.h3),
        ),
        IconButton.filledTonal(
          tooltip: 'Increase $label',
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
