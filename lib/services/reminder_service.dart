import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../core/format.dart';
import '../models/plan_item.dart';

class ReminderService {
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  bool ready = false;

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    ready = true;
  }

  Future<bool> askPermission() async {
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<void> reschedule(List<PlanItem> items, {
    required bool notificationsEnabled,
    required bool eventNotifications,
    required bool financeNotifications,
    required bool vibration,
  }) async {
    if (!ready) return;
    await plugin.cancelAll();
    if (!notificationsEnabled) return;
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 90));
    final alerts = <({DateTime alarm, PlanItem item, DateTime day})>[];

    for (final item in items) {
      if (!item.reminderEnabled) continue;
      if (item.kind == PlanKind.event && !eventNotifications) continue;
      if (item.kind != PlanKind.event && !financeNotifications) continue;
      final start = item.repeat == RepeatRule.never ? dayOnly(item.start) : dayOnly(now);
      var count = 0;
      for (var day = start; !day.isAfter(maxDate) && count < 90; day = day.add(const Duration(days: 1))) {
        if (!item.occursOn(day)) continue;
        final beginsAt = item.occurrenceAt(day);
        final alarm = beginsAt.subtract(Duration(minutes: item.reminderMinutes));
        if (alarm.isAfter(now)) {
          alerts.add((alarm: alarm, item: item, day: day));
          count++;
        }
        if (item.repeat == RepeatRule.never) break;
      }
    }
    alerts.sort((a, b) => a.alarm.compareTo(b.alarm));
    final selected = alerts.take(230);
    var id = 200;
    for (final alert in selected) {
      final item = alert.item;
      final title = item.kind == PlanKind.event ? '📅 ${item.title}'
          : '${item.kind == PlanKind.income ? '💚 Entrada' : '💸 Saída'}: ${item.title}';
      final description = item.kind == PlanKind.event
          ? '${dateLabel(alert.day)} às ${timeLabel(item.occurrenceAt(alert.day))}'
          : '${money(item.cents)} • ${dateLabel(alert.day)}';
      await plugin.zonedSchedule(
        id: id++,
        title: title,
        body: description,
        scheduledDate: tz.TZDateTime.from(alert.alarm, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            vibration ? 'planner_vibrate_v1' : 'planner_no_vibration_v1',
            'Lembretes do Planner',
            channelDescription: 'Avisos para eventos e movimentações financeiras',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: vibration,
          ),
        ),
        // Avoids the Android SCHEDULE_EXACT_ALARM restricted permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
