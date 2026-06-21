import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/planning_models.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {},
    );

    // Créer le canal Android
    const androidChannel = AndroidNotificationChannel(
      'planning_ccas',
      'Planning CCAS',
      description: 'Rappels de planning de travail',
      importance: Importance.high,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> scheduleShiftNotifications(
    List<ShiftEntry> shifts,
    NotificationSettings settings,
  ) async {
    // Annuler toutes les notifs existantes
    await _plugin.cancelAll();

    int notifId = 0;

    for (final shift in shifts) {
      if (shift.type != ShiftType.travail) continue;
      if (shift.startTime == null) continue;
      if (shift.date.isBefore(DateTime.now())) continue;

      final shiftStart = DateTime(
        shift.date.year,
        shift.date.month,
        shift.date.day,
        shift.startTime!.hour,
        shift.startTime!.minute,
      );

      // Notification avant la prise de poste
      if (settings.enabledBeforeShift) {
        final notifTime = shiftStart.subtract(
          Duration(minutes: settings.minutesBeforeShift),
        );
        if (notifTime.isAfter(DateTime.now())) {
          await _scheduleNotification(
            id: notifId++,
            title: '🕐 Rappel de prise de poste',
            body: 'Vous travaillez dans ${settings.minutesBeforeShift} minutes - ${shift.timeLabel}',
            scheduledDate: notifTime,
          );
        }
      }

      // Notification la veille
      if (settings.enabledDayBefore) {
        final dayBefore = DateTime(
          shift.date.year,
          shift.date.month,
          shift.date.day - 1,
          settings.dayBeforeTime.hour,
          settings.dayBeforeTime.minute,
        );
        if (dayBefore.isAfter(DateTime.now())) {
          await _scheduleNotification(
            id: notifId++,
            title: '📅 Planning de demain',
            body: 'Demain vous travaillez : ${shift.timeLabel}',
            scheduledDate: dayBefore,
          );
        }
      }
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'planning_ccas',
          'Planning CCAS',
          channelDescription: 'Rappels de planning de travail',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      99999,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'planning_ccas',
          'Planning CCAS',
          importance: Importance.defaultImportance,
        ),
      ),
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}