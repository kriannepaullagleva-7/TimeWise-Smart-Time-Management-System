import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../utils/app_logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static const _module = 'NotificationService';

  /// Fixed id of the "focus time is up" notification (only one can be pending).
  static const int focusEndId = 424242;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  factory NotificationService() => _instance;

  NotificationService._internal();

  /// Sets the plugin up. It does NOT ask for permission: the system dialog is
  /// shown later, in context, by [ensurePermission] (when the user sets their
  /// first reminder or starts a focus session).
  Future<void> initNotifications() async {
    tzdata.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    _ready = true;
  }

  /// Asks for the notification permission (Android 13+ / iOS). Returns true
  /// when notifications may be shown.
  Future<bool> ensurePermission() async {
    if (!_ready) return false;
    try {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final enabled = await androidPlugin.areNotificationsEnabled();
        if (enabled ?? false) return true;
        return await androidPlugin.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } catch (e) {
      AppLogger.warning(_module, 'Permission request failed', e);
      return false;
    }
  }

  NotificationDetails _details(String channelId, String channelName) => NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          sound: 'default',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  Future<void> scheduleTaskReminder(int id, String taskTitle, DateTime reminderTime) {
    return _schedule(id, 'Task Reminder', taskTitle, reminderTime, _details('task_reminders', 'Task Reminders'));
  }

  /// "Time is up" alert for a focus session that ends at [endsAt].
  Future<void> scheduleFocusEnd(DateTime endsAt, String taskTitle) {
    return _schedule(
      focusEndId,
      'Focus time is up',
      taskTitle,
      endsAt,
      _details('focus_timer', 'Focus Timer'),
    );
  }

  Future<void> cancelFocusEnd() => cancelNotification(focusEndId);

  Future<void> _schedule(int id, String title, String body, DateTime when, NotificationDetails details) async {
    if (!_ready) return;
    final at = tz.TZDateTime.from(when, tz.local);
    try {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          at,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      } on PlatformException catch (e) {
        if (e.code != 'exact_alarms_not_permitted') rethrow;
        // Exact alarms are switched off for the app: an inexact alarm still
        // delivers the reminder, just a little less precisely.
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          at,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      AppLogger.warning(_module, 'Could not schedule notification $id', e);
    }
  }

  Future<void> cancelNotification(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id);
    } catch (e) {
      AppLogger.warning(_module, 'Could not cancel notification $id', e);
    }
  }

  Future<void> cancelAllNotifications() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      AppLogger.warning(_module, 'Could not cancel all notifications', e);
    }
  }

  Future<void> showInstantNotification(String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        _details('instant_notifications', 'Instant Notifications'),
      );
    } catch (e) {
      AppLogger.warning(_module, 'Could not show notification', e);
    }
  }
}
