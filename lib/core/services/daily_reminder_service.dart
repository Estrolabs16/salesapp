import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class DailyReminderService {
  DailyReminderService._();

  static const _channelId = 'estroshop_daily_reminders';
  static const _channelName = 'Daily reminders';
  static const _channelDescription =
      'Gentle reminders to record sales and keep your books tidy.';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final dynamic localZone = await FlutterTimezone.getLocalTimezone();
        final String zoneName =
            localZone is String ? localZone : localZone.identifier as String;
        tz.setLocalLocation(tz.getLocation(zoneName));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      );
      await _plugin.initialize(initSettings);

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);

      await _scheduleDailyReminders();
      _initialized = true;
    } catch (_) {
      // Never let notification setup crash app startup.
    }
  }

  static Future<void> _scheduleDailyReminders() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    const reminders = <_Reminder>[
      _Reminder(
        id: 7001,
        hour: 8,
        minute: 0,
        title: 'Good morning',
        body: "Open EstroShop and record yesterday's takings.",
      ),
      _Reminder(
        id: 7002,
        hour: 13,
        minute: 0,
        title: 'Midday check',
        body: "Log today's sales and restock low items.",
      ),
      _Reminder(
        id: 7003,
        hour: 19,
        minute: 0,
        title: 'End of day',
        body: "Close today's sales — review profit and expenses.",
      ),
    ];

    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        reminder.id,
        reminder.title,
        reminder.body,
        _nextInstanceOf(reminder.hour, reminder.minute),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

class _Reminder {
  const _Reminder({
    required this.id,
    required this.hour,
    required this.minute,
    required this.title,
    required this.body,
  });

  final int id;
  final int hour;
  final int minute;
  final String title;
  final String body;
}
