import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/schedule.dart';
import '../../providers/schedule_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_styles.dart';
import '../../utils/feedback.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/schedule_item_card.dart';
import '../../widgets/ui.dart';

/// Shows an AI-generated plan before it is saved, so the user can accept
/// it as-is, change the time of a block, drop blocks, or ask for a new plan.
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
  String _busyLabel = 'Working…';

  Future<void> _regenerate() async {
    setState(() {
      _isBusy = true;
      _busyLabel = 'Asking the AI for a new plan…';
    });
    try {
      final regenerated = await widget.onRegenerate();
      if (mounted) setState(() => _items = regenerated);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _accept() async {
    setState(() {
      _isBusy = true;
      _busyLabel = 'Saving your plan…';
    });
    final provider = context.read<ScheduleProvider>();
    final ok = await guarded(
      context,
      () => provider.acceptGeneratedSchedule(widget.userId, widget.scheduleDate, _items),
      successMessage: 'AI plan saved to your calendar',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _isBusy = false);
    }
  }

  void _openMenu(int index) {
    final item = _items[index];
    showAppSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(item.title),
          SheetAction(
            icon: Icons.schedule,
            title: 'Edit time',
            description: 'Change when this block starts and ends',
            onTap: () {
              Navigator.pop(ctx);
              _editTime(index);
            },
          ),
          SheetAction(
            icon: Icons.delete_outline,
            title: 'Remove from plan',
            color: ctx.cs.error,
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _items.removeAt(index));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _editTime(int index) async {
    final item = _items[index];
    var start = TimeOfDay.fromDateTime(item.startTime);
    var end = TimeOfDay.fromDateTime(item.endTime);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String? error;
          final s = start.hour * 60 + start.minute;
          final e = end.hour * 60 + end.minute;
          if (e <= s) {
            error = 'End time must be after start time.';
          } else {
            for (var i = 0; i < _items.length; i++) {
              if (i == index) continue;
              final other = _items[i];
              final os = other.startTime.hour * 60 + other.startTime.minute;
              final oe = other.endTime.hour * 60 + other.endTime.minute;
              if (s < oe && os < e) {
                error = 'Overlaps with "${other.title}".';
                break;
              }
            }
          }
          return AlertDialog(
            title: const Text('Edit time'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PickerField(
                  label: 'Start time',
                  value: start.format(ctx),
                  icon: Icons.access_time,
                  onTap: () async {
                    final p = await showTimePicker(context: ctx, initialTime: start);
                    if (p != null) setDialogState(() => start = p);
                  },
                ),
                const SizedBox(height: 12),
                PickerField(
                  label: 'End time',
                  value: end.format(ctx),
                  icon: Icons.access_time,
                  warn: error != null,
                  helperText: error,
                  onTap: () async {
                    final p = await showTimePicker(context: ctx, initialTime: end);
                    if (p != null) setDialogState(() => end = p);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: error == null ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true || !mounted) return;
    final d = item.startTime;
    setState(() {
      _items[index] = item.copyWith(
        startTime: DateTime(d.year, d.month, d.day, start.hour, start.minute),
        endTime: DateTime(d.year, d.month, d.day, end.hour, end.minute),
      );
      _items.sort((a, b) => a.startTime.compareTo(b.startTime));
    });
  }

  String _summary() {
    final tasks = _items.where((i) => i.taskId != null).map((i) => i.taskId).toSet().length;
    final minutes = _items.fold<int>(0, (sum, i) => sum + i.duration.inMinutes);
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    final total = hours > 0 ? '${hours}h${rest > 0 ? ' ${rest}m' : ''}' : '${rest}m';
    return '${_items.length} blocks · $tasks task${tasks == 1 ? '' : 's'} · $total planned';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMMM d');

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Review AI Plan',
              subtitle: dateFormat.format(widget.scheduleDate),
              onBack: _isBusy ? () {} : () => Navigator.pop(context, false),
              trailing: const IconTile(icon: Icons.auto_awesome, color: AppColors.secondary),
            ),
            Expanded(
              child: _items.isEmpty
                  ? EmptyState(
                      icon: Icons.auto_awesome_mosaic_outlined,
                      title: 'No suggestions generated',
                      subtitle: 'Try again, or go back and adjust your tasks and fixed events first.',
                      action: _isBusy
                          ? const CircularProgressIndicator()
                          : FilledButton.icon(
                              onPressed: _regenerate,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Regenerate'),
                            ),
                    )
                  : Stack(
                      children: [
                        ListView.builder(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 24),
                          itemCount: _items.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: AppCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  radius: AppRadius.md,
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 20, color: context.cs.onSurfaceVariant),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(_summary(), style: context.body.copyWith(fontWeight: FontWeight.w700)),
                                            Text('Tap a block to edit its time or remove it.', style: context.label),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            final i = index - 1;
                            return ScheduleItemCard(item: _items[i], dimPast: false, onTap: _isBusy ? null : () => _openMenu(i));
                          },
                        ),
                        if (_isBusy)
                          Positioned.fill(
                            child: ColoredBox(
                              color: context.cs.surface.withValues(alpha: 0.8),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 14),
                                    Text(_busyLabel, style: context.body),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            if (_items.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.page),
                decoration: BoxDecoration(
                  color: context.cs.surface,
                  border: Border(top: BorderSide(color: context.cs.outline)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: OutlinedButton.icon(
                        onPressed: _isBusy ? null : _regenerate,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Regenerate'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: GradientButton(
                        label: 'Accept Plan',
                        icon: Icons.check,
                        gradient: AppColors.aiGradient,
                        onPressed: _isBusy ? null : _accept,
                      ),
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
