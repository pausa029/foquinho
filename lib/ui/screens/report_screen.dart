// Relatório por matéria: semana ou mês.

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../logic/report.dart';
import '../../logic/stats.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import 'quiz_screen.dart';
import 'session_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int days = 7;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final d = state.data;
    final cs = Theme.of(context).colorScheme;
    final rows = subjectReport(d, days: days);
    final total = rows.fold<int>(0, (a, r) => a + r.minutes);
    final maxMin = rows.fold<int>(0, (a, r) => r.minutes > a ? r.minutes : a);
    final behind = rows.where((r) => r.behind).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Relatório por matéria')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SegmentedButton<int>(
            segments: const [ButtonSegment(value: 7, label: Text('Últimos 7 dias')), ButtonSegment(value: 30, label: Text('Últimos 30 dias'))],
            selected: {days},
            onSelectionChanged: (s) => setState(() => days = s.first),
          ),
          const SizedBox(height: 12),
          Text('Total: ${fmtMin(total)} de estudo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (d.subjects.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: EmptyState(icon: Icons.school_outlined, title: 'Cadastre suas matérias', text: 'Em Plano → Matérias.'),
            ),
          if (behind.isNotEmpty) ...[
            const SectionTitle('Ficando para trás'),
            for (final r in behind)
              Card(
                color: cs.errorContainer.withValues(alpha: 0.35),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.subject.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      for (final a in r.alerts) Text('• $a'),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => SessionScreen(kind: SessionKind.estudo, presetTitle: r.subject.name, presetMinutes: 25, presetSubjectId: r.subject.id),
                            )),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Estudar 25 min'),
                          ),
                          if (state.signedIn)
                            TextButton.icon(
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QuizScreen(subjectId: r.subject.id))),
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('Quiz'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SectionTitle('Tempo por matéria'),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(r.subject.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(r.minutes == 0 ? 'nada' : fmtMin(r.minutes)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: maxMin == 0 ? 0 : r.minutes / maxMin,
                      minHeight: 10,
                      color: r.behind ? cs.error : cs.primary,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      '${r.sessions} ${r.sessions == 1 ? 'sessão' : 'sessões'}',
                      r.daysSinceLast == null ? 'nunca estudou' : (r.daysSinceLast == 0 ? 'estudou hoje' : 'último estudo há ${r.daysSinceLast} ${r.daysSinceLast == 1 ? 'dia' : 'dias'}'),
                      if (r.grade != null) 'nota ${fmtPts(r.grade!.earned)}',
                      if (r.openMistakes > 0) '${r.openMistakes} no caderno de erros',
                    ].join(' · '),
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
          const InfoNote('O relatório usa só as sessões feitas no temporizador com matéria escolhida.'),
        ],
      ),
    );
  }
}
