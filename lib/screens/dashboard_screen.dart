import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../models/task.dart';
import '../../models/schedule.dart';
import '../../theme/app_colors.dart';
import 'tasks/add_task_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigateToTab;

  const DashboardScreen({super.key, required this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _aiController = TextEditingController();
  bool _aiLoading = false;
  String _aiReply = '';

  final List<String> _aiReplies = [
    "I've analyzed your tasks. I suggest studying Research Paper from 10:45 AM – 12:15 PM during your peak focus window, then Flutter Project at 3:15 PM after your class.",
    "Based on your schedule, you have 2.5 hours free this afternoon. I recommend tackling Math Problem Set at 9:30 PM after your lab session ends.",
    "You have 3 high-priority tasks due tomorrow. Your most productive block is 10 AM – 12 PM — I've reserved it for Research Paper.",
  ];

  @override
  void dispose() {
    _aiController.dispose();
    super.dispose();
  }

  void _handleAsk() {
    if (_aiController.text.trim().isEmpty) return;
    setState(() {
      _aiLoading = true;
      _aiReply = '';
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _aiReply = _aiReplies[math.Random().nextInt(_aiReplies.length)];
          _aiLoading = false;
        });
      }
    });
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 3:
        return const Color(0xFFEF4444);
      case 2:
        return const Color(0xFFF59E0B);
      case 1:
      default:
        return const Color(0xFF10B981);
    }
  }

  Color _getCategoryColor(String category) {
    if (category.toLowerCase() == 'school') return const Color(0xFF6366F1);
    if (category.toLowerCase() == 'work') return const Color(0xFF0EA5E9);
    if (category.toLowerCase() == 'personal') return const Color(0xFF10B981);
    return const Color(0xFF8B5CF6);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.read<AuthProvider>().currentUser;
    final userId = user?.uid ?? '';
    final today = DateTime.now();
    final dayName = DateFormat('EEEE').format(today);
    final dateStr = DateFormat('MMMM d').format(today);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Background Gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -1.2),
                  radius: 1.5,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Greeting
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$dayName, $dateStr',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Good afternoon, ${user?.name.split(' ').first ?? 'User'} 👋',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🔥', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 4),
                            Text(
                              '7',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFCD34D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Progress + Streak row
                  StreamBuilder<List<Task>>(
                    stream: context.read<TaskProvider>().getUserTasksStream(userId),
                    builder: (context, snapshot) {
                      final tasks = snapshot.data ?? [];
                      final todayTasks = tasks.where((t) {
                        return t.deadline.year == today.year &&
                            t.deadline.month == today.month &&
                            t.deadline.day == today.day;
                      }).toList();
                      
                      final completed = todayTasks.where((t) => t.isCompleted).length;
                      final total = todayTasks.length;
                      final pct = total == 0 ? 0 : ((completed / total) * 100).round();

                      return Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: theme.colorScheme.outline),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: total == 0 ? 0 : (completed / total),
                                          backgroundColor: theme.colorScheme.outline,
                                          color: AppColors.primary,
                                          strokeWidth: 5,
                                        ),
                                        Text(
                                          '$pct%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TODAY',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$completed/$total Tasks',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Completed',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: theme.colorScheme.outline),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'STREAK',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '7',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: theme.colorScheme.onSurface,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        '🔥 days',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].asMap().entries.map((entry) {
                                      int idx = entry.key;
                                      String d = entry.value;
                                      bool active = idx < 6;
                                      return Expanded(
                                        child: Column(
                                          children: [
                                            Container(
                                              height: 6,
                                              margin: const EdgeInsets.symmetric(horizontal: 1),
                                              decoration: BoxDecoration(
                                                color: active ? const Color(0xFFF59E0B) : theme.colorScheme.outline,
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              d,
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // AI Assistant Card
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.btnGradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: const Text('✨', style: TextStyle(fontSize: 14)),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'AI ASSISTANT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          if (_aiReply.isNotEmpty) ...[
                            Text(
                              _aiReply,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => widget.onNavigateToTab(2),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(alpha: 0.22),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    child: const Text('Add to Schedule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => setState(() { _aiReply = ''; _aiController.clear(); }),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                                    foregroundColor: Colors.white.withValues(alpha: 0.75),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                  child: const Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                          ] else ...[
                            const Text(
                              'You have 3 high-priority tasks due tomorrow. Ask me to help plan your day.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: TextField(
                                    controller: _aiController,
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                    decoration: InputDecoration(
                                      hintText: 'Plan my day, suggest study times...',
                                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                      border: InputBorder.none,
                                    ),
                                    onSubmitted: (_) => _handleAsk(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _handleAsk,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: _aiLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildQuickAction(context, '✅', 'Add Task', () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTaskScreen()));
                      }),
                      const SizedBox(width: 8),
                      _buildQuickAction(context, '📅', 'Schedule', () {
                        widget.onNavigateToTab(2); // Go to schedule
                      }),
                      const SizedBox(width: 8),
                      _buildQuickAction(context, '📆', 'Calendar', () {
                        widget.onNavigateToTab(2);
                      }),
                      const SizedBox(width: 8),
                      _buildQuickAction(context, '👤', 'Profile', () {
                        widget.onNavigateToTab(3);
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Available Today
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'AVAILABLE TODAY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '2.5 hrs free',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF22C55E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildBlock(theme, AppColors.primary)),
                            const SizedBox(width: 4),
                            Expanded(child: _buildBlock(theme, AppColors.secondary)),
                            const SizedBox(width: 4),
                            Expanded(child: _buildBlock(theme, const Color(0xFFF59E0B))),
                            const SizedBox(width: 4),
                            Expanded(child: _buildBlock(theme, const Color(0xFF22C55E))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildLegendItem(AppColors.primary, 'Fixed'),
                            const SizedBox(width: 12),
                            _buildLegendItem(AppColors.secondary, 'AI Task'),
                            const SizedBox(width: 12),
                            _buildLegendItem(const Color(0xFFF59E0B), 'Break'),
                            const SizedBox(width: 12),
                            _buildLegendItem(const Color(0xFF22C55E), 'Free'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Today's Schedule
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Today\'s Schedule',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => widget.onNavigateToTab(2),
                        child: const Text(
                          'View All →',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<ScheduleItem>>(
                    stream: context.read<ScheduleProvider>().getUserScheduleStream(userId, today),
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? [];
                      if (items.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: theme.colorScheme.outline),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'No events scheduled today',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }

                      items.sort((a, b) => a.startTime.compareTo(b.startTime));
                      final todayItems = items.take(4).toList();

                      return Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: Column(
                          children: List.generate(todayItems.length, (index) {
                            final item = todayItems[index];
                            final timeFormat = DateFormat('h:mm a');
                            final isLast = index == todayItems.length - 1;
                            
                            Color typeColor;
                            if (item.isFixed) {
                              typeColor = AppColors.primary;
                            } else if (item.isAISuggested) {
                              typeColor = AppColors.secondary;
                            } else if (item.type == 'break') {
                              typeColor = const Color(0xFFF59E0B);
                            } else {
                              typeColor = const Color(0xFF22C55E);
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                border: isLast ? null : Border(bottom: BorderSide(color: theme.colorScheme.outline)),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 60,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          timeFormat.format(item.startTime),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        Text(
                                          '${item.duration.inMinutes}m',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 4,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: typeColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        if (item.isAISuggested)
                                          Text(
                                            '✨ AI scheduled',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: typeColor,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      item.isFixed ? 'Fixed' : (item.isAISuggested ? 'AI' : (item.type == 'break' ? 'Break' : 'Personal')),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: typeColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Today's Tasks
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Today\'s Tasks',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => widget.onNavigateToTab(1), // Go to Tasks
                        child: const Text(
                          'View All →',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<Task>>(
                    stream: context.read<TaskProvider>().getUserTasksStream(userId),
                    builder: (context, snapshot) {
                      final tasks = snapshot.data ?? [];
                      final todayTasks = tasks.where((t) {
                        return t.deadline.year == today.year &&
                            t.deadline.month == today.month &&
                            t.deadline.day == today.day &&
                            !t.isCompleted;
                      }).toList();

                      todayTasks.sort((a, b) => b.priority.compareTo(a.priority));

                      if (todayTasks.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              const Text('🎉', style: TextStyle(fontSize: 32)),
                              const SizedBox(height: 8),
                              Text(
                                'All tasks done!',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Great job today.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: todayTasks.take(4).map((task) {
                          final pColor = _getPriorityColor(task.priority);
                          final cColor = _getCategoryColor(task.category);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.colorScheme.outline),
                            ),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    context.read<TaskProvider>().updateTask(task.copyWith(isCompleted: !task.isCompleted));
                                  },
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: pColor, width: 2),
                                      color: task.isCompleted ? pColor : Colors.transparent,
                                    ),
                                    alignment: Alignment.center,
                                    child: task.isCompleted
                                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            DateFormat('MMM d').format(task.deadline),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '⏱ ${task.estimatedMinutes}m',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: pColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        task.priorityText,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: pColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: cColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        task.category,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: cColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String emoji, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlock(ThemeData theme, Color color) {
    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
