import 'package:flutter/material.dart';

import '../models/recurrence.dart';

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
    RecurrenceFrequency.none: 'Does not repeat',
    RecurrenceFrequency.daily: 'Daily',
    RecurrenceFrequency.weekly: 'Weekly',
    RecurrenceFrequency.monthly: 'Monthly',
  };

  static const _weekdayLabels = {
    1: 'M',
    2: 'T',
    3: 'W',
    4: 'T',
    5: 'F',
    6: 'S',
    7: 'S',
  };

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
    if (picked != null) {
      onChanged(value.copyWith(endDate: picked, clearCount: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Repeat', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<RecurrenceFrequency>(
          initialValue: value.frequency,
          onChanged: (freq) {
            if (freq == null) return;
            onChanged(
              RecurrenceRule(
                frequency: freq,
                interval: 1,
                daysOfWeek: freq == RecurrenceFrequency.weekly
                    ? {firstDate.weekday}
                    : const {},
              ),
            );
          },
          items: _frequencyLabels.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (value.isRecurring) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Every'),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: value.interval > 1
                    ? () => onChanged(value.copyWith(interval: value.interval - 1))
                    : null,
                icon: const Icon(Icons.remove),
                iconSize: 18,
                visualDensity: VisualDensity.compact,
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '${value.interval}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton.filledTonal(
                onPressed: value.interval < 30
                    ? () => onChanged(value.copyWith(interval: value.interval + 1))
                    : null,
                icon: const Icon(Icons.add),
                iconSize: 18,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              Text(switch (value.frequency) {
                RecurrenceFrequency.daily =>
                  value.interval == 1 ? 'day' : 'days',
                RecurrenceFrequency.weekly =>
                  value.interval == 1 ? 'week' : 'weeks',
                RecurrenceFrequency.monthly =>
                  value.interval == 1 ? 'month' : 'months',
                RecurrenceFrequency.none => '',
              }),
            ],
          ),
          if (value.frequency == RecurrenceFrequency.weekly) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: _weekdayLabels.entries.map((e) {
                final selected = value.daysOfWeek.contains(e.key);
                return FilterChip(
                  label: Text(e.value),
                  selected: selected,
                  onSelected: (isSelected) {
                    final days = Set<int>.from(value.daysOfWeek);
                    if (isSelected) {
                      days.add(e.key);
                    } else if (days.length > 1) {
                      days.remove(e.key);
                    }
                    onChanged(value.copyWith(daysOfWeek: days));
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          Text('Ends', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<_EndMode>(
            selected: {_endMode},
            onSelectionChanged: (selection) {
              switch (selection.first) {
                case _EndMode.never:
                  onChanged(value.copyWith(clearEndDate: true, clearCount: true));
                case _EndMode.onDate:
                  onChanged(
                    value.copyWith(
                      endDate: firstDate.add(const Duration(days: 30)),
                      clearCount: true,
                    ),
                  );
                case _EndMode.afterCount:
                  onChanged(value.copyWith(count: 10, clearEndDate: true));
              }
            },
            segments: const [
              ButtonSegment(value: _EndMode.never, label: Text('Never')),
              ButtonSegment(value: _EndMode.onDate, label: Text('On date')),
              ButtonSegment(value: _EndMode.afterCount, label: Text('After N')),
            ],
          ),
          if (_endMode == _EndMode.onDate) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _pickEndDate(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event, size: 18),
                    const SizedBox(width: 8),
                    Text(value.endDate!.toString().split(' ')[0]),
                  ],
                ),
              ),
            ),
          ],
          if (_endMode == _EndMode.afterCount) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: (value.count ?? 10) > 1
                      ? () => onChanged(value.copyWith(count: (value.count ?? 10) - 1))
                      : null,
                  icon: const Icon(Icons.remove),
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${value.count ?? 10}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: (value.count ?? 10) < 200
                      ? () => onChanged(value.copyWith(count: (value.count ?? 10) + 1))
                      : null,
                  icon: const Icon(Icons.add),
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                const Text('occurrences'),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            value.summary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
