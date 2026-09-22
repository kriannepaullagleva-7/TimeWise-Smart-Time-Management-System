import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingPhoto = false;

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
          title: const Text('Sleep Schedule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Wake time'),
                trailing: Text(wake.format(context)),
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: wake);
                  if (picked != null) setDialogState(() => wake = picked);
                },
              ),
              ListTile(
                title: const Text('Sleep time'),
                trailing: Text(sleep.format(context)),
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
          title: const Text('Task Categories'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  children: categories
                      .map((c) => Chip(
                            label: Text(c),
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
                        decoration: const InputDecoration(hintText: 'New category'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
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
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, categories),
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
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: user?.profileImageUrl != null
                      ? NetworkImage(user!.profileImageUrl!)
                      : null,
                  child: user?.profileImageUrl == null
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
                if (user != null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _isUploadingPhoto ? null : () => _pickAndUploadPhoto(user),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: _isUploadingPhoto
                            ? const Padding(
                                padding: EdgeInsets.all(4),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              user?.name ?? 'User',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? '',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            if (user != null) ...[
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.bedtime),
                      title: const Text('Sleep Schedule'),
                      subtitle: Text('Wake ${user.wakeTime}  ·  Sleep ${user.sleepTime}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editWakeSleepTimes(user),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.label_outline),
                      title: const Text('Task Categories'),
                      subtitle: Text(user.categories.join(', ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _manageCategories(user),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.calendar_month),
                      title: const Text('Account Created'),
                      trailing: Text(user.createdAt.toString().split(' ')[0]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await context.read<AuthProvider>().signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
