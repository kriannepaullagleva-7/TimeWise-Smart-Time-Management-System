import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import 'appearance_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingPhoto = false;

  // Mock settings state for the UI
  bool _taskReminders = true;
  bool _scheduleAlerts = true;
  bool _aiSuggestions = true;

  Future<void> _pickAndUploadPhoto(UserModel user) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final ref = FirebaseStorage.instance.ref('profile_images/${user.uid}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();

      if (!mounted) return;
      await context.read<AuthProvider>().updateProfile(
            user.copyWith(profileImageUrl: url),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not upload photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _editWakeSleepTimes(UserModel user) async {
    TimeOfDay wake = _parseTime(user.wakeTime);
    TimeOfDay sleep = _parseTime(user.sleepTime);

    final result = await showDialog<Map<String, TimeOfDay>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Sleep Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Wake time', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(wake.format(context), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: wake);
                  if (picked != null) setDialogState(() => wake = picked);
                },
              ),
              ListTile(
                title: const Text('Sleep time', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(sleep.format(context), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: sleep);
                  if (picked != null) setDialogState(() => sleep = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {'wake': wake, 'sleep': sleep}),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final wakeStr = _formatTime(result['wake']!);
    final sleepStr = _formatTime(result['sleep']!);

    if (!mounted) return;
    await context.read<AuthProvider>().updateProfile(
          user.copyWith(wakeTime: wakeStr, sleepTime: sleepStr),
        );
  }

  Future<void> _manageCategories(UserModel user) async {
    final categories = List<String>.from(user.categories);
    final controller = TextEditingController();

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Task Categories', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  children: categories
                      .map((c) => Chip(
                            label: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            side: BorderSide.none,
                            onDeleted: categories.length > 1
                                ? () => setDialogState(() => categories.remove(c))
                                : null,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'New category',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainer,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () {
                          final value = controller.text.trim();
                          if (value.isNotEmpty && !categories.contains(value)) {
                            setDialogState(() {
                              categories.add(value);
                              controller.clear();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, categories),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    if (!mounted) return;
    await context.read<AuthProvider>().updateProfile(user.copyWith(categories: result));
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // Background Gradient effect from Figma
          Positioned(
            top: -100,
            left: 0,
            right: 0,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.5),
                  radius: 1.0,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Header
                  const SizedBox(height: 16),
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.btnGradient,
                          ),
                          child: user.profileImageUrl != null
                              ? ClipOval(child: Image.network(user.profileImageUrl!, fit: BoxFit.cover))
                              : Center(
                                  child: Text(
                                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                                  ),
                                ),
                        ),
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: GestureDetector(
                            onTap: _isUploadingPhoto ? null : () => _pickAndUploadPhoto(user),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.colorScheme.outline, width: 2),
                              ),
                              child: _isUploadingPhoto
                                  ? const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                    )
                                  : const Icon(Icons.edit, size: 14, color: AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name.isEmpty ? 'User' : user.name,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'TimeWise Member',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                  const SizedBox(height: 24),

                  // Productivity Stats
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('🔥', '87%', 'Completion')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatCard('🎯', '7', 'Day Streak')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatCard('⏱️', '24h', 'Focus Time')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Notifications
                  _buildSectionLabel('NOTIFICATIONS'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Column(
                      children: [
                        _buildToggleRow('⏰', 'Task Reminders', _taskReminders, (v) => setState(() => _taskReminders = v)),
                        _buildDivider(),
                        _buildToggleRow('📅', 'Schedule Alerts', _scheduleAlerts, (v) => setState(() => _scheduleAlerts = v)),
                        _buildDivider(),
                        _buildToggleRow('✨', 'AI Suggestions', _aiSuggestions, (v) => setState(() => _aiSuggestions = v), isLast: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // AI & Schedule Preferences
                  _buildSectionLabel('PREFERENCES'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Column(
                      children: [
                        _buildNavRow('Sleep Schedule', '${user.wakeTime} - ${user.sleepTime}', onTap: () => _editWakeSleepTimes(user)),
                        _buildDivider(),
                        _buildNavRow('Task Categories', '${user.categories.length} custom', onTap: () => _manageCategories(user), isLast: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // App Settings
                  _buildSectionLabel('APP SETTINGS'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Column(
                      children: [
                        _buildNavRow('Appearance', '', icon: '🎨', onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AppearanceScreen()));
                        }),
                        _buildDivider(),
                        _buildNavRow('About TimeWise', 'v2.0', icon: 'ℹ️', isLast: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account
                  _buildSectionLabel('ACCOUNT'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Column(
                      children: [
                        _buildNavRow('Google Account', 'Connected', icon: '👤'),
                        _buildDivider(),
                        _buildNavRow('Log Out', '', icon: '🚪', isDanger: true, onTap: () async {
                          await context.read<AuthProvider>().signOut();
                        }, isLast: true),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  Text(
                    'TimeWise v2.0 · Smart Time Management',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Theme.of(context).colorScheme.outline);
  }

  Widget _buildToggleRow(String emoji, String label, bool value, ValueChanged<bool> onChanged, {bool isLast = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow(String label, String value, {String? icon, bool isDanger = false, bool isLast = false, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final color = isDanger ? const Color(0xFFEF4444) : theme.colorScheme.onSurface;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(isLast ? 20 : 0),
        bottomRight: Radius.circular(isLast ? 20 : 0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (icon != null) ...[
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }
}
