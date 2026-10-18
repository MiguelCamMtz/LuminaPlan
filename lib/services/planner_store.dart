import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/format.dart';
import '../models/plan_item.dart';
import 'reminder_service.dart';

class PlannerStore extends ChangeNotifier {
  PlannerStore(this.reminders);
  final ReminderService reminders;
  List<PlanItem> items = [];
  Map<String, bool> completedOccurrences = {};
  bool notificationsEnabled = true;
  bool eventNotifications = true;
  bool financeNotifications = true;
  bool vibrationsEnabled = true;
  bool darkTheme = true;
  bool loaded = false;

  void finishLoadingWithDefaults() {
    loaded = true;
    notifyListeners();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final decoded = jsonDecode(prefs.getString('planner_v1') ?? '{}') as Map<String, dynamic>;
      items = ((decoded['items'] as List?) ?? [])
          .map((e) => PlanItem.fromJson(Map<String,dynamic>.from(e as Map)))
          .toList();
      completedOccurrences = Map<String, bool>.from((decoded['completedOccurrences'] as Map?) ?? {});
      notificationsEnabled = decoded['notificationsEnabled'] != false;
      eventNotifications = decoded['eventNotifications'] != false;
      financeNotifications = decoded['financeNotifications'] != false;
      vibrationsEnabled = decoded['vibrationsEnabled'] != false;
      darkTheme = decoded['darkTheme'] != false;
    } catch (_) {
      // Invalid old backup: start empty instead of crashing.
      items = [];
    }
    loaded = true;
    notifyListeners();
    await syncReminders();
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
    'schema': 1,
    'items': items.map((e) => e.toJson()).toList(),
    'completedOccurrences': completedOccurrences,
    'notificationsEnabled': notificationsEnabled,
    'eventNotifications': eventNotifications,
    'financeNotifications': financeNotifications,
    'vibrationsEnabled': vibrationsEnabled,
    'darkTheme': darkTheme,
  });

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('planner_v1', exportJson());
    notifyListeners();
    await syncReminders();
  }

  Future<bool> importJson(String data) async {
    try {
      final parsed = jsonDecode(data) as Map<String, dynamic>;
      if (parsed['schema'] != 1 || parsed['items'] is! List) return false;
      final incoming = (parsed['items'] as List)
          .map((e) => PlanItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      items = incoming;
      completedOccurrences = Map<String, bool>.from((parsed['completedOccurrences'] as Map?) ?? {});
      notificationsEnabled = parsed['notificationsEnabled'] != false;
      eventNotifications = parsed['eventNotifications'] != false;
      financeNotifications = parsed['financeNotifications'] != false;
      vibrationsEnabled = parsed['vibrationsEnabled'] != false;
      darkTheme = parsed['darkTheme'] != false;
      await persist();
      return true;
    } catch (_) { return false; }
  }

  Future<void> upsert(PlanItem item) async {
    final index = items.indexWhere((e) => e.id == item.id);
    if (index < 0) { items.add(item); } else { items[index] = item; }
    await persist();
  }

  Future<void> remove(String id) async {
    items.removeWhere((e) => e.id == id);
    completedOccurrences.removeWhere((key, value) => key.startsWith('$id|'));
    await persist();
  }

  bool isCompleted(PlanItem item, DateTime date) {
    if (item.repeat == RepeatRule.never) return item.completed;
    return completedOccurrences['${item.id}|${dateLabel(date)}'] ?? false;
  }

  Future<void> toggleCompleted(PlanItem item, DateTime date) async {
    if (item.repeat == RepeatRule.never) {
      await upsert(item.copyWith(completed: !item.completed));
    } else {
      final key = '${item.id}|${dateLabel(date)}';
      completedOccurrences[key] = !(completedOccurrences[key] ?? false);
      await persist();
    }
  }

  List<PlanItem> forDay(DateTime date) {
    final result = items.where((item) => item.occursOn(date)).toList();
    result.sort((a,b) {
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      return a.start.hour * 60 + a.start.minute - b.start.hour * 60 - b.start.minute;
    });
    return result;
  }

  int netForMonth(DateTime month, {required bool onlyCompleted}) {
    var total = 0;
    final days = daysInMonth(month.year, month.month);
    for (var d = 1; d <= days; d++) {
      final day = DateTime(month.year, month.month, d);
      for (final item in forDay(day)) {
        if (item.kind == PlanKind.event) continue;
        if (onlyCompleted && !isCompleted(item, day)) continue;
        total += item.kind == PlanKind.income ? item.cents : -item.cents;
      }
    }
    return total;
  }

  int totalForMonth(DateTime month, PlanKind kind, {bool onlyCompleted = false}) {
    var sum = 0;
    for (var day = 1; day <= daysInMonth(month.year, month.month); day++) {
      final date = DateTime(month.year, month.month, day);
      for (final item in forDay(date)) {
        if (item.kind != kind || (onlyCompleted && !isCompleted(item, date))) continue;
        sum += item.cents;
      }
    }
    return sum;
  }

  Map<String, int> byCategory(DateTime month) {
    final result = <String,int>{};
    for (var day = 1; day <= daysInMonth(month.year, month.month); day++) {
      for (final item in forDay(DateTime(month.year, month.month, day))) {
        if (item.kind != PlanKind.expense) continue;
        result[item.category] = (result[item.category] ?? 0) + item.cents;
      }
    }
    return result;
  }

  Future<void> syncReminders() async {
    try {
      await reminders.reschedule(items, notificationsEnabled: notificationsEnabled,
        eventNotifications: eventNotifications, financeNotifications: financeNotifications,
        vibration: vibrationsEnabled);
    } catch (err) { debugPrint('Não foi possível atualizar lembretes: $err'); }
  }
}
