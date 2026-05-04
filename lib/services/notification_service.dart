import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/fridge_item.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'expiry_channel';
  static const _channelName = 'Lejárati figyelmeztetések';

  static const _androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: 'Értesítések közelgő lejáratú termékekről',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _notifDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> init() async {
    tz_data.initializeTimeZones();

    // flutter_timezone v5: getLocalTimezone() → TimezoneInfo (nem String)
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // flutter_local_notifications v21: initialize() – minden paraméter nevesített
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
  }

  static Future<void> scheduleExpiryNotifications(
      List<FridgeItem> items) async {
    await _plugin.cancelAll();
    int id = 0;
    final now = tz.TZDateTime.now(tz.local);

    for (final item in items) {
      if (item.isExpired) continue;
      final days = item.daysUntilExpiry;
      if (days > 3) continue;

      final body = switch (days) {
        0 => '${item.name} ma jár le!',
        1 => '${item.name} holnap jár le!',
        _ => '${item.name} $days napon belül lejár!',
      };

      // Ütemezés: a lejárat napján reggel 8:00-kor
      final targetDay = tz.TZDateTime(
        tz.local,
        item.expiryDate.year,
        item.expiryDate.month,
        item.expiryDate.day,
        8, 0, 0,
      );

      if (targetDay.isBefore(now)) continue;

      // flutter_local_notifications v21: zonedSchedule() – minden paraméter nevesített,
      // uiLocalNotificationDateInterpretation eltávolítva
      await _plugin.zonedSchedule(
        id: id++,
        title: 'Lejárati figyelmeztetés',
        body: body,
        scheduledDate: targetDay,
        notificationDetails: _notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }
}
