import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:io';
import '../models/index.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialization settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for Android 13+
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    // Request permissions for iOS
    if (Platform.isIOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    _initialized = true;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - can navigate to exam details page
    // This will be handled by the app's navigation system
  }

  /// Schedule a notification for an exam 30 minutes before it starts
  Future<void> scheduleExamNotification({
    required Exam exam,
    required String studentId,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Skip dummy exams
    if (exam.isDummy || exam.examTime.toUpperCase() == 'NAN') {
      return;
    }

    // Get exam start time
    final examStartDateTime = exam.getExamStartDateTime();
    if (examStartDateTime == null) {
      return;
    }

    // Calculate notification time (30 minutes before exam)
    final notificationTime = examStartDateTime.subtract(const Duration(minutes: 30));
    final now = DateTime.now();

    // Only schedule if notification time is in the future
    if (notificationTime.isBefore(now)) {
      return;
    }

    // Use exam ID as notification ID to avoid duplicates
    final notificationId = exam.id.hashCode;

    // Cancel any existing notification for this exam
    await cancelNotification(notificationId);

    // Create notification details
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'exam_reminders',
      'Exam Reminders',
      channelDescription: 'Notifications for upcoming exams',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Convert notification time to timezone-aware DateTime
    final scheduledDate = tz.TZDateTime.from(notificationTime, tz.local);

    // Schedule the notification
    await _notifications.zonedSchedule(
      notificationId,
      'Upcoming Exam: ${exam.title}',
      'Your ${exam.subject} exam starts in 30 minutes!',
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(int notificationId) async {
    await _notifications.cancel(notificationId);
  }

  /// Cancel all exam notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Schedule notifications for all upcoming exams
  Future<void> scheduleNotificationsForExams({
    required List<Exam> exams,
    required String studentId,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Cancel all existing notifications first
    await cancelAllNotifications();

    final now = DateTime.now();

    for (final exam in exams) {
      // Skip dummy exams
      if (exam.isDummy || exam.examTime.toUpperCase() == 'NAN') {
        continue;
      }

      final examStartDateTime = exam.getExamStartDateTime();
      if (examStartDateTime == null) {
        continue;
      }

      // Only schedule for upcoming exams
      if (examStartDateTime.isAfter(now)) {
        await scheduleExamNotification(
          exam: exam,
          studentId: studentId,
        );
      }
    }
  }

  /// Show an immediate notification (for testing)
  Future<void> showTestNotification() async {
    if (!_initialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'exam_reminders',
      'Exam Reminders',
      channelDescription: 'Notifications for upcoming exams',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999,
      'Test Notification',
      'This is a test notification for exam reminders',
      notificationDetails,
    );
  }
}

