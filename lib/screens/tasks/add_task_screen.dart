import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../models/recurrence.dart';
import '../../models/task.dart';
import '../../theme/app_colors.dart';
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

  late DateTime _selectedDeadline =
      widget.task?.deadline ?? DateTime.now().add(const Duration(days: 1));
  late TimeOfDay _selectedTime = widget.task != null
      ? TimeOfDay.fromDateTime(widget.task!.deadline)
      : const TimeOfDay(hour: 18, minute: 0);
  
  late int _selectedPriority = widget.task?.priority ?? 2;
  late String _selectedCategory = widget.task?.category ?? 'School';
  late int? _reminderMinutes = widget.task?.reminderMinutesBefore;
  RecurrenceRule _recurrenceRule = RecurrenceRule.none;
  late bool _recurring = widget.task?.recurrenceId != null;

  bool _submitted = false;

  bool get _isEditing => widget.task != null;
  bool get _isEditingSeriesMember => widget.task?.recurrenceId != null;

  final List<String> _categories = ['School', 'Work', 'Personal', 'Fitness', 'Other'];

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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDeadline = picked);
    }
  }

  Future<void> _selectDeadlineTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final duration = int.tryParse(_durationController.text) ?? 60;

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
      title: title,
      description: _descriptionController.text.trim(),
      deadline: deadline,
      priority: _selectedPriority,
      category: _selectedCategory,
      estimatedMinutes: duration,
      isCompleted: widget.task?.isCompleted ?? false,
      createdAt: widget.task?.createdAt ?? DateTime.now(),
      reminderMinutesBefore: _reminderMinutes,
    );

    if (_isEditing) {
      await taskProvider.updateTask(task);
    } else if (_recurring && _recurrenceRule.isRecurring) {
      await taskProvider.addRecurringTask(task, _recurrenceRule);
    } else {
      await taskProvider.addTask(task);
    }

    if (mounted) {
      setState(() => _submitted = true);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 3: return const Color(0xFFEF4444);
      case 2: return const Color(0xFFF59E0B);
      default: return const Color(0xFF22C55E);
    }
  }

  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 3: return 'High';
      case 2: return 'Medium';
      default: return 'Low';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_submitted) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  gradient: AppColors.btnGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                _isEditing ? 'Task Updated!' : 'Task Added!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '"${_titleController.text.trim()}" has been saved.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit Task' : 'Add New Task',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFormField(
                      label: 'Task Name',
                      hint: 'e.g. Research Paper',
                      controller: _titleController,
                      onChanged: (v) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      label: 'Description',
                      hint: 'What needs to be done?',
                      controller: _descriptionController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Grid for Date & Time
                    Row(
                      children: [
                        Expanded(
                          child: _buildFormField(
                            label: 'Deadline',
                            hint: DateFormat('MMM d, yyyy').format(_selectedDeadline),
                            icon: Icons.calendar_today,
                            onTap: _selectDeadlineDate,
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFormField(
                            label: 'Time',
                            hint: _selectedTime.format(context),
                            icon: Icons.access_time,
                            onTap: _selectDeadlineTime,
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    _buildFormField(
                      label: 'Duration (mins)',
                      hint: 'e.g. 60',
                      icon: Icons.timer_outlined,
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Priority
                    Text(
                      'PRIORITY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [3, 2, 1].map((p) {
                        final isSelected = _selectedPriority == p;
                        final color = _getPriorityColor(p);
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedPriority = p),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(right: p == 1 ? 0 : 8),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? color.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? color : theme.colorScheme.outline,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _getPriorityLabel(p),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Category
                    Text(
                      'CATEGORY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((c) {
                        final isSelected = _selectedCategory == c;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : theme.colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : theme.colorScheme.outline,
                              ),
                            ),
                            child: Text(
                              c,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Reminder
                    _buildDropdownField(
                      label: 'Reminder',
                      icon: Icons.notifications_none,
                      value: _reminderMinutes,
                      items: _reminderOptions.map((o) {
                        return DropdownMenuItem(value: o.minutes, child: Text(o.label));
                      }).toList(),
                      onChanged: (val) => setState(() => _reminderMinutes = val),
                    ),
                    const SizedBox(height: 16),

                    // Recurring Box
                    if (!_isEditing)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recurring Task',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Repeat this task automatically',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                CupertinoSwitch(
                                  value: _recurring,
                                  onChanged: (v) => setState(() {
                                    _recurring = v;
                                    if (v && _recurrenceRule == RecurrenceRule.none) {
                                      _recurrenceRule = const RecurrenceRule(frequency: RecurrenceFrequency.weekly);
                                    }
                                  }),
                                  activeTrackColor: AppColors.primary,
                                ),
                              ],
                            ),
                            if (_recurring) ...[
                              const SizedBox(height: 16),
                              RecurrenceRulePicker(
                                value: _recurrenceRule,
                                firstDate: _selectedDeadline,
                                onChanged: (r) => setState(() => _recurrenceRule = r),
                              ),
                            ],
                          ],
                        ),
                      )
                    else if (_isEditingSeriesMember)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.repeat, size: 20, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Part of a repeating series. Changes here only affect this occurrence.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 16),

                    // Subtasks dummy placeholder
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SUBTASKS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '+ Add',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline,
                          style: BorderStyle.none,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.list, size: 16, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Text(
                            'Break this task into subtasks',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Submit Button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: _titleController.text.trim().isNotEmpty ? AppColors.btnGradient : null,
                        color: _titleController.text.trim().isNotEmpty ? null : theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _titleController.text.trim().isNotEmpty
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _titleController.text.trim().isNotEmpty ? _save : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            child: Text(
                              _isEditing ? 'Save Changes' : 'Add Task',
                              style: TextStyle(
                                color: _titleController.text.trim().isNotEmpty ? Colors.white : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    TextEditingController? controller,
    IconData? icon,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
    TextInputType? keyboardType,
    Function(String)? onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                const SizedBox(width: 16),
                Icon(icon, size: 18, color: AppColors.primary.withValues(alpha: 0.7)),
              ],
              Expanded(
                child: TextFormField(
                  controller: controller,
                  readOnly: readOnly,
                  onTap: onTap,
                  maxLines: maxLines,
                  keyboardType: keyboardType,
                  onChanged: onChanged,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: maxLines > 1 ? 16 : 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary.withValues(alpha: 0.7)),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value: value,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down, color: theme.colorScheme.onSurfaceVariant),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    items: items,
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
