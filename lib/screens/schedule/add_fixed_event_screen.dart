import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/recurrence.dart';
import '../../models/schedule.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/recurrence_rule_picker.dart';

class AddFixedEventScreen extends StatefulWidget {
  final DateTime date;

  const AddFixedEventScreen({required this.date, super.key});

  @override
  State<AddFixedEventScreen> createState() => _AddFixedEventScreenState();
}

class _AddFixedEventScreenState extends State<AddFixedEventScreen> {
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _type = ScheduleTypes.class_;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  RecurrenceRule _recurrenceRule = RecurrenceRule.none;
  bool _isSaving = false;

  static const _typeLabels = {
    ScheduleTypes.class_: 'Class',
    ScheduleTypes.work: 'Work',
    ScheduleTypes.appointment: 'Appointment',
    ScheduleTypes.travel: 'Travel',
    ScheduleTypes.personal: 'Personal commitment',
  };

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
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
      widget.date.year,
      widget.date.month,
      widget.date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final start = _combine(_startTime);
    final end = _combine(_endTime);

    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    final userId = context.read<AuthProvider>().currentUser?.uid ?? '';
    setState(() => _isSaving = true);

    try {
      await context.read<ScheduleProvider>().addFixedEvent(
            userId: userId,
            title: _titleController.text.trim(),
            startTime: start,
            endTime: end,
            type: _type,
            recurrence: _recurrenceRule,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_recurrenceRule.isRecurring ? 'Repeating event added' : 'Event added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Fixed Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Type', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _type,
                onChanged: (v) => setState(() => _type = v!),
                items: _typeLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Software Engineering Lecture',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime(true),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.access_time, size: 18),
                          const SizedBox(width: 8),
                          Text('Start: ${_startTime.format(context)}'),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime(false),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.access_time_filled, size: 18),
                          const SizedBox(width: 8),
                          Text('End: ${_endTime.format(context)}'),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RecurrenceRulePicker(
                value: _recurrenceRule,
                firstDate: widget.date,
                onChanged: (rule) => setState(() => _recurrenceRule = rule),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Add Event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
