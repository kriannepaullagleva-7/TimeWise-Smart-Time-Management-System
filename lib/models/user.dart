import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> kDefaultCategories = ['School', 'Work', 'Personal', 'Fitness', 'Other'];

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? profileImageUrl;
  final DateTime createdAt;
  final List<String> categories;

  /// Stored as "HH:mm" (24h). Used by the AI scheduler to avoid placing
  /// activities during sleep.
  final String wakeTime;
  final String sleepTime;

  /// Answers from the onboarding quiz that are not wake/sleep times:
  /// `usage` (School / Work / Personal / mix), `scheduleStyle` (fixed /
  /// flexible / both) and `aiHelp` (minimal / balanced / full). They are
  /// passed to the AI as planning hints.
  final Map<String, String> onboarding;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.profileImageUrl,
    required this.createdAt,
    this.categories = kDefaultCategories,
    this.wakeTime = '07:00',
    this.sleepTime = '23:00',
    this.onboarding = const {},
  });

  /// Minutes after midnight for "HH:mm"; falls back to [fallback] when malformed.
  static int minutesOf(String hhmm, int fallback) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return fallback;
    return h * 60 + m;
  }

  int get wakeMinutes => minutesOf(wakeTime, 7 * 60);
  int get sleepMinutes => minutesOf(sleepTime, 23 * 60);

  UserModel copyWith({
    String? name,
    String? email,
    String? profileImageUrl,
    List<String>? categories,
    String? wakeTime,
    String? sleepTime,
    Map<String, String>? onboarding,
  }) {
    return UserModel(
      uid: uid,
      email: email ?? this.email,
      name: name ?? this.name,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt,
      categories: categories ?? this.categories,
      wakeTime: wakeTime ?? this.wakeTime,
      sleepTime: sleepTime ?? this.sleepTime,
      onboarding: onboarding ?? this.onboarding,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'categories': categories,
      'wakeTime': wakeTime,
      'sleepTime': sleepTime,
      'onboarding': onboarding,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final rawOnboarding = map['onboarding'];
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      categories: List<String>.from(map['categories'] ?? kDefaultCategories),
      wakeTime: map['wakeTime'] ?? '07:00',
      sleepTime: map['sleepTime'] ?? '23:00',
      onboarding: rawOnboarding is Map
          ? rawOnboarding.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
    );
  }
}
