import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/recurrence.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_styles.dart';
import '../../utils/feedback.dart';
import '../../widgets/recurrence_rule_picker.dart';
import '../../widgets/ui.dart';

const _reminderChoices = <(int?, String)>[
  (null, 'None'),
  (15, '15 min before'),
  (60, '1 hour before'),
  (180, '3 hours before'),
  (1440, '1 day before'),
];

const _durationChoices = [15, 30, 45, 60, 90, 120, 180];
const _minMinutes = 5;
const _maxMinutes = 720;

String _formatMinutes(int m) {
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '$h h' : '$h h $r min';
}

String _reminderLabel(int minutes) {
  for (final (value, label) in _reminderChoices) {
    if (value == minutes) return label;
  }
  return '${_formatMinutes(minutes)} before';
}

/// Create a task, or edit one (pass [task]). Editing a repeating task changes
/// only that occurrence.
class AddTaskScreen extends StatefulWidget {
  final Task? task;

  const AddTaskScreen({this.task, super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  late final _titleController = TextEditingController(text: widget.task?.title);
  late final _descriptionController = TextEditingController(text: widget.task?.description);
  final _subtaskController = TextEditingController();

  late DateTime _deadlineDate = widget.task?.deadline ?? DateTime.now().add(const Duration(days: 1));
  late TimeOfDay _deadlineTime =
      widget.task != null ? TimeOfDay.fromDateTime(widget.task!.deadline) : const TimeOfDay(hour: 18, minute: 0);
  late int _minutes = widget.task?.estimatedMinutes ?? 60;
  late int _priority = widget.task?.priority ?? 2;
  String? _categoryChoice;
  late int? _reminder = widget.task?.reminderMinutesBefore;
  late final List<Subtask> _subtasks = widget.task?.subtasks.toList() ?? [];
  bool _repeats = false;
  RecurrenceRule _rule = const RecurrenceRule(frequency: RecurrenceFrequency.weekly);

  bool _attempted = false;
  bool _isSaving = false;

  bool get _editing => widget.task != null;

  List<String> _userCategories(UserModel? user) =>
      (user?.categories.isNotEmpty ?? false) ? user!.categories : kDefaultCategories;

  /// The tapped category, else the edited task's own, else the user's first.
  String _category(List<String> categories) => _categoryChoice ?? widget.task?.category ?? categories.first;

  DateTime get _deadline => DateTime(
        _deadlineDate.year,
        _deadlineDate.month,
        _deadlineDate.day,
        _deadlineTime.hour,
        _deadlineTime.minute,
      );

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final earliest = _deadlineDate.isBefore(now) ? _deadlineDate : now.subtract(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadlineDate,
      firstDate: DateTime(earliest.year, earliest.month, earliest.day),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _deadlineDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _deadlineTime);
    if (picked != null) setState(() => _deadlineTime = picked);
  }

  Future<void> _pickCustomDuration() async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _CustomDurationDialog(initialMinutes: _minutes),
    );
    if (result != null) setState(() => _minutes = result);
  }

  void _addSubtask() {
    final title = _subtaskController.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _subtasks.add(Subtask(id: DateTime.now().microsecondsSinceEpoch.toString(), title: title));
      _subtaskController.clear();
    });
  }

  Future<void> _save() async {
    setState(() => _attempted = true);
    final title = _titleController.text.trim();
    if (title.isEmpty || _isSaving) return;

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final provider = context.read<TaskProvider>();

    // A subtask typed but not yet added would be lost on save.
    if (_subtaskController.text.trim().isNotEmpty) _addSubtask();

    setState(() => _isSaving = true);
    try {
      if (_editing) {
        // Start from the live copy so focus time, completion and series
        // fields written elsewhere are kept.
        final current = provider.byId(widget.task!.id) ?? widget.task!;
        await provider.updateTask(
          current.copyWith(
            title: title,
            description: _descriptionController.text.trim(),
            deadline: _deadline,
            priority: _priority,
            category: _category(_userCategories(user)),
            estimatedMinutes: _minutes,
            reminderMinutesBefore: _reminder,
            clearReminder: _reminder == null,
            subtasks: _subtasks,
          ),
        );
      } else {
        final task = Task(
          id: provider.newTaskId(),
          userId: user.uid,
          title: title,
          description: _descriptionController.text.trim(),
          deadline: _deadline,
          priority: _priority,
          category: _category(_userCategories(user)),
          estimatedMinutes: _minutes,
          createdAt: DateTime.now(),
          reminderMinutesBefore: _reminder,
          subtasks: _subtasks,
        );
        if (_repeats && _rule.isRecurring) {
          await provider.addRecurringTask(task, _rule);
        } else {
          await provider.addTask(task);
        }
      }
      if (!mounted) return;
      showMessage(context, _editing ? 'Task updated' : (_repeats ? 'Repeating task created' : 'Task added'));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final userCategories = _userCategories(user);
    final selectedCategory = _category(userCategories);
    final categories = <String>[
      ...userCategories,
      if (!userCategories.contains(selectedCategory)) selectedCategory,
    ];
    final durations = {..._durationChoices, _minutes}.toList()..sort();
    final titleError = _attempted && _titleController.text.trim().isEmpty ? 'Give the task a name.' : null;
    final inPast = _deadline.isBefore(DateTime.now());
    final reminderChoices = [
      ..._reminderChoices,
      if (_reminder != null && !_reminderChoices.any((c) => c.$1 == _reminder)) (_reminder, _reminderLabel(_reminder!)),
    ];

    return Scaffold(
      bottomNavigationBar: BottomActionBar(
              child: GradientButton(
                label: _editing ? 'Save changes' : 'Add task',
                loading: _isSaving,
                onPressed: _save,
              ),
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: _editing ? 'Edit Task' : 'Add Task'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 24),
                children: [
                  LabeledField(
                    label: 'Task name',
                    hint: 'e.g. Research paper',
                    controller: _titleController,
                    icon: Icons.edit_outlined,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLength: 100,
                    errorText: titleError,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Description (optional)',
                    hint: 'What needs to be done?',
                    controller: _descriptionController,
                    maxLines: 3,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: PickerField(
                          label: 'Deadline',
                          value: DateFormat('MMM d, yyyy').format(_deadlineDate),
                          icon: Icons.calendar_today_outlined,
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: PickerField(
                          label: 'Time',
                          value: _deadlineTime.format(context),
                          icon: Icons.access_time,
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                  if (inPast)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: readableOn(context.cs.error, context.cs.surface)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'This deadline has passed, so the task will show as overdue.',
                              style: context.label.copyWith(color: readableOn(context.cs.error, context.cs.surface)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  const SectionLabel('Estimated time'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in durations)
                        PillChip(label: _formatMinutes(m), selected: _minutes == m, onTap: () => setState(() => _minutes = m)),
                      PillChip(label: 'Custom…', selected: false, onTap: _pickCustomDuration),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SectionLabel('Priority'),
                  Row(
                    children: [
                      for (final p in [3, 2, 1]) ...[
                        Expanded(
                          child: _PriorityOption(
                            priority: p,
                            selected: _priority == p,
                            onTap: () => setState(() => _priority = p),
                          ),
                        ),
                        if (p != 1) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SectionLabel('Category'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in categories)
                        PillChip(label: c, selected: selectedCategory == c, onTap: () => setState(() => _categoryChoice = c)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SectionLabel('Reminder'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (value, label) in reminderChoices)
                        PillChip(label: label, selected: _reminder == value, onTap: () => setState(() => _reminder = value)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!_editing) ...[
                    SwitchRow(
                      icon: Icons.repeat,
                      title: 'Repeat',
                      subtitle: 'Create this task on several days.',
                      value: _repeats,
                      onChanged: (v) => setState(() {
                        _repeats = v;
                        if (v && !_rule.isRecurring) _rule = const RecurrenceRule(frequency: RecurrenceFrequency.weekly);
                      }),
                    ),
                    if (_repeats) ...[
                      const SizedBox(height: 12),
                      AppCard(
                        child: RecurrenceRulePicker(
                          value: _rule.frequency == RecurrenceFrequency.weekly && _rule.daysOfWeek.isEmpty
                              ? _rule.copyWith(daysOfWeek: {_deadlineDate.weekday})
                              : _rule,
                          firstDate: _deadlineDate,
                          onChanged: (r) => setState(() => _rule = r),
                        ),
                      ),
                    ],
                  ] else if (widget.task!.isRecurring)
                    Row(
                      children: [
                        Icon(Icons.repeat, size: 16, color: context.cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Part of a repeating series. Changes here only affect this occurrence.',
                            style: context.label,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  const SectionLabel('Subtasks'),
                  for (var i = 0; i < _subtasks.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.only(left: 14, right: 4),
                        radius: AppRadius.sm,
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(_subtasks[i].title, style: context.body),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove subtask',
                              icon: Icon(Icons.close, size: 20, color: context.cs.onSurfaceVariant),
                              onPressed: () => setState(() => _subtasks.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  LabeledFieldInline(
                    controller: _subtaskController,
                    hint: 'Add a step…',
                    onAdd: _addSubtask,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text field with an attached "add" button, used for subtasks.
class LabeledFieldInline extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onAdd;

  const LabeledFieldInline({super.key, required this.controller, required this.hint, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: context.cs.outline, width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onAdd(),
              style: context.body.copyWith(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: context.bodyMuted,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Add subtask',
            icon: Icon(Icons.add_circle, color: context.primary),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _PriorityOption extends StatelessWidget {
  final int priority;
  final bool selected;
  final VoidCallback onTap;

  const _PriorityOption({required this.priority, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(priority);
    final background = Color.alphaBlend(color.withValues(alpha: 0.14), context.cs.surfaceContainer);
    return Semantics(
      button: true,
      selected: selected,
      label: '${Task.priorityLabel(priority)} priority',
      child: Material(
        color: selected ? color.withValues(alpha: 0.14) : context.cs.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: selected ? color : context.cs.outline, width: 1.5),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(
                Task.priorityLabel(priority),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: selected ? readableOn(color, background) : context.cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for a custom estimate in minutes. Owns its controller (see the note on
/// the login screen's reset dialog).
class _CustomDurationDialog extends StatefulWidget {
  final int initialMinutes;
  const _CustomDurationDialog({required this.initialMinutes});

  @override
  State<_CustomDurationDialog> createState() => _CustomDurationDialogState();
}

class _CustomDurationDialogState extends State<_CustomDurationDialog> {
  late final _controller = TextEditingController(text: '${widget.initialMinutes}');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < _minMinutes || value > _maxMinutes) {
      setState(() => _error = 'Enter $_minMinutes to $_maxMinutes minutes.');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Estimated time'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
        decoration: InputDecoration(labelText: 'Minutes', errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Set')),
      ],
    );
  }
}
