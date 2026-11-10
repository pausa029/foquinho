// Histórico: resumos diários e semanais só com o que foi registrado.

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../logic/stats.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int weekOffset = 0; // 0 = semana atual, -1 = anterior…

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final d = state.data;
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final start = weekStart(now).add(Duration(days: 7 * weekOffset));
    final w = weekStats(d, start);
    final end = start.add(const Duration(days: 6));
    final todayKey = dayKey(now);
    final sessions = d.sessions.where((s) => s.day.compareTo(w.start) >= 0 && s.day.compareTo(dayKey(end)) <= 0).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final maxBar = [30, ...w.days.map((x) => x.studyMin), ...w.days.map((x) => x.moveMin)].reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              IconButton(onPressed: () => setState(() => weekOffset--), icon: const Icon(Icons.chevron_left), tooltip: 'Semana anterior'),
              Expanded(
                child: Column(
                  children: [
                    Text(weekOffset == 0 ? 'Esta semana' : 'Semana', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${fmtDay(w.start)} a ${fmtDay(dayKey(end))}', style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(onPressed: weekOffset == 0 ? null : () => setState(() => weekOffset++), icon: const Icon(Icons.chevron_right), tooltip: 'Próxima semana'),
            ],
          ),

          const SectionTitle('Resumo da semana'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: w.sessions == 0 && w.screenDays == 0
                  ? Text('Sem dados nesta semana. Os resumos usam só sessões registradas e tempo de tela informado.', style: TextStyle(color: cs.onSurfaceVariant))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _line(Icons.menu_book, 'Estudo: ${fmtMin(w.studyMin)} em ${w.studyDays} ${w.studyDays == 1 ? 'dia' : 'dias'}'),
                        _line(Icons.directions_run, 'Atividade física: ${fmtMin(w.moveMin)} em ${w.moveDays} ${w.moveDays == 1 ? 'dia' : 'dias'}'),
                        _line(Icons.phone_android, w.screenDays == 0 ? 'Tempo de tela: sem dados informados' : 'Tempo de tela: média de ${fmtMin(w.screenAvg!)} em ${w.screenDays} ${w.screenDays == 1 ? 'dia informado' : 'dias informados'} (registro manual)'),
                        if (w.bySubject.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Por matéria: ${(w.bySubject.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) => '${d.subjectName(e.key)} ${fmtMin(e.value)}').join(' · ')}',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
            ),
          ),

          const SectionTitle('Dia a dia'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  Semantics(
                    label: 'Gráfico de minutos por dia. ${w.days.map((s) => '${kWeekdayShort[w.days.indexOf(s)]}: ${s.hasData ? 'estudo ${s.studyMin} min, exercício ${s.moveMin} min' : 'sem dados'}').join('. ')}',
                    child: ExcludeSemantics(
                      child: SizedBox(
                        height: 140,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < 7; i++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (!w.days[i].hasData && w.days[i].day.compareTo(todayKey) <= 0)
                                        Text('–', style: TextStyle(color: cs.onSurfaceVariant)),
                                      Expanded(
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Expanded(child: _bar(w.days[i].studyMin, maxBar, cs.primary)),
                                            const SizedBox(width: 2),
                                            Expanded(child: _bar(w.days[i].moveMin, maxBar, cs.tertiary)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(kWeekdayShort[i], style: TextStyle(fontSize: 12, color: w.days[i].day == todayKey ? cs.primary : cs.onSurfaceVariant, fontWeight: w.days[i].day == todayKey ? FontWeight.w700 : FontWeight.w400)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legend(cs.primary, 'estudo'),
                      const SizedBox(width: 12),
                      _legend(cs.tertiary, 'exercício'),
                      const SizedBox(width: 12),
                      Text('– sem dados', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < 7; i++)
                  ListTile(
                    dense: true,
                    title: Text('${kWeekdayShort[i]} ${fmtDay(w.days[i].day)}${w.days[i].day == todayKey ? ' · hoje' : ''}'),
                    subtitle: Text(_dayLine(w.days[i], todayKey)),
                    trailing: w.days[i].day.compareTo(todayKey) > 0
                        ? null
                        : IconButton(
                            tooltip: 'Informar tempo de tela de ${fmtDay(w.days[i].day)}',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _logScreen(context, w.days[i].day),
                          ),
                  ),
              ],
            ),
          ),

          const SectionTitle('Sessões da semana'),
          if (sessions.isEmpty)
            const EmptyState(icon: Icons.history, title: 'Nenhuma sessão registrada nesta semana', text: 'Conclua um temporizador de estudo ou exercício e registre.')
          else
            Card(
              child: Column(
                children: [
                  for (final s in sessions)
                    ListTile(
                      leading: Icon(s.kind == SessionKind.estudo ? Icons.menu_book : Icons.directions_run, color: s.kind == SessionKind.estudo ? cs.primary : cs.tertiary),
                      title: Text(s.title),
                      subtitle: Text(
                        '${kWeekdayShort[(parseDayKey(s.day) ?? now).weekday - 1]} ${fmtDay(s.day)} · ${fmtMin(s.minutes)}'
                        '${s.subjectId != null ? ' · ${d.subjectName(s.subjectId)}' : ''}'
                        '${s.note.isNotEmpty ? '\n${s.note}' : ''}',
                      ),
                      isThreeLine: s.note.isNotEmpty,
                      trailing: IconButton(
                        tooltip: 'Excluir sessão',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await confirmDialog(context, title: 'Excluir esta sessão?', text: '${s.title}, ${fmtMin(s.minutes)}.', yes: 'Excluir', danger: true);
                          if (ok) await state.removeSession(s.id);
                        },
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await confirmDialog(context, title: 'Apagar todo o histórico?', text: 'Todas as sessões e os tempos de tela informados serão apagados. Matérias, provas e tarefas continuam. Não tem volta.', yes: 'Apagar histórico', danger: true);
              if (ok) await state.clearHistory();
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Apagar histórico'),
          ),
        ],
      ),
    );
  }

  String _dayLine(DayStats s, String todayKey) {
    if (s.day.compareTo(todayKey) > 0) return 'Ainda não chegou';
    if (!s.hasData) return 'Sem dados';
    final parts = <String>[];
    if (s.studyMin > 0) parts.add('estudo ${fmtMin(s.studyMin)}');
    if (s.moveMin > 0) parts.add('exercício ${fmtMin(s.moveMin)}');
    parts.add(s.screenMin == null ? 'tela: sem dados' : 'tela ${fmtMin(s.screenMin!)} (manual)');
    return parts.join(' · ');
  }

  Widget _bar(int v, int max, Color color) {
    final f = max <= 0 ? 0.0 : (v / max).clamp(0.0, 1.0).toDouble();
    return FractionallySizedBox(
      heightFactor: v == 0 ? 0.02 : f,
      alignment: Alignment.bottomCenter,
      child: Container(decoration: BoxDecoration(color: v == 0 ? color.withAlpha(60) : color, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))),
    );
  }

  Widget _legend(Color c, String t) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 4),
      Text(t, style: const TextStyle(fontSize: 12)),
    ]);
  }

  Widget _line(IconData i, String t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [Icon(i, size: 18), const SizedBox(width: 8), Expanded(child: Text(t))]),
    );
  }

  Future<void> _logScreen(BuildContext context, String day) async {
    final state = AppScope.of(context);
    final cur = state.data.screenLog[day];
    final h = TextEditingController(text: cur == null ? '' : (cur ~/ 60).toString());
    final m = TextEditingController(text: cur == null ? '' : (cur % 60).toString());
    final r = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tempo de tela de ${fmtDay(day)}'),
        content: Row(
          children: [
            Expanded(child: TextField(controller: h, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Horas'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: m, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minutos'))),
          ],
        ),
        actions: [
          if (cur != null) TextButton(onPressed: () => Navigator.pop(ctx, -1), child: const Text('Apagar')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final hh = int.tryParse(h.text.trim()) ?? 0;
              final mm = int.tryParse(m.text.trim()) ?? 0;
              if (hh < 0 || hh > 24 || mm < 0 || mm > 59 || (h.text.trim().isEmpty && m.text.trim().isEmpty)) return;
              Navigator.pop(ctx, hh * 60 + mm);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (r == null) return;
    await state.setScreenMinutes(day, r < 0 ? null : r);
  }
}
