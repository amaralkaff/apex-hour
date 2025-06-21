import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'settings_service.dart';

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Notification IDs
  static const int apexHourReminderID = 1;
  static const int workdayEndID = 2;
  static const int deepWorkWarningID = 3;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone database
    tz.initializeTimeZones();

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid = 
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS = 
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    // Combined initialization settings
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin
    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  Future<bool> requestPermissions() async {
    if (!_isInitialized) await initialize();

    // Request permissions on iOS
    final iosImplementation = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      final granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    // Request permissions on Android 13+
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }

    return true; // Assume granted for other platforms
  }

  Future<void> scheduleApexHourReminder() async {
    if (!_isInitialized) await initialize();

    final settings = await SettingsService.instance.getSettings();
    if (!settings.notificationsEnabled) return;

    final now = DateTime.now();
    final apexHourStart = settings.getApexHourStart(now);
    final reminderTime = apexHourStart.subtract(
      Duration(minutes: settings.notificationMinutesBefore)
    );

    // Only schedule if the reminder time is in the future
    if (reminderTime.isAfter(now)) {
      await _scheduleNotification(
        id: apexHourReminderID,
        title: 'Apex Hour Starting Soon',
        body: 'Heads up! Your Apex Hour starts at ${_formatTime(apexHourStart)}. Time to start wrapping up complex problem-solving.',
        scheduledDate: reminderTime,
        channelId: 'apex_hour_reminders',
        channelName: 'Apex Hour Reminders',
        channelDescription: 'Notifications about upcoming Apex Hour',
        importance: Importance.high,
      );
    }
  }

  Future<void> scheduleWorkdayEndReminder() async {
    if (!_isInitialized) await initialize();

    final settings = await SettingsService.instance.getSettings();
    if (!settings.hardStopEnabled) return;

    final now = DateTime.now();
    final workdayEnd = settings.getWorkdayEnd(now);

    // Only schedule if workday end is in the future
    if (workdayEnd.isAfter(now)) {
      await _scheduleNotification(
        id: workdayEndID,
        title: 'Workday Complete',
        body: 'It\'s time to close your IDE. Anything left can be tackled tomorrow. Great job today!',
        scheduledDate: workdayEnd,
        channelId: 'workday_end',
        channelName: 'Workday End',
        channelDescription: 'Hard stop notifications when workday ends',
        importance: Importance.max,
      );
    }
  }

  Future<void> scheduleDeepWorkWarning({
    required DateTime scheduledTime,
    required String taskTitle,
  }) async {
    if (!_isInitialized) await initialize();

    final settings = await SettingsService.instance.getSettings();
    final apexHourStart = settings.getApexHourStart(scheduledTime);
    
    // Warn if deep work is scheduled too close to Apex Hour
    if (scheduledTime.isAfter(apexHourStart.subtract(const Duration(hours: 1)))) {
      await _scheduleNotification(
        id: deepWorkWarningID,
        title: 'Deep Work Scheduling Warning',
        body: 'Task "$taskTitle" is scheduled close to your Apex Hour. Consider moving it to earlier in the day for better energy management.',
        scheduledDate: DateTime.now().add(const Duration(seconds: 2)),
        channelId: 'scheduling_warnings',
        channelName: 'Scheduling Warnings',
        channelDescription: 'Warnings about task scheduling conflicts',
        importance: Importance.defaultImportance,
      );
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required Importance importance,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Failed to schedule exact notification: $e');
      }
      // Fallback to inexact scheduling if exact alarms are not permitted
      if (e.toString().contains('exact_alarms_not_permitted')) {
        try {
          await _notifications.zonedSchedule(
            id,
            title,
            body,
            tz.TZDateTime.from(scheduledDate, tz.local),
            platformChannelSpecifics,
            androidScheduleMode: AndroidScheduleMode.inexact,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
          if (kDebugMode) {
            print('Scheduled inexact notification: $title at $scheduledDate');
          }
        } catch (fallbackError) {
          if (kDebugMode) {
            print('Failed to schedule inexact notification: $fallbackError');
          }
        }
      }
    }

    if (kDebugMode) {
      print('Scheduled notification: $title at $scheduledDate');
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<void> rescheduleAllNotifications() async {
    // Cancel existing notifications
    await cancelAllNotifications();
    
    // Reschedule based on current settings
    await scheduleApexHourReminder();
    await scheduleWorkdayEndReminder();
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    final id = notificationResponse.id;
    
    if (kDebugMode) {
      print('Notification tapped: ID $id, Payload: ${notificationResponse.payload}');
    }

    // Handle different notification types
    switch (id) {
      case apexHourReminderID:
        // User tapped Apex Hour reminder - could navigate to dashboard
        break;
      case workdayEndID:
        // User tapped workday end notification - could show summary
        break;
      case deepWorkWarningID:
        // User tapped scheduling warning - could open task management
        break;
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  // Check if notifications are enabled on device level
  Future<bool> areNotificationsEnabled() async {
    if (!_isInitialized) await initialize();
    
    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      return await androidImplementation.areNotificationsEnabled() ?? false;
    }
    
    // For iOS, we assume they're enabled if initialization was successful
    return true;
  }
}