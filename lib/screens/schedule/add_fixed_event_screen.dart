import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/recurrence.dart';
import '../../models/schedule.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/recurrence_rule_picker.dart';

class AddFixedEventScreen extends StatefulWidget {
  final DateTime date;

  const AddFixedEventScreen({required this.date, super.key});

  @override
  State<AddFixedEventScreen> createState() => _AddFixedEventScreenState();
}

class _AddFixedEventScreenState extends State<AddFixedEventScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  late DateTime _selectedDate = widget.date;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  String _category = ScheduleTypes.class_;
  bool _isFixed = true;
  bool _isRecurring = false;
  RecurrenceRule _recurrenceRule = RecurrenceRule.none;
  bool _submitted = false;

  final List<String> _categories = [
    ScheduleTypes.class_,
    ScheduleTypes.work,
    ScheduleTypes.appointment,
    ScheduleTypes.personal,
    ScheduleTypes.travel,
  ];

  String _formatCategory(String c) {
    if (c == ScheduleTypes.class_) return 'School';
    if (c == ScheduleTypes.personal) return 'Personal';
    return c[0].toUpperCase() + c.substring(1);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
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
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  DateTime _combine(TimeOfDay time) {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final start = _combine(_startTime);
    final end = _combine(_endTime);

    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    final userId = context.read<AuthProvider>().currentUser?.uid ?? '';

    try {
      // The backend addFixedEvent uses the title, start, end, type, recurrence.
      // note parameter doesn't exist in addFixedEvent based on original file, but we can pass it if we add it to the provider. 
      // The instructions say "Preserve existing Models" so we won't alter the provider signature here if it doesn't support notes.
      await context.read<ScheduleProvider>().addFixedEvent(
            userId: userId,
            title: title,
            startTime: start,
            endTime: end,
            type: _category,
            recurrence: _isRecurring ? _recurrenceRule : RecurrenceRule.none,
          );
      
      if (mounted) {
        setState(() => _submitted = true);
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFEF4444)),
        );
      }
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
                'Schedule Saved!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
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
                      'Add Schedule',
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
                      label: 'Activity Name',
                      hint: 'e.g. CS101 Class',
                      controller: _titleController,
                      icon: Icons.bookmark_border,
                      onChanged: (v) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    _buildFormField(
                      label: 'Date',
                      hint: DateFormat('MMMM d, yyyy').format(_selectedDate),
                      icon: Icons.calendar_today,
                      onTap: _pickDate,
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildFormField(
                            label: 'Start Time',
                            hint: _startTime.format(context),
                            icon: Icons.access_time,
                            onTap: () => _pickTime(true),
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFormField(
                            label: 'End Time',
                            hint: _endTime.format(context),
                            icon: Icons.access_time,
                            onTap: () => _pickTime(false),
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

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
                        final isSelected = _category == c;
                        return GestureDetector(
                          onTap: () => setState(() => _category = c),
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
                              _formatCategory(c),
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

                    _buildFormField(
                      label: 'Notes',
                      hint: 'Optional notes...',
                      controller: _notesController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Fixed Schedule
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
                                    'Fixed Schedule',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'AI won\'t schedule tasks during this time',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              CupertinoSwitch(
                                value: _isFixed,
                                onChanged: (v) => setState(() => _isFixed = v),
                                activeTrackColor: AppColors.primary,
                              ),
                            ],
                          ),
                          if (_isFixed) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.only(top: 12),
                              decoration: BoxDecoration(
                                border: Border(top: BorderSide(color: AppColors.primary.withValues(alpha: 0.15))),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_outline, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'This block is protected — AI will plan around it.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Recurring
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recurring Event',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              CupertinoSwitch(
                                value: _isRecurring,
                                onChanged: (v) => setState(() {
                                  _isRecurring = v;
                                  if (v && _recurrenceRule == RecurrenceRule.none) {
                                    _recurrenceRule = const RecurrenceRule(frequency: RecurrenceFrequency.weekly);
                                  }
                                }),
                                activeTrackColor: AppColors.primary,
                              ),
                            ],
                          ),
                          if (_isRecurring) ...[
                            const SizedBox(height: 16),
                            RecurrenceRulePicker(
                              value: _recurrenceRule,
                              firstDate: _selectedDate,
                              onChanged: (r) => setState(() => _recurrenceRule = r),
                            ),
                          ],
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
                              'Save Schedule',
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
}
