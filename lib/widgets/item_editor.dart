import 'package:flutter/material.dart';
import '../core/format.dart';
import '../models/plan_item.dart';
import '../services/planner_store.dart';

const categoriesExpense = ['Alimentação', 'Transporte', 'Moradia', 'Saúde', 'Educação', 'Lazer', 'Compras', 'Assinaturas', 'Outros'];
const categoriesIncome = ['Salário', 'Freelance', 'PIX', 'Vendas', 'Presentes', 'Investimentos', 'Outros'];
const categoriesEvent = ['Pessoal', 'Trabalho', 'Estudos', 'Saúde', 'Família', 'Outros'];

Future<void> showItemEditor(BuildContext context, PlannerStore store,
    {PlanItem? existing, DateTime? initialDay, PlanKind initialKind = PlanKind.event}) async {
  await showModalBottomSheet<void>(
    context: context, isScrollControlled: true, useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    showDragHandle: true,
    builder: (sheetContext) => ItemEditor(store: store, existing: existing,
      initialDay: initialDay ?? DateTime.now(), initialKind: initialKind),
  );
}

class ItemEditor extends StatefulWidget {
  const ItemEditor({super.key, required this.store, this.existing,
    required this.initialDay, required this.initialKind});
  final PlannerStore store;
  final PlanItem? existing;
  final DateTime initialDay;
  final PlanKind initialKind;
  @override
  State<ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<ItemEditor> {
  late PlanKind kind;
  late DateTime date;
  late TimeOfDay time;
  late TimeOfDay endTime;
  late bool allDay;
  late bool completed;
  late bool alarm;
  late int minutes;
  late RepeatRule repeat;
  late String category;
  late final TextEditingController titleCtrl;
  late final TextEditingController notesCtrl;
  late final TextEditingController amountCtrl;
  bool saving = false;

  List<String> get categories => kind == PlanKind.event ? categoriesEvent :
    kind == PlanKind.income ? categoriesIncome : categoriesExpense;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    kind = e?.kind ?? widget.initialKind;
    date = e?.start ?? widget.initialDay;
    time = TimeOfDay.fromDateTime(e?.start ?? DateTime(date.year, date.month, date.day, 9));
    endTime = TimeOfDay.fromDateTime(e?.end ?? DateTime(date.year, date.month, date.day, 10));
    allDay = e?.allDay ?? (kind != PlanKind.event);
    completed = e?.completed ?? false;
    alarm = e?.reminderEnabled ?? true;
    minutes = e?.reminderMinutes ?? (kind == PlanKind.event ? 10 : 1440);
    repeat = e?.repeat ?? RepeatRule.never;
    category = e?.category ?? categories.first;
    titleCtrl = TextEditingController(text: e?.title ?? '');
    notesCtrl = TextEditingController(text: e?.notes ?? '');
    amountCtrl = TextEditingController(text: e == null ? '' :
      (e.cents / 100).toStringAsFixed(2).replaceAll('.', ','));
  }

  @override
  void dispose() { titleCtrl.dispose(); notesCtrl.dispose(); amountCtrl.dispose(); super.dispose(); }

  Future<void> selectDate() async {
    final picked = await showDatePicker(context: context, initialDate: date,
      firstDate: DateTime(2000), lastDate: DateTime(2100), locale: const Locale('pt', 'BR'));
    if (picked != null) setState(() => date = picked);
  }

  Future<void> selectTime({bool end = false}) async {
    final picked = await showTimePicker(context: context, initialTime: end ? endTime : time,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!));
    if (picked != null) setState(() { if (end) { endTime = picked; } else { time = picked; } });
  }

  Future<void> save() async {
    if (saving) return;
    if (titleCtrl.text.trim().isEmpty) { snack('Informe um título'); return; }
    final amount = kind == PlanKind.event ? 0 : parseMoney(amountCtrl.text);
    if (kind != PlanKind.event && amount == null) { snack('Informe um valor válido. Ex.: 120,50'); return; }
    final start = DateTime(date.year, date.month, date.day,
      allDay && kind == PlanKind.event ? 9 : time.hour,
      allDay && kind == PlanKind.event ? 0 : time.minute);
    DateTime? end;
    if (kind == PlanKind.event && !allDay) {
      end = DateTime(date.year, date.month, date.day, endTime.hour, endTime.minute);
      if (!end.isAfter(start)) { snack('O término precisa ser depois do início'); return; }
    }
    setState(() => saving = true);
    final item = PlanItem(
      id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      kind: kind, title: titleCtrl.text.trim(), category: category,
      notes: notesCtrl.text.trim(), start: start, end: end,
      cents: amount ?? 0, allDay: allDay, completed: completed,
      reminderEnabled: alarm, reminderMinutes: minutes, repeat: repeat,
    );
    await widget.store.upsert(item);
    if (mounted) Navigator.of(context).pop();
  }

  void snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 25),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(widget.existing == null ? 'Novo lançamento' : 'Editar lançamento',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 12),
          SegmentedButton<PlanKind>(
            segments: const [
              ButtonSegment(value: PlanKind.event, label: Text('Evento'), icon: Icon(Icons.event)),
              ButtonSegment(value: PlanKind.income, label: Text('Entrada'), icon: Icon(Icons.south_west)),
              ButtonSegment(value: PlanKind.expense, label: Text('Saída'), icon: Icon(Icons.north_east)),
            ], selected: {kind},
            onSelectionChanged: (selected) => setState(() {
              kind = selected.first;
              category = categories.first;
              allDay = kind != PlanKind.event;
              minutes = kind == PlanKind.event ? 10 : 1440;
            }),
          ),
          const SizedBox(height: 18),
          TextField(controller: titleCtrl, textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Título', hintText: kind == PlanKind.event ? 'Ex.: Estudar Flutter' : 'Ex.: Mercado')),
          if (kind != PlanKind.event) ...[
            const SizedBox(height: 14),
            TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor (R\$)', prefixIcon: Icon(Icons.attach_money), hintText: 'Ex.: 125,90')),
          ],
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: categories.contains(category) ? category : categories.first,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) { if (v != null) setState(() => category = v); },
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: selectDate, icon: const Icon(Icons.calendar_today),
            label: Text('Data: ${dateLabel(date)}')),
          if (kind == PlanKind.event) SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero, title: const Text('Dia inteiro'),
            value: allDay, onChanged: (v) => setState(() => allDay = v)),
          if (!allDay || kind != PlanKind.event) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: selectTime,
                icon: const Icon(Icons.schedule), label: Text('Início ${time.format(context)}'))),
              if (kind == PlanKind.event) ...[
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: () => selectTime(end: true),
                  icon: const Icon(Icons.timelapse), label: Text('Fim ${endTime.format(context)}'))),
              ],
            ]),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<RepeatRule>(
            initialValue: repeat, decoration: const InputDecoration(labelText: 'Repetição'),
            items: const [
              DropdownMenuItem(value: RepeatRule.never, child: Text('Não repetir')),
              DropdownMenuItem(value: RepeatRule.daily, child: Text('Todo dia')),
              DropdownMenuItem(value: RepeatRule.weekly, child: Text('Toda semana')),
              DropdownMenuItem(value: RepeatRule.monthly, child: Text('Todo mês')),
            ], onChanged: (v) { if (v != null) setState(() => repeat = v); },
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.notifications_active_outlined, color: colors.primary),
            title: const Text('Alertar no celular'), subtitle: const Text('Pode desligar a qualquer momento'),
            value: alarm, onChanged: (v) => setState(() => alarm = v)),
          if (alarm) DropdownButtonFormField<int>(
            initialValue: minutes, decoration: const InputDecoration(labelText: 'Antecedência do alerta'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Na hora')),
              DropdownMenuItem(value: 5, child: Text('5 minutos antes')),
              DropdownMenuItem(value: 10, child: Text('10 minutos antes')),
              DropdownMenuItem(value: 30, child: Text('30 minutos antes')),
              DropdownMenuItem(value: 60, child: Text('1 hora antes')),
              DropdownMenuItem(value: 1440, child: Text('1 dia antes')),
            ], onChanged: (v) { if (v != null) setState(() => minutes = v); },
          ),
          if (kind != PlanKind.event) SwitchListTile.adaptive(contentPadding: EdgeInsets.zero,
            title: const Text('Já foi recebido / pago'), subtitle: const Text('Distingue previsto de realizado'),
            value: completed, onChanged: (v) => setState(() => completed = v)),
          const SizedBox(height: 10),
          TextField(controller: notesCtrl, maxLines: 2, textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Observações (opcional)')),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: saving ? null : save,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(saving ? 'Salvando...' : 'Salvar'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16))),
          if (widget.existing != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(onPressed: () async {
              final ok = await showDialog<bool>(context: context,
                builder: (ctx) => AlertDialog(title: const Text('Excluir lançamento?'),
                  content: const Text('Se for recorrente, todas as ocorrências serão excluídas.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir'))]));
              if (ok != true) return;
              await widget.store.remove(widget.existing!.id);
              if (context.mounted) Navigator.pop(context);
            }, icon: const Icon(Icons.delete_outline), label: const Text('Excluir'),
              style: TextButton.styleFrom(foregroundColor: kRed)),
          ],
        ]),
      ),
    );
  }
}
