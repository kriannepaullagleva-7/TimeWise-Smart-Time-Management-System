import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/schedule.dart';
import '../../providers/schedule_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/schedule_item_card.dart';

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
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEEE, MMMM d');

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
                    onTap: _isBusy ? null : () => Navigator.pop(context, false),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review AI Plan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          dateFormat.format(widget.scheduleDate),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome, color: AppColors.secondary, size: 20),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _items.isEmpty
                  ? EmptyState(
                      icon: Icons.auto_awesome_mosaic,
                      title: 'No suggestions generated',
                      subtitle: 'Try regenerating, or reject and adjust your tasks/fixed events first.',
                      action: ElevatedButton(
                        onPressed: _isBusy ? null : _regenerate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                        ),
                        child: _isBusy 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Regenerate'),
                      ),
                    )
                  : Stack(
                      children: [
                        ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return ScheduleItemCard(
                              item: item,
                              onDelete: () => setState(() => _items.removeAt(index)),
                            );
                          },
                        ),
                        if (_isBusy)
                          Container(
                            color: theme.colorScheme.surface.withValues(alpha: 0.7),
                            child: const Center(
                              child: CircularProgressIndicator(color: AppColors.secondary),
                            ),
                          ),
                      ],
                    ),
            ),

            // Bottom Actions
            if (_items.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(top: BorderSide(color: theme.colorScheme.outline)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Regenerate
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: _isBusy ? null : _regenerate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.colorScheme.outline),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh, size: 18, color: theme.colorScheme.onSurface),
                              const SizedBox(width: 6),
                              Text(
                                'Retry',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Accept
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: _isBusy ? null : _accept,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.secondary, Color(0xFF6366F1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, size: 18, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Accept Plan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
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
