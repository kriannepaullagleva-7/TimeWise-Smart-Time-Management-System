import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/recurrence.dart';
import '../../models/schedule.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../theme/app_styles.dart';
import '../../utils/feedback.dart';
import '../../widgets/recurrence_rule_picker.dart';
import '../../widgets/ui.dart';

/// Create a calendar event, or edit one occurrence of an existing event
/// (pass [item]). Fixed events are never moved by the AI planner.
class AddFixedEventScreen extends StatefulWidget {
  final DateTime date;
  final ScheduleItem? item;

  const AddFixedEventScreen({required this.date, this.item, super.key});

  @override
  State<AddFixedEventScreen> createState() => _AddFixedEventScreenState();
}

class _AddFixedEventScreenState extends State<AddFixedEventScreen> {
  late final _titleController = TextEditingController(text: widget.item?.title);
  late final _notesController = TextEditingController(text: widget.item?.note);

  late DateTime _selectedDate = widget.item?.startTime ?? widget.date;
  late TimeOfDay _startTime = widget.item == null
      ? const TimeOfDay(hour: 9, minute: 0)
      : TimeOfDay.fromDateTime(widget.item!.startTime);
  late TimeOfDay _endTime = widget.item == null
      ? const TimeOfDay(hour: 10, minute: 0)
      : TimeOfDay.fromDateTime(widget.item!.endTime);
  late String _type = widget.item?.type ?? ScheduleTypes.class_;
  late bool _isFixed = widget.item?.isFixed ?? true;
  bool _isRecurring = false;
  RecurrenceRule _rule = const RecurrenceRule(frequency: RecurrenceFrequency.weekly);
  bool _attempted = false;
  bool _isSaving = false;
  String? _conflict;

  bool get _editing => widget.item != null;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DateTime _combine(TimeOfDay time) =>
      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, time.hour, time.minute);

  bool get _endAfterStart => _combine(_endTime).isAfter(_combine(_startTime));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _conflict = null;
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _startTime : _endTime);
    if (picked == null) return;
    setState(() {
      _conflict = null;
      if (isStart) {
        // Keep the same duration when the start moves past the end.
        final oldDuration = _combine(_endTime).difference(_combine(_startTime));
        _startTime = picked;
        if (!_endAfterStart) {
          final newEnd = _combine(_startTime).add(oldDuration.isNegative || oldDuration == Duration.zero ? const Duration(hours: 1) : oldDuration);
          if (newEnd.day == _selectedDate.day) _endTime = TimeOfDay.fromDateTime(newEnd);
        }
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _attempted = true);
    final title = _titleController.text.trim();
    if (title.isEmpty || !_endAfterStart || _isSaving) return;

    final userId = context.read<AuthProvider>().currentUser?.uid;
    if (userId == null) return;
    final provider = context.read<ScheduleProvider>();

    setState(() {
      _isSaving = true;
      _conflict = null;
    });
    try {
      if (_editing) {
        await provider.updateEvent(
          widget.item!,
          title: title,
          startTime: _combine(_startTime),
          endTime: _combine(_endTime),
          type: _type,
          note: _notesController.text,
          isFixed: _isFixed,
        );
      } else {
        await provider.addFixedEvent(
          userId: userId,
          title: title,
          startTime: _combine(_startTime),
          endTime: _combine(_endTime),
          type: _type,
          isFixed: _isFixed,
          note: _notesController.text,
          recurrence: _isRecurring ? _rule : RecurrenceRule.none,
        );
      }
      if (!mounted) return;
      showMessage(context, _editing ? 'Event updated' : (_isRecurring ? 'Repeating event saved' : 'Event saved'));
      Navigator.pop(context, true);
    } on ScheduleConflictException catch (e) {
      if (mounted) setState(() => _conflict = e.message);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleError = _attempted && _titleController.text.trim().isEmpty ? 'Give the event a name.' : null;
    final timeError = !_endAfterStart ? 'End time must be after the start time.' : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: _editing ? 'Edit Event' : 'Add Event'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 24),
                children: [
                  LabeledField(
                    label: 'Event name',
                    hint: 'e.g. CS101 lecture',
                    controller: _titleController,
                    icon: Icons.bookmark_border,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLength: 80,
                    errorText: titleError,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  PickerField(
                    label: 'Date',
                    value: DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                    icon: Icons.calendar_today_outlined,
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: PickerField(
                          label: 'Starts',
                          value: _startTime.format(context),
                          icon: Icons.access_time,
                          onTap: () => _pickTime(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PickerField(
                          label: 'Ends',
                          value: _endTime.format(context),
                          icon: Icons.access_time,
                          warn: timeError != null,
                          onTap: () => _pickTime(false),
                        ),
                      ),
                    ],
                  ),
                  if (timeError != null || _conflict != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline, size: 16, color: context.cs.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              timeError ?? _conflict!,
                              style: context.label.copyWith(color: readableOn(context.cs.error, context.cs.surface)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  const SectionLabel('Type'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in ScheduleTypes.selectable)
                        PillChip(label: ScheduleTypes.label(t), selected: _type == t, onTap: () => setState(() => _type = t)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Notes (optional)',
                    hint: 'Room, link, things to bring…',
                    controller: _notesController,
                    maxLines: 3,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  SwitchRow(
                    icon: Icons.lock_outline,
                    title: 'Fixed schedule',
                    subtitle: _isFixed
                        ? 'The AI plans around this block and never moves it.'
                        : 'The AI may schedule other tasks during this time.',
                    value: _isFixed,
                    onChanged: (v) => setState(() => _isFixed = v),
                  ),
                  if (!_editing) ...[
                    const SizedBox(height: 12),
                    SwitchRow(
                      icon: Icons.repeat,
                      title: 'Repeat',
                      subtitle: 'Create this event on several days.',
                      value: _isRecurring,
                      onChanged: (v) => setState(() {
                        _isRecurring = v;
                        _conflict = null;
                        if (v && !_rule.isRecurring) _rule = const RecurrenceRule(frequency: RecurrenceFrequency.weekly);
                      }),
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(height: 12),
                      AppCard(
                        child: RecurrenceRulePicker(
                          value: _rule.isRecurring && _rule.frequency == RecurrenceFrequency.weekly && _rule.daysOfWeek.isEmpty
                              ? _rule.copyWith(daysOfWeek: {_selectedDate.weekday})
                              : _rule,
                          firstDate: _selectedDate,
                          onChanged: (r) => setState(() {
                            _rule = r;
                            _conflict = null;
                          }),
                        ),
                      ),
                    ],
                  ] else if (widget.item!.isRecurring) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: context.cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Editing changes only this occurrence.', style: context.label)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            BottomActionBar(
              child: GradientButton(
                label: _editing ? 'Save changes' : 'Save event',
                loading: _isSaving,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
