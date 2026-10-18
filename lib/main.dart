import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/format.dart';
import 'models/plan_item.dart';
import 'services/planner_store.dart';
import 'services/reminder_service.dart';
import 'widgets/item_editor.dart';
import 'widgets/plan_tile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PlannerApp());
}

class PlannerApp extends StatefulWidget {
  const PlannerApp({super.key});
  @override
  State<PlannerApp> createState() => _PlannerAppState();
}

class _PlannerAppState extends State<PlannerApp> {
  late final PlannerStore store;
  @override
  void initState() {
    super.initState();
    store = PlannerStore(ReminderService());
    _initialize();
  }

  Future<void> _initialize() async {
    try { await store.reminders.init(); } catch (e) { debugPrint('Notificações: $e'); }
    try { await store.load(); } catch (e) { debugPrint('Dados: $e'); store.finishLoadingWithDefaults(); }
  }

  @override
  void dispose() { store.dispose(); super.dispose(); }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    const schemeSeed = kMint;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(seedColor: schemeSeed, brightness: brightness,
        surface: dark ? kBg : const Color(0xFFF6F8FC), primary: dark ? kMint : const Color(0xFF087D71)),
      scaffoldBackgroundColor: dark ? kBg : const Color(0xFFF6F8FC),
      cardTheme: CardThemeData(
        color: dark ? kSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(backgroundColor: dark ? kBg : const Color(0xFFF6F8FC),
        scrolledUnderElevation: 0),
      inputDecorationTheme: InputDecorationTheme(filled: true,
        fillColor: dark ? kSurface2 : const Color(0xFFEFF3F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15)),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? kSurface : Colors.white,
        indicatorColor: dark ? const Color(0xFF164A47) : const Color(0xFFCBF6EA),
        height: 74,
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LuminaPlan',
      theme: _theme(Brightness.light), darkTheme: _theme(Brightness.dark),
      themeMode: store.darkTheme ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: store.loaded ? PlannerHome(store: store) : const Scaffold(body: Center(child: CircularProgressIndicator())),
    ),
  );
}

enum CalendarView { month, week, day }

class PlannerHome extends StatefulWidget {
  const PlannerHome({super.key, required this.store});
  final PlannerStore store;
  @override
  State<PlannerHome> createState() => _PlannerHomeState();
}

class _PlannerHomeState extends State<PlannerHome> {
  int page = 0;
  DateTime chosen = dayOnly(DateTime.now());
  DateTime financeMonth = DateTime(DateTime.now().year, DateTime.now().month);
  CalendarView view = CalendarView.month;

  Future<void> _add() async {
    final kind = page == 1 ? PlanKind.expense : PlanKind.event;
    await showItemEditor(context, widget.store, initialDay: chosen, initialKind: kind);
  }

  void _shift(int step) => setState(() {
    chosen = switch (view) {
      CalendarView.month => DateTime(chosen.year, chosen.month + step, math.min(chosen.day, daysInMonth(chosen.year, chosen.month + step))),
      CalendarView.week => chosen.add(Duration(days: 7 * step)),
      CalendarView.day => chosen.add(Duration(days: step)),
    };
  });

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/branding/owl_app.png', width: 36, height: 36,
              fit: BoxFit.cover)),
          const SizedBox(width: 10),
          const Flexible(child: Text('LuminaPlan', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20))),
        ]),
        actions: [
          if (page == 0) IconButton(tooltip: 'Hoje', onPressed: () => setState(() => chosen = dayOnly(DateTime.now())), icon: const Icon(Icons.today_outlined)),
          IconButton(tooltip: 'Notificações', onPressed: () => setState(() => page = 3), icon: Icon(store.notificationsEnabled ? Icons.notifications_none_rounded : Icons.notifications_off_outlined)),
        ],
      ),
      body: SafeArea(top: false, child: AnimatedBuilder(animation: store, builder: (_, __) {
        return IndexedStack(index: page, children: [
          _agenda(), _finance(), _summary(), _settings(),
        ]);
      })),
      floatingActionButton: page <= 1 ? FloatingActionButton.extended(
        heroTag: 'new', onPressed: _add, icon: const Icon(Icons.add),
        label: const Text('Adicionar')) : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (i) => setState(() => page = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Finanças'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Resumo'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Ajustes'),
        ],
      ),
    );
  }

  Widget _agenda() {
    final today = widget.store.forDay(chosen);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 100), children: [
      _sectionHeading('Sua agenda', 'Organize o tempo e o dinheiro'),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: SegmentedButton<CalendarView>(
          showSelectedIcon: false,
          style: ButtonStyle(visualDensity: VisualDensity.compact,
            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 7))),
          segments: const [
            ButtonSegment(value: CalendarView.month, label: Text('Mês')),
            ButtonSegment(value: CalendarView.week, label: Text('Semana')),
            ButtonSegment(value: CalendarView.day, label: Text('Dia')),
          ], selected: {view}, onSelectionChanged: (v) => setState(() => view = v.first),
        )),
      ]),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.fromLTRB(10, 12, 10, 12), child: Column(children: [
        Row(children: [
          IconButton(onPressed: () => _shift(-1), tooltip: 'Anterior', icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text(switch(view) {
            CalendarView.month => prettyMonth(chosen),
            CalendarView.week => 'Semana de ${dateLabel(mondayOf(chosen))}',
            CalendarView.day => '${weekdays[chosen.weekday - 1]}, ${dateLabel(chosen)}',
          }, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          IconButton(onPressed: () => _shift(1), tooltip: 'Próximo', icon: const Icon(Icons.chevron_right)),
        ]),
        if (view == CalendarView.month) _monthGrid() else if (view == CalendarView.week) _weekStrip(),
        if (view == CalendarView.day) _dailyTimeline(chosen),
      ]))),
      if (view != CalendarView.day) ...[
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Text('Dia ${dateLabel(chosen)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          Text('${today.length} itens', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: 10),
        if (today.isEmpty) _empty('Nenhum lançamento neste dia', Icons.event_available_outlined)
        else ...today.map((e) => PlanTile(item: e, day: chosen, store: widget.store)),
      ],
    ]);
  }

  Widget _monthGrid() {
    final first = DateTime(chosen.year, chosen.month, 1);
    final pad = first.weekday - 1;
    final total = daysInMonth(chosen.year, chosen.month);
    final rows = ((pad + total) / 7).ceil();
    return Column(children: [
      Row(children: weekdays.map((name) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 9),
        child: Text(name, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))))).toList()),
      ...List.generate(rows, (r) => Row(children: List.generate(7, (c) {
        final dayNum = r * 7 + c - pad + 1;
        if (dayNum < 1 || dayNum > total) return const Expanded(child: SizedBox(height: 65));
        final date = DateTime(chosen.year, chosen.month, dayNum);
        final items = widget.store.forDay(date);
        final selected = sameDay(date, chosen);
        final isToday = sameDay(date, DateTime.now());
        return Expanded(child: InkWell(borderRadius: BorderRadius.circular(15),
          onTap: () => setState(() => chosen = date),
          child: Container(height: 65, margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
              color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: .18) : null,
              border: isToday ? Border.all(color: kBlue.withValues(alpha: .8)) : null),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$dayNum', style: TextStyle(fontWeight: selected || isToday ? FontWeight.bold : FontWeight.w400,
                color: selected ? kBlue : null)),
              const SizedBox(height: 7),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ...items.take(3).map((item) => Container(width: 5, height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: colorFor(item.kind)))),
              ]),
            ])),
        ));
      }))),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
        _Legend(color: kBlue, label: 'Evento'), SizedBox(width: 13),
        _Legend(color: kGreen, label: 'Entrada'), SizedBox(width: 13),
        _Legend(color: kRed, label: 'Saída'),
      ]),
      const SizedBox(height: 6),
    ]);
  }

  Widget _weekStrip() {
    final monday = mondayOf(chosen);
    return Row(children: List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final selected = sameDay(chosen, day);
      final entries = widget.store.forDay(day);
      return Expanded(child: InkWell(onTap: () => setState(() => chosen = day),
        borderRadius: BorderRadius.circular(15),
        child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: selected ? kBlue.withValues(alpha: .2) : null,
            borderRadius: BorderRadius.circular(15)),
          child: Column(children: [
            Text(weekdays[i], style: const TextStyle(fontSize: 10)),
            const SizedBox(height: 6), Text('${day.day}', style: TextStyle(fontSize: 17,
              color: selected ? kBlue : null, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle,
              color: entries.isEmpty ? Colors.transparent : colorFor(entries.first.kind))),
          ])),
      ));
    }));
  }

  Widget _dailyTimeline(DateTime date) {
    final items = widget.store.forDay(date);
    if (items.isEmpty) return Padding(padding: const EdgeInsets.all(10), child: _empty('Dia livre, aproveite!', Icons.nights_stay_outlined));
    return Column(children: [
      ...items.map((item) => Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
        SizedBox(width: 53, child: Text(item.allDay && item.kind == PlanKind.event ? 'Dia todo' : timeLabel(item.occurrenceAt(date)),
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
        Expanded(child: PlanTile(item: item, day: date, store: widget.store)),
      ]))),
    ]);
  }

  Widget _finance() {
    final income = widget.store.totalForMonth(financeMonth, PlanKind.income);
    final expense = widget.store.totalForMonth(financeMonth, PlanKind.expense);
    final incomePaid = widget.store.totalForMonth(financeMonth, PlanKind.income, onlyCompleted: true);
    final expensePaid = widget.store.totalForMonth(financeMonth, PlanKind.expense, onlyCompleted: true);
    final financeEntries = <({PlanItem item, DateTime date})>[];
    for (var d = 1; d <= daysInMonth(financeMonth.year, financeMonth.month); d++) {
      final day = DateTime(financeMonth.year, financeMonth.month, d);
      for (final item in widget.store.forDay(day)) {
        if (item.kind != PlanKind.event) financeEntries.add((item: item, date: day));
      }
    }
    financeEntries.sort((a, b) => b.date.compareTo(a.date));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 100), children: [
      _sectionHeading('Seu dinheiro', 'Receitas, despesas e previsões'),
      const SizedBox(height: 16),
      Row(children: [
        IconButton(onPressed: () => setState(() => financeMonth = DateTime(financeMonth.year, financeMonth.month - 1)), icon: const Icon(Icons.chevron_left)),
        Expanded(child: Text(prettyMonth(financeMonth), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        IconButton(onPressed: () => setState(() => financeMonth = DateTime(financeMonth.year, financeMonth.month + 1)), icon: const Icon(Icons.chevron_right)),
      ]),
      const SizedBox(height: 6),
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1D756A), Color(0xFF13405E)])), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Saldo realizado neste mês', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Text(money(incomePaid - expensePaid), style: const TextStyle(color: Colors.white,
          fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Text('Previsão: ${money(income - expense)}', style: const TextStyle(color: Colors.white70)),
      ])),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _statCard('Entradas', income, Icons.south_west, kGreen)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Saídas', expense, Icons.north_east, kRed)),
      ]),
      const SizedBox(height: 18),
      Row(children: [
        const Expanded(child: Text('Transações', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        Text('${financeEntries.length} lançamentos', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
      const SizedBox(height: 10),
      if (financeEntries.isEmpty) _empty('Nenhuma transação neste mês', Icons.account_balance_wallet_outlined)
      else ...financeEntries.map((pair) => PlanTile(item: pair.item, day: pair.date, store: widget.store, showDate: true)),
    ]);
  }

  Widget _statCard(String label, int cents, IconData symbol, Color accent) => Card(
    child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(symbol, color: accent), const SizedBox(height: 12), Text(label,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
      const SizedBox(height: 4), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
        child: Text(money(cents), style: TextStyle(color: accent, fontSize: 19, fontWeight: FontWeight.w900))),
    ])),
  );

  Widget _summary() {
    final month = financeMonth;
    final allIn = widget.store.totalForMonth(month, PlanKind.income);
    final allOut = widget.store.totalForMonth(month, PlanKind.expense);
    final categories = widget.store.byCategory(month).entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 90), children: [
      _sectionHeading('Visão geral', 'Onde seu dinheiro está indo'),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Balanço • ${prettyMonth(month)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 10), Text(money(allIn - allOut), style: TextStyle(
          fontSize: 30, fontWeight: FontWeight.w900, color: allIn - allOut >= 0 ? kGreen : kRed)),
        const SizedBox(height: 14),
        LinearProgressIndicator(value: allIn == 0 ? 0 : (allOut / allIn).clamp(0, 1).toDouble(),
          color: kRed, backgroundColor: kGreen.withValues(alpha: .3), minHeight: 11, borderRadius: BorderRadius.circular(8)),
        const SizedBox(height: 9),
        Text(allIn == 0 ? 'Registre uma entrada para calcular a proporção de gastos.'
          : '${(100 * allOut / allIn).toStringAsFixed(0)}% das entradas previstas comprometidas',
          style: const TextStyle(fontSize: 12)),
      ]))),
      const SizedBox(height: 18),
      const Text('Despesas por categoria', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 9),
      if (categories.isEmpty) _empty('Crie despesas para ver seu resumo', Icons.pie_chart_outline)
      else Card(child: Padding(padding: const EdgeInsets.all(17), child: Column(children: [
        ...categories.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(children: [
          Row(children: [Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(money(entry.value), style: const TextStyle(fontWeight: FontWeight.w700))]),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: allOut == 0 ? 0 : entry.value / allOut,
            minHeight: 8, color: kBlue, backgroundColor: kBlue.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(6)),
        ]))),
      ]))),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        const Icon(Icons.lightbulb_outline, color: kAmber), const SizedBox(width: 12),
        Expanded(child: Text('Dica: marque cada pagamento como realizado para separar o que já saiu do que ainda está previsto.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))),
      ]))),
    ]);
  }

  Widget _settings() {
    final store = widget.store;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 90), children: [
      _sectionHeading('Preferências', 'Deixe seu planner do seu jeito'),
      const SizedBox(height: 14),
      const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text('NOTIFICAÇÕES', style: TextStyle(color: kBlue, fontWeight: FontWeight.w800, fontSize: 12))),
      Card(child: Column(children: [
        SwitchListTile.adaptive(secondary: const Icon(Icons.notifications_active_outlined), title: const Text('Alertas no celular'),
          subtitle: const Text('Liga ou desliga todos os lembretes'), value: store.notificationsEnabled,
          onChanged: (v) async {
            if (v) {
              final allowed = await store.reminders.askPermission();
              if (!allowed && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Permita notificações nas configurações do Android.')));
            }
            store.notificationsEnabled = v;
            await store.persist();
          }),
        const Divider(height: 1, indent: 16, endIndent: 16),
        SwitchListTile.adaptive(secondary: const Icon(Icons.event_note_outlined), title: const Text('Compromissos'),
          subtitle: const Text('Avisos antes dos eventos'), value: store.eventNotifications,
          onChanged: store.notificationsEnabled ? (v) { store.eventNotifications = v; store.persist(); } : null),
        SwitchListTile.adaptive(secondary: const Icon(Icons.payments_outlined), title: const Text('Movimentações financeiras'),
          subtitle: const Text('Lembretes de recebimentos e contas'), value: store.financeNotifications,
          onChanged: store.notificationsEnabled ? (v) { store.financeNotifications = v; store.persist(); } : null),
        SwitchListTile.adaptive(secondary: const Icon(Icons.vibration), title: const Text('Vibração'),
          subtitle: const Text('Sujeita às configurações do Android'), value: store.vibrationsEnabled,
          onChanged: store.notificationsEnabled ? (v) { store.vibrationsEnabled = v; store.persist(); } : null),
      ])),
      const SizedBox(height: 15),
      const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text('APARÊNCIA E DADOS', style: TextStyle(color: kBlue, fontWeight: FontWeight.w800, fontSize: 12))),
      Card(child: Column(children: [
        SwitchListTile.adaptive(secondary: Icon(store.darkTheme ? Icons.dark_mode : Icons.light_mode), title: const Text('Tema escuro'),
          value: store.darkTheme, onChanged: (v) { store.darkTheme = v; store.persist(); }),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(leading: const Icon(Icons.ios_share), title: const Text('Copiar backup'),
          subtitle: const Text('Salva eventos e transações em JSON'), trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: store.exportJson()));
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup copiado. Guarde-o em local seguro.')));
          }),
        ListTile(leading: const Icon(Icons.settings_backup_restore), title: const Text('Restaurar backup'),
          subtitle: const Text('Importar JSON de outro celular'), trailing: const Icon(Icons.chevron_right),
          onTap: _restoreBackup),
      ])),
      const SizedBox(height: 10),
      Text('Versão 1.0 • Funciona offline. Os dados ficam neste dispositivo. Sem conexão bancária.\n'
          'Dica: faça backups regularmente. Desinstalar ou limpar dados do aplicativo pode apagar suas informações.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 11, height: 1.6, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }

  Future<void> _restoreBackup() async {
    final ctrl = TextEditingController();
    final data = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Restaurar backup'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Cole o JSON exportado anteriormente. Isso substituirá os dados atuais.'),
        const SizedBox(height: 12),
        TextField(controller: ctrl, minLines: 2, maxLines: 7,
          decoration: const InputDecoration(hintText: '{"schema":1,...}')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Importar'))],
    ));
    if (data == null) return;
    final ok = await widget.store.importJson(data);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Backup restaurado!' : 'Backup inválido. Nada foi alterado.')));
    ctrl.dispose();
  }

  Widget _sectionHeading(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.5)),
    const SizedBox(height: 3),
    Text(subtitle, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
  ]);

  Widget _empty(String title, IconData icon) => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    width: double.infinity, padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .5)),
      borderRadius: BorderRadius.circular(17)),
    child: Column(children: [Icon(icon, size: 30, color: kBlue), const SizedBox(height: 10),
      Text(title, style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)]),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
    const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 10)),
  ]);
}
