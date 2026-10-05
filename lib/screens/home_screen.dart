import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/focus_provider.dart';
import '../theme/app_styles.dart';
import '../widgets/ui.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'schedule/add_fixed_event_screen.dart';
import 'schedule/schedule_screen.dart';
import 'tasks/add_task_screen.dart';
import 'tasks/focus_screen.dart';
import 'tasks/tasks_screen.dart';

/// Signed-in shell: four tabs, a center "add" button and, while a focus
/// session exists, a strip that returns to it.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _navigateToTab(int index) {
    if (mounted) setState(() => _selectedIndex = index);
  }

  void _showAddMenu() {
    showAppSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader('Add new'),
          SheetAction(
            icon: Icons.add_task,
            title: 'Task',
            description: 'Something to finish by a deadline',
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTaskScreen()));
            },
          ),
          SheetAction(
            icon: Icons.event_available_outlined,
            title: 'Event',
            description: 'Class, work, appointment or other fixed block',
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => AddFixedEventScreen(date: DateTime.now())));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onNavigateToTab: _navigateToTab),
      const TasksScreen(),
      const ScheduleScreen(),
      const ProfileScreen(),
    ];

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _navigateToTab(0);
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: context.cs.surface,
            border: Border(top: BorderSide(color: context.cs.outline)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _ActiveFocusStrip(),
                SizedBox(
                  height: 68,
                  child: Row(
                    children: [
                      _NavItem(
                        selected: _selectedIndex == 0,
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_filled,
                        label: 'Home',
                        onTap: () => _navigateToTab(0),
                      ),
                      _NavItem(
                        selected: _selectedIndex == 1,
                        icon: Icons.checklist_outlined,
                        activeIcon: Icons.checklist,
                        label: 'Tasks',
                        onTap: () => _navigateToTab(1),
                      ),
                      Expanded(
                        child: Center(
                          child: Semantics(
                            button: true,
                            label: 'Add a task or event',
                            // The shadow lives on the outer box: inside a Material it was
                            // clipped to a visible square around the round button.
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: context.primaryGradient,
                                boxShadow: [
                                  BoxShadow(color: context.primary.withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: Material(
                                type: MaterialType.transparency,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: _showAddMenu,
                                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _NavItem(
                        selected: _selectedIndex == 2,
                        icon: Icons.calendar_month_outlined,
                        activeIcon: Icons.calendar_month,
                        label: 'Calendar',
                        onTap: () => _navigateToTab(2),
                      ),
                      _NavItem(
                        selected: _selectedIndex == 3,
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        label: 'Profile',
                        onTap: () => _navigateToTab(3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.selected,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? readableOn(context.primary, context.cs.surface) : context.cs.onSurfaceVariant;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? context.primary.withValues(alpha: 0.14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(selected ? activeIcon : icon, color: color, size: 24),
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown above the navigation bar while a focus session is running, paused or
/// finished, so the user can always get back to it.
class _ActiveFocusStrip extends StatelessWidget {
  const _ActiveFocusStrip();

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusProvider>();
    if (!focus.hasSession) return const SizedBox.shrink();

    final running = focus.state == FocusState.running;
    final finished = focus.state == FocusState.finished;
    final remaining = focus.remainingSeconds;
    final clock = '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}';
    final status = finished ? 'Session complete' : (running ? '$clock left' : 'Paused · $clock left');

    return Material(
      color: context.primary,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen())),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 8),
            child: Row(
              children: [
                Icon(finished ? Icons.check_circle_outline : Icons.timer_outlined, size: 20, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    focus.currentTask?.title ?? 'Focus session',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
