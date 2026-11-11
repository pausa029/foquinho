// Painel inicial.

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../logic/stats.dart';
import '../../logic/streak.dart';
import '../../logic/suggestions.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import 'session_screen.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onGoTo; // troca de aba: 1 = Plano, 2 = Movimento
  const HomeScreen({super.key, required this.onGoTo});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final d = state.data;
    final p = d.profile ?? Profile(nickname: 'Estudante');
    final now = DateTime.now();
    final today = dayKey(now);
    final st = dayStats(d, today);
    final cs = Theme.of(context).colorScheme;
    final exams = state.upcomingExams(now);
    final studySugs = studySuggestions(d, now: now, limit: 2);
    final moveSugs = moveSuggestions(d, limit: 1);
    final screenToday = d.screenLog[today];

    return Scaffold(
      appBar: AppBar(title: Text('Oi, ${p.nickname}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            homeMessage(studyMin: st.studyMin, moveMin: st.moveMin, studyGoal: p.studyGoalMin, moveGoal: p.moveGoalMin),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          StreakCard(info: computeStreak(d, now)),
          const SizedBox(height: 12),

          // Ações rápidas
          Row(
            children: [
              Expanded(child: _QuickAction(icon: Icons.menu_book, label: 'Estudar agora', color: cs.primary, onTap: () => _startStudy(context))),
              const SizedBox(width: 8),
              Expanded(child: _QuickAction(icon: Icons.directions_run, label: 'Pausa ativa', color: cs.tertiary, onTap: () => _startMove(context))),
              const SizedBox(width: 8),
              Expanded(child: _QuickAction(icon: Icons.checklist, label: 'Ver plano', color: cs.secondary, onTap: () => onGoTo(1))),
            ],
          ),

          const SectionTitle('Hoje'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GoalProgress(label: 'Estudo', done: st.studyMin, goal: p.studyGoalMin, color: cs.primary),
                  const SizedBox(height: 14),
                  GoalProgress(label: 'Atividade física', done: st.moveMin, goal: p.moveGoalMin, color: cs.tertiary),
                  if (st.sessions == 0) ...[
                    const SizedBox(height: 12),
                    Text('Os minutos aparecem aqui quando você conclui uma sessão no temporizador.', style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ),

          const SectionTitle('Tempo de tela'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (screenToday == null) ...[
                    Text('Sem registro de hoje', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      p.screenGoalMin != null ? 'Meta: até ${fmtMin(p.screenGoalMin!)} por dia.' : 'Sem meta de tempo de tela definida.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(fmtMin(screenToday), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        if (p.screenGoalMin != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('de ${fmtMin(p.screenGoalMin!)}', style: TextStyle(color: cs.onSurfaceVariant)),
                          ),
                        const SizedBox(width: 8),
                        Chip(label: const Text('registro manual'), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                      ],
                    ),
                    if (p.screenGoalMin != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(screenToday <= p.screenGoalMin! ? Icons.check_circle_outline : Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              screenToday <= p.screenGoalMin!
                                  ? 'Dentro da meta. Faltam ${fmtMin(p.screenGoalMin! - screenToday)}.'
                                  : 'Passou ${fmtMin(screenToday - p.screenGoalMin!)} da meta. Tudo bem: amanhã é outro dia.',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: 10),
                  const InfoNote('O Foquinho não mede o tempo de tela sozinho. Copie o valor que o celular mostra em Bem-estar digital (Android) ou Tempo de Uso (iPhone).'),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _logScreen(context, today),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(screenToday == null ? 'Informar tempo de hoje' : 'Atualizar'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SectionTitle('Próxima prova ou trabalho'),
          if (exams.isEmpty)
            EmptyState(
              icon: Icons.event_outlined,
              title: 'Nenhuma prova ou trabalho cadastrado',
              text: 'Cadastre na aba Plano para receber sugestões de revisão.',
              action: OutlinedButton(onPressed: () => onGoTo(1), child: const Text('Abrir plano')),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final e in exams.take(3))
                    ListTile(
                      leading: Icon(e.kind == ExamKind.trabalho ? Icons.assignment_outlined : Icons.event_note_outlined),
                      title: Text('${d.subjectName(e.subjectId)}${e.title.isEmpty ? '' : ' · ${e.title}'}'),
                      subtitle: Text(_examWhen(e, now)),
                      trailing: TextButton(onPressed: () => _studyFor(context, e), child: const Text('Estudar')),
                    ),
                ],
              ),
            ),

          const SectionTitle('Sugestões para agora'),
          if (studySugs.isEmpty && moveSugs.isEmpty)
            const EmptyState(icon: Icons.lightbulb_outline, title: 'Ainda sem sugestões', text: 'Cadastre matérias, provas e esportes para receber ideias feitas para você.')
          else ...[
            for (final s in studySugs) SuggestionCard(s: s),
            for (final s in moveSugs) SuggestionCard(s: s),
          ],

          if (p.remindersOn && _inReminderWindow(p, now) && st.sessions == 0) ...[
            const SizedBox(height: 8),
            Card(
              color: cs.secondaryContainer,
              child: ListTile(
                leading: Icon(Icons.notifications_none, color: cs.onSecondaryContainer),
                title: Text('Lembrete gentil', style: TextStyle(color: cs.onSecondaryContainer, fontWeight: FontWeight.w600)),
                subtitle: Text('Ainda não teve estudo nem movimento hoje. Que tal 10 minutos? Sem pressa.', style: TextStyle(color: cs.onSecondaryContainer)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static bool _inReminderWindow(Profile p, DateTime now) {
    final m = now.hour * 60 + now.minute;
    final a = hmToMinutes(p.remindFrom), b = hmToMinutes(p.remindTo);
    final inWindow = a <= b ? (m >= a && m < b) : (m >= a || m < b);
    final qa = hmToMinutes(p.quietFrom), qb = hmToMinutes(p.quietTo);
    final quiet = qa <= qb ? (m >= qa && m < qb) : (m >= qa || m < qb);
    return inWindow && !quiet;
  }

  String _examWhen(Exam e, DateTime now) {
    final days = e.daysUntil(now);
    final kind = e.kind == ExamKind.trabalho ? 'Trabalho' : 'Prova';
    if (days == null) return '$kind · sem data';
    return '$kind · ${fmtDate(parseDayKey(e.date)!)} · ${relativeDays(days)}';
  }

  void _startStudy(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SessionScreen(kind: SessionKind.estudo)));
  }

  void _startMove(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SessionScreen(kind: SessionKind.exercicio)));
  }

  void _studyFor(BuildContext context, Exam e) {
    final d = AppScope.of(context).data;
    final subj = d.subjectName(e.subjectId);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SessionScreen(
        kind: SessionKind.estudo,
        presetTitle: 'Revisar para ${e.kind == ExamKind.trabalho ? 'o trabalho' : 'a prova'}: $subj${e.title.isEmpty ? '' : ' · ${e.title}'}',
        presetSubjectId: e.subjectId,
        presetTopic: e.title.isEmpty ? null : e.title,
      ),
    ));
  }

  Future<void> _logScreen(BuildContext context, String day) async {
    final state = AppScope.of(context);
    final cur = state.data.screenLog[day];
    final h = TextEditingController(text: cur == null ? '' : (cur ~/ 60).toString());
    final m = TextEditingController(text: cur == null ? '' : (cur % 60).toString());
    final r = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tempo de tela de hoje'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Copie o valor mostrado pelo celular. Fica registrado como manual.'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: h, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Horas'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: m, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minutos'))),
              ],
            ),
          ],
        ),
        actions: [
          if (cur != null) TextButton(onPressed: () => Navigator.pop(ctx, -1), child: const Text('Apagar registro')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final hh = int.tryParse(h.text.trim()) ?? 0;
              final mm = int.tryParse(m.text.trim()) ?? 0;
              if (hh < 0 || hh > 24 || mm < 0 || mm > 59 || (h.text.trim().isEmpty && m.text.trim().isEmpty)) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Use horas de 0 a 24 e minutos de 0 a 59.')));
                return;
              }
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

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cartão de sugestão com botão para começar o temporizador.
class SuggestionCard extends StatelessWidget {
  final Suggestion s;
  const SuggestionCard({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isStudy = s.kind == SuggestionKind.estudo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: isStudy ? cs.primaryContainer : cs.tertiaryContainer, borderRadius: BorderRadius.circular(10)),
              child: Icon(isStudy ? Icons.menu_book : Icons.directions_run, color: isStudy ? cs.onPrimaryContainer : cs.onTertiaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${s.reason} · ${s.minutes} min', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SessionScreen(
                          kind: isStudy ? SessionKind.estudo : SessionKind.exercicio,
                          presetTitle: s.title,
                          presetMinutes: s.minutes,
                          presetSubjectId: s.subjectId,
                          presetTopic: s.topic,
                          presetTaskId: s.taskId,
                        ),
                      )),
                      child: const Text('Começar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartão da sequência de dias (foguinho). Mostra número, frase e os últimos 7 dias.
class StreakCard extends StatelessWidget {
  final StreakInfo info;
  const StreakCard({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const flame = Color(0xFFF28C3C);
    final lit = info.count > 0;
    final now = DateTime.now();
    final title = info.count == 0
        ? 'Sequência: comece hoje'
        : '${info.count} ${info.count == 1 ? 'dia seguido' : 'dias seguidos'}';
    final weekText = [
      for (var i = 0; i < 7; i++)
        '${kWeekdayShort[DateTime(now.year, now.month, now.day - (6 - i)).weekday - 1]}: ${info.week[i] == 'ativo' ? 'feito' : info.week[i] == 'folga' ? 'folga' : 'sem sessão'}',
    ].join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          label: '$title. ${streakMessage(info)} Últimos 7 dias: $weekText.${info.best > info.count ? ' Seu recorde: ${info.best} dias.' : ''}',
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: lit ? flame.withAlpha(46) : cs.surfaceContainerHighest, shape: BoxShape.circle),
                      child: Icon(Icons.local_fire_department, size: 32, color: lit ? flame : cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                          Text(streakMessage(info), style: TextStyle(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: info.week[i] == 'ativo' ? flame : Colors.transparent,
                                border: Border.all(color: info.week[i] == 'ativo' ? flame : cs.outlineVariant, width: 2),
                              ),
                              child: info.week[i] == 'ativo'
                                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                                  : info.week[i] == 'folga'
                                      ? Icon(Icons.bedtime_outlined, size: 16, color: cs.onSurfaceVariant)
                                      : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              kWeekdayShort[DateTime(now.year, now.month, now.day - (6 - i)).weekday - 1],
                              style: TextStyle(fontSize: 11, color: i == 6 ? cs.primary : cs.onSurfaceVariant, fontWeight: i == 6 ? FontWeight.w700 : FontWeight.w400),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Um dia de folga por semana não quebra a sequência.${info.best > info.count ? ' Seu recorde: ${info.best} ${info.best == 1 ? 'dia' : 'dias'}.' : ''}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
