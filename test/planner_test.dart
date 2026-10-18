import 'package:flutter_test/flutter_test.dart';
import 'package:luminaplan/core/format.dart';
import 'package:luminaplan/models/plan_item.dart';

void main() {
  test('Formata reais corretamente', () {
    expect(money(125050), 'R\$ 1.250,50');
    expect(money(-2150), '− R\$ 21,50');
    expect(parseMoney('1.250,50'), 125050);
    expect(parseMoney('0'), null);
  });

  PlanItem makeItem(DateTime when, RepeatRule repeat) => PlanItem(
    id: 'test', kind: PlanKind.expense, title: 'Aluguel', category: 'Moradia',
    notes: '', start: when, cents: 150000, allDay: true,
    completed: false, reminderEnabled: true, reminderMinutes: 1440, repeat: repeat,
  );

  test('Recorrência semanal respeita o dia de início', () {
    final item = makeItem(DateTime(2026, 10, 5), RepeatRule.weekly);
    expect(item.occursOn(DateTime(2026, 10, 12)), isTrue);
    expect(item.occursOn(DateTime(2026, 10, 13)), isFalse);
    expect(item.occursOn(DateTime(2026, 9, 28)), isFalse);
  });

  test('Recorrência mensal ajusta meses curtos', () {
    final item = makeItem(DateTime(2026, 1, 31), RepeatRule.monthly);
    expect(item.occursOn(DateTime(2026, 2, 28)), isTrue);
    expect(item.occursOn(DateTime(2026, 3, 31)), isTrue);
    expect(item.occursOn(DateTime(2026, 2, 27)), isFalse);
  });
}
