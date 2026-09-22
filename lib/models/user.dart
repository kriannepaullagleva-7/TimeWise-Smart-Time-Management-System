import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> kDefaultCategories = ['Work', 'Study', 'Personal', 'Health'];

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

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.profileImageUrl,
    required this.createdAt,
    this.categories = kDefaultCategories,
    this.wakeTime = '07:00',
    this.sleepTime = '23:00',
  });

  UserModel copyWith({
    String? name,
    String? profileImageUrl,
    List<String>? categories,
    String? wakeTime,
    String? sleepTime,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      name: name ?? this.name,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt,
      categories: categories ?? this.categories,
      wakeTime: wakeTime ?? this.wakeTime,
      sleepTime: sleepTime ?? this.sleepTime,
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
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      categories: List<String>.from(map['categories'] ?? kDefaultCategories),
      wakeTime: map['wakeTime'] ?? '07:00',
      sleepTime: map['sleepTime'] ?? '23:00',
    );
  }
}
