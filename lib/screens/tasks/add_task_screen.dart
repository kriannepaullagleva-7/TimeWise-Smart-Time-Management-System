import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../models/recurrence.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../widgets/recurrence_rule_picker.dart';

const List<_ReminderOption> _reminderOptions = [
  _ReminderOption(null, 'No reminder'),
  _ReminderOption(15, '15 minutes before'),
  _ReminderOption(60, '1 hour before'),
  _ReminderOption(180, '3 hours before'),
  _ReminderOption(1440, '1 day before'),
];

class _ReminderOption {
  final int? minutes;
  final String label;
  const _ReminderOption(this.minutes, this.label);
}

class AddTaskScreen extends StatefulWidget {
  final Task? task;

  const AddTaskScreen({this.task, super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  late final _titleController = TextEditingController(text: widget.task?.title);
  late final _descriptionController =
      TextEditingController(text: widget.task?.description);
  late final _durationController = TextEditingController(
    text: (widget.task?.estimatedMinutes ?? 60).toString(),
  );
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDeadline =
      widget.task?.deadline ?? DateTime.now().add(const Duration(days: 1));
  late TimeOfDay _selectedTime = widget.task != null
      ? TimeOfDay.fromDateTime(widget.task!.deadline)
      : const TimeOfDay(hour: 18, minute: 0);
  late int _selectedPriority = widget.task?.priority ?? 2;
  late String? _selectedCategory = widget.task?.category;
  late int? _reminderMinutes = widget.task?.reminderMinutesBefore;
  RecurrenceRule _recurrenceRule = RecurrenceRule.none;

  bool get _isEditing => widget.task != null;
  bool get _isEditingSeriesMember => widget.task?.recurrenceId != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadlineDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _selectedDeadline = picked);
    }
  }

  Future<void> _selectDeadlineTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final taskProvider = context.read<TaskProvider>();
    final userId = authProvider.currentUser?.uid ?? '';

    final deadline = DateTime(
      _selectedDeadline.year,
      _selectedDeadline.month,
      _selectedDeadline.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final task = Task(
      id: widget.task?.id ?? taskProvider.newTaskId(),
      userId: userId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      deadline: deadline,
      priority: _selectedPriority,
      category: _selectedCategory ?? 'General',
      estimatedMinutes: int.parse(_durationController.text),
      isCompleted: widget.task?.isCompleted ?? false,
      createdAt: widget.task?.createdAt ?? DateTime.now(),
      reminderMinutesBefore: _reminderMinutes,
    );

    String confirmationMessage;
    if (_isEditing) {
      await taskProvider.updateTask(task);
      confirmationMessage = 'Task updated';
    } else if (_recurrenceRule.isRecurring) {
      await taskProvider.addRecurringTask(task, _recurrenceRule);
      confirmationMessage = 'Repeating task added';
    } else {
      await taskProvider.addTask(task);
      confirmationMessage = 'Task added';
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(confirmationMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final categories = user?.categories ?? kDefaultCategories;
    _selectedCategory ??= categories.contains(widget.task?.category)
        ? widget.task?.category
        : categories.first;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Task' : 'Add Task')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Task Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) return 'Title is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Estimated Duration (minutes)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  final n = int.tryParse(value ?? '');
                  if (n == null) return 'Enter a valid number';
                  if (n <= 0) return 'Duration must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                onChanged: (value) => setState(() => _selectedCategory = value),
                items: categories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Priority', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                selected: {_selectedPriority},
                onSelectionChanged: (Set<int> newSelection) {
                  setState(() => _selectedPriority = newSelection.first);
                },
                segments: const [
                  ButtonSegment(value: 1, label: Text('Low')),
                  ButtonSegment(value: 2, label: Text('Medium')),
                  ButtonSegment(value: 3, label: Text('High')),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Deadline', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDeadlineDate,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18),
                            const SizedBox(width: 8),
                            Text(_selectedDeadline.toString().split(' ')[0]),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _selectDeadlineTime,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 18),
                            const SizedBox(width: 8),
                            Text(_selectedTime.format(context)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Reminder', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                initialValue: _reminderMinutes,
                onChanged: (value) => setState(() => _reminderMinutes = value),
                items: _reminderOptions
                    .map((o) => DropdownMenuItem(value: o.minutes, child: Text(o.label)))
                    .toList(),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_isEditingSeriesMember)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.repeat, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Part of a repeating series (${widget.task!.recurrence.summary}). '
                          'Changes here only affect this occurrence.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )
              else if (!_isEditing)
                RecurrenceRulePicker(
                  value: _recurrenceRule,
                  firstDate: _selectedDeadline,
                  onChanged: (rule) => setState(() => _recurrenceRule = rule),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(_isEditing ? 'Save Changes' : 'Add Task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
