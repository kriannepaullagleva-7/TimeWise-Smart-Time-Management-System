import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/schedule.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/empty_state.dart';

/// Shows an AI-generated plan before it is saved, so the user can accept
/// it as-is, drop individual items, or regenerate/reject the whole thing.
class AIedSchedulePreviewScreen extends StatefulWidget {
  final String userId;
  final DateTime scheduleDate;
  final List<ScheduleItem> initialItems;
  final Future<List<ScheduleItem>> Function() onRegenerate;

  const AIedSchedulePreviewScreen({
    required this.userId,
    required this.scheduleDate,
    required this.initialItems,
    required this.onRegenerate,
    super.key,
  });

  @override
  State<AIedSchedulePreviewScreen> createState() => _AIedSchedulePreviewScreenState();
}

class _AIedSchedulePreviewScreenState extends State<AIedSchedulePreviewScreen> {
  late List<ScheduleItem> _items = List.of(widget.initialItems);
  bool _isBusy = false;

  Future<void> _regenerate() async {
    setState(() => _isBusy = true);
    try {
      final regenerated = await widget.onRegenerate();
      setState(() => _items = regenerated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _accept() async {
    setState(() => _isBusy = true);
    try {
      await context.read<ScheduleProvider>().acceptGeneratedSchedule(
            widget.userId,
            widget.scheduleDate,
            _items,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review AI Schedule'),
      ),
      body: _items.isEmpty
          ? const EmptyState(
              icon: Icons.auto_awesome,
              title: 'No suggestions generated',
              subtitle: 'Try regenerating, or reject and adjust your tasks/fixed events first.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${timeFormat.format(item.startTime)} - ${timeFormat.format(item.endTime)} · ${item.type}'),
                        if (item.note != null && item.note!.isNotEmpty)
                          Text(item.note!, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Remove from plan',
                      onPressed: () => setState(() => _items.removeAt(index)),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isBusy ? null : () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isBusy ? null : _regenerate,
                  icon: _isBusy
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: const Text('Regenerate'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isBusy || _items.isEmpty ? null : _accept,
                  icon: const Icon(Icons.check),
                  label: const Text('Accept'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
