import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/preferences_provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../utils/app_info.dart';
import '../utils/app_logger.dart';
import '../utils/feedback.dart';
import '../widgets/ui.dart';
import 'appearance_screen.dart';

/// Profile tab: account, productivity stats, notification and planning
/// preferences, appearance, and sign-out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingPhoto = false;

  Future<void> _pickAndUploadPhoto(UserModel user) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1024);
    if (picked == null || !mounted) return;

    setState(() => _isUploadingPhoto = true);
    final auth = context.read<AuthProvider>();
    try {
      final ref = FirebaseStorage.instance.ref('profile_images/${user.uid}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      final ok = await auth.updateProfile(user.copyWith(profileImageUrl: url));
      if (mounted) showMessage(context, ok ? 'Profile photo updated' : (auth.errorMessage ?? 'Could not save the photo.'), error: !ok);
    } catch (e, st) {
      AppLogger.error('Profile', 'photo upload failed', e, st);
      if (mounted) showMessage(context, 'Could not upload the photo. Check your connection and try again.', error: true);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  static TimeOfDay _parse(String hhmm) {
    final minutes = UserModel.minutesOf(hhmm, 0);
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  static String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _editSleepSchedule(UserModel user) async {
    var wake = _parse(user.wakeTime);
    var sleep = _parse(user.sleepTime);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final same = wake.hour == sleep.hour && wake.minute == sleep.minute;
          return AlertDialog(
            title: const Text('Sleep schedule'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('The AI planner never schedules anything while you sleep.', style: ctx.bodyMuted),
                const SizedBox(height: 16),
                PickerField(
                  label: 'Wake up',
                  value: wake.format(ctx),
                  icon: Icons.wb_sunny_outlined,
                  onTap: () async {
                    final p = await showTimePicker(context: ctx, initialTime: wake);
                    if (p != null) setDialogState(() => wake = p);
                  },
                ),
                const SizedBox(height: 12),
                PickerField(
                  label: 'Go to sleep',
                  value: sleep.format(ctx),
                  icon: Icons.bedtime_outlined,
                  warn: same,
                  helperText: same ? 'Wake and sleep times must differ.' : null,
                  onTap: () async {
                    final p = await showTimePicker(context: ctx, initialTime: sleep);
                    if (p != null) setDialogState(() => sleep = p);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: same ? null : () => Navigator.pop(ctx, true), child: const Text('Save')),
            ],
          );
        },
      ),
    );
    if (saved != true || !mounted) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(user.copyWith(wakeTime: _hhmm(wake), sleepTime: _hhmm(sleep)));
    if (mounted) showMessage(context, ok ? 'Sleep schedule saved' : (auth.errorMessage ?? 'Could not save.'), error: !ok);
  }

  Future<void> _manageCategories(UserModel user) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _CategoriesDialog(initial: user.categories),
    );
    if (result == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(user.copyWith(categories: result));
    if (mounted) showMessage(context, ok ? 'Categories saved' : (auth.errorMessage ?? 'Could not save.'), error: !ok);
  }

  Future<void> _logOut(AuthProvider auth) async {
    final ok = await confirmAction(
      context,
      title: 'Log out?',
      message: 'You will need to sign in again to see your tasks.',
      confirmLabel: 'Log out',
      destructive: false,
    );
    if (!ok || !mounted) return;
    await context.read<TaskProvider>().cancelAllReminders();
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final prefs = context.watch<PreferencesProvider>();
    final tasks = context.watch<TaskProvider>().tasks;
    final user = auth.currentUser;

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final streak = context.read<TaskProvider>().calculateStreak(tasks);
    final rate = TaskProvider.completionRate(tasks);
    final focusSeconds = TaskProvider.focusSeconds(tasks);
    final focusText = focusSeconds < 3600 ? '${focusSeconds ~/ 60}m' : '${(focusSeconds / 3600).toStringAsFixed(1)}h';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 20, AppSpacing.page, 24),
          children: [
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: context.primaryGradient),
                    clipBehavior: Clip.antiAlias,
                    child: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                        ? Image.network(
                            user.profileImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _Initial(user.name),
                          )
                        : _Initial(user.name),
                  ),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: Tooltip(
                      message: 'Change profile photo',
                      child: Material(
                        color: context.cs.surface,
                        shape: CircleBorder(side: BorderSide(color: context.cs.outline, width: 2)),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _isUploadingPhoto ? null : () => _pickAndUploadPhoto(user),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: _isUploadingPhoto
                                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.5))
                                : Icon(Icons.photo_camera_outlined, size: 20, color: context.primary),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(child: Text(user.name.isEmpty ? 'User' : user.name, style: context.h1)),
            const SizedBox(height: 2),
            Center(
              child: Text(user.email, style: context.bodyMuted),
            ),
            const SizedBox(height: 8),
            Center(child: TintBadge(label: 'Signed in with ${auth.signInMethod}', color: context.primary, icon: Icons.verified_user_outlined)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _Stat(icon: Icons.task_alt, value: '$rate%', label: 'Completion')),
                const SizedBox(width: 8),
                Expanded(child: _Stat(icon: Icons.local_fire_department, value: '$streak', label: 'Day streak')),
                const SizedBox(width: 8),
                Expanded(child: _Stat(icon: Icons.timer_outlined, value: focusText, label: 'Focus time')),
              ],
            ),

            const SizedBox(height: 24),
            const SectionLabel('Notifications'),
            _Group(children: [
              SwitchRow(
                icon: Icons.notifications_active_outlined,
                title: 'Task reminders',
                subtitle: 'Alert before a task is due (set per task)',
                value: prefs.taskReminders,
                onChanged: prefs.setTaskReminders,
              ),
              SwitchRow(
                icon: Icons.auto_awesome,
                title: 'AI planner',
                subtitle: 'Show the AI Schedule card and button',
                value: prefs.aiSuggestions,
                onChanged: prefs.setAiSuggestions,
              ),
            ]),
            const SizedBox(height: 24),
            const SectionLabel('Planning'),
            _Group(children: [
              _NavRow(
                icon: Icons.bedtime_outlined,
                label: 'Sleep schedule',
                value: '${_parse(user.wakeTime).format(context)} – ${_parse(user.sleepTime).format(context)}',
                onTap: () => _editSleepSchedule(user),
              ),
              _NavRow(
                icon: Icons.label_outline,
                label: 'Task categories',
                value: '${user.categories.length}',
                onTap: () => _manageCategories(user),
              ),
            ]),
            const SizedBox(height: 24),
            const SectionLabel('App'),
            _Group(children: [
              _NavRow(
                icon: Icons.palette_outlined,
                label: 'Appearance',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppearanceScreen())),
              ),
              _NavRow(
                icon: Icons.info_outline,
                label: 'About $kAppName',
                value: 'v$kAppVersion',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: kAppName,
                  applicationVersion: 'Version $kAppVersion (build $kAppBuild)',
                  applicationIcon: Image.asset('assets/images/timewise_pet.png', width: 48, height: 48),
                  children: const [
                    SizedBox(height: 12),
                    Text('A smart time-management app for students: tasks, a calendar, focus sessions and an AI schedule planner.'),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),
            const SectionLabel('Account'),
            _Group(children: [
              _NavRow(
                icon: Icons.logout,
                label: 'Log out',
                danger: true,
                onTap: () => _logOut(auth),
              ),
            ]),
            const SizedBox(height: 24),
            Center(child: Text('$kAppName v$kAppVersion', style: context.label)),
          ],
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  final String name;
  const _Initial(this.name);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _Stat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        radius: AppRadius.md,
        child: Column(
          children: [
            Icon(icon, size: 20, color: label == 'Day streak' ? readableOn(AppColors.warning, context.cs.surfaceContainer) : context.primary),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: context.h2)),
            const SizedBox(height: 2),
            Text(label, style: context.label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool danger;
  final VoidCallback onTap;

  const _NavRow({required this.icon, required this.label, this.value, this.danger = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.cs.error : context.primary;
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value',
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        radius: AppRadius.md,
        onTap: onTap,
        child: Row(
          children: [
            IconTile(icon: icon, color: color, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: context.body.copyWith(fontWeight: FontWeight.w700, color: danger ? readableOn(context.cs.error, context.cs.surfaceContainer) : null),
              ),
            ),
            if (value != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Text(value!, style: context.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
              ),
            if (!danger) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 20, color: context.cs.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }
}

/// Add and remove task categories. Pops the new list, or null on Cancel.
class _CategoriesDialog extends StatefulWidget {
  final List<String> initial;
  const _CategoriesDialog({required this.initial});

  @override
  State<_CategoriesDialog> createState() => _CategoriesDialogState();
}

class _CategoriesDialogState extends State<_CategoriesDialog> {
  late final List<String> _categories = List<String>.from(widget.initial);
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _duplicate {
    final value = _controller.text.trim().toLowerCase();
    return value.isNotEmpty && _categories.any((c) => c.toLowerCase() == value);
  }

  void _add() {
    final value = _controller.text.trim();
    if (value.isEmpty || _duplicate) return;
    setState(() {
      _categories.add(value);
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Task categories'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in _categories)
                    InputChip(
                      label: Text(c),
                      onDeleted: _categories.length > 1 ? () => setState(() => _categories.remove(c)) : null,
                      deleteButtonTooltipMessage: 'Remove $c',
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLength: 20,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(
                  labelText: 'New category',
                  errorText: _duplicate ? 'That category already exists.' : null,
                  counterText: '',
                  suffixIcon: IconButton(tooltip: 'Add category', icon: const Icon(Icons.add_circle), onPressed: _add),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _categories), child: const Text('Save')),
      ],
    );
  }
}
