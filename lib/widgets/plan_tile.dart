import 'package:flutter/material.dart';
import '../core/format.dart';
import '../models/plan_item.dart';
import '../services/planner_store.dart';
import 'item_editor.dart';

Color colorFor(PlanKind kind) => switch(kind) {
  PlanKind.event => kBlue,
  PlanKind.income => kGreen,
  PlanKind.expense => kRed,
};

IconData iconFor(PlanKind kind) => switch(kind) {
  PlanKind.event => Icons.event_note,
  PlanKind.income => Icons.south_west,
  PlanKind.expense => Icons.north_east,
};

class PlanTile extends StatelessWidget {
  const PlanTile({super.key, required this.item, required this.day,
    required this.store, this.showDate = false});
  final PlanItem item;
  final DateTime day;
  final PlannerStore store;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final done = store.isCompleted(item, day);
    final accent = colorFor(item.kind);
    return Card(margin: const EdgeInsets.only(bottom: 8), clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: () => showItemEditor(context, store, existing: item),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(
              color: accent.withValues(alpha: .13), borderRadius: BorderRadius.circular(13)),
              child: Icon(iconFor(item.kind), color: accent)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 3),
              Text('${showDate ? '${dateLabel(day)} · ' : ''}${item.allDay && item.kind == PlanKind.event ? 'Dia inteiro' : timeLabel(item.occurrenceAt(day))} · ${item.category}${item.repeat != RepeatRule.never ? ' · ↻' : ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
            if (item.kind != PlanKind.event) ...[
              const SizedBox(width: 5),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${item.kind == PlanKind.income ? '+' : '−'} ${money(item.cents)}',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 12.5)),
                Text(done ? 'Realizado' : 'Previsto', style: TextStyle(
                  color: done ? kGreen : kAmber, fontSize: 10)),
              ]),
              IconButton(tooltip: done ? 'Marcar como previsto' : 'Marcar como realizado',
                onPressed: () => store.toggleCompleted(item, day),
                icon: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? kGreen : Colors.grey, size: 21)),
            ] else const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }
}
