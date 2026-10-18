import '../core/format.dart';

enum PlanKind { event, income, expense }

enum RepeatRule { never, daily, weekly, monthly }

class PlanItem {
  final String id;
  final PlanKind kind;
  final String title;
  final String category;
  final String notes;
  final DateTime start;
  final DateTime? end;
  final int cents;
  final bool allDay;
  final bool completed;
  final bool reminderEnabled;
  final int reminderMinutes;
  final RepeatRule repeat;

  const PlanItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.category,
    required this.notes,
    required this.start,
    this.end,
    required this.cents,
    required this.allDay,
    required this.completed,
    required this.reminderEnabled,
    required this.reminderMinutes,
    required this.repeat,
  });

  bool occursOn(DateTime date) {
    final base = dayOnly(start);
    final target = dayOnly(date);
    if (target.isBefore(base)) return false;
    if (repeat == RepeatRule.never) return sameDay(date, start);
    if (repeat == RepeatRule.daily) return true;
    final delta = target.difference(base).inDays;
    if (repeat == RepeatRule.weekly) return delta % 7 == 0;
    final valid = start.day.clamp(1, daysInMonth(date.year, date.month));
    return target.day == valid;
  }

  DateTime occurrenceAt(DateTime date) => DateTime(date.year, date.month, date.day, start.hour, start.minute);

  PlanItem copyWith({bool? completed, bool? reminderEnabled}) => PlanItem(
    id: id, kind: kind, title: title, category: category, notes: notes, start: start,
    end: end, cents: cents, allDay: allDay, completed: completed ?? this.completed,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled, reminderMinutes: reminderMinutes, repeat: repeat,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'kind': kind.name, 'title': title, 'category': category, 'notes': notes,
    'start': start.toIso8601String(), 'end': end?.toIso8601String(), 'cents': cents,
    'allDay': allDay, 'completed': completed, 'reminderEnabled': reminderEnabled,
    'reminderMinutes': reminderMinutes, 'repeat': repeat.name,
  };

  factory PlanItem.fromJson(Map<String, dynamic> json) {
    T enumByName<T extends Enum>(List<T> values, dynamic name, T fallback) {
      for (final element in values) { if (element.name == name) return element; }
      return fallback;
    }
    return PlanItem(
      id: json['id']?.toString() ?? '',
      kind: enumByName(PlanKind.values, json['kind'], PlanKind.event),
      title: json['title']?.toString() ?? 'Sem título',
      category: json['category']?.toString() ?? 'Outros',
      notes: json['notes']?.toString() ?? '',
      start: DateTime.tryParse(json['start']?.toString() ?? '') ?? DateTime.now(),
      end: DateTime.tryParse(json['end']?.toString() ?? ''),
      cents: (json['cents'] as num?)?.toInt() ?? 0,
      allDay: json['allDay'] == true,
      completed: json['completed'] == true,
      reminderEnabled: json['reminderEnabled'] == true,
      reminderMinutes: (json['reminderMinutes'] as num?)?.toInt() ?? 10,
      repeat: enumByName(RepeatRule.values, json['repeat'], RepeatRule.never),
    );
  }
}
