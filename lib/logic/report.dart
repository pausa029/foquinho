// Relatório por matéria: quanto estudou no período e o que está ficando para trás.

import '../models/models.dart';

class SubjectReport {
  final Subject subject;
  final int minutes;
  final int sessions;
  final int? daysSinceLast; // null = nunca estudou
  final int openMistakes;
  final int? examInDays; // prova/trabalho mais próximo
  final GradeStatus? grade; // null se não tem nota lançada
  final List<String> alerts; // motivos para dar atenção

  const SubjectReport({
    required this.subject,
    required this.minutes,
    required this.sessions,
    required this.daysSinceLast,
    required this.openMistakes,
    required this.examInDays,
    required this.grade,
    required this.alerts,
  });

  bool get behind => alerts.isNotEmpty;
}

/// [days] = tamanho do período, contando hoje (7 = semana, 30 = mês).
List<SubjectReport> subjectReport(AppData d, {required int days, DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final from = today.subtract(Duration(days: days - 1));
  final out = <SubjectReport>[];
  final totalMin = <String, int>{};
  for (final s in d.subjects) {
    var min = 0, count = 0;
    DateTime? last;
    for (final ss in d.sessions) {
      if (ss.kind != SessionKind.estudo || ss.subjectId != s.id) continue;
      final w = DateTime.fromMillisecondsSinceEpoch(ss.startedAt);
      if (last == null || w.isAfter(last)) last = w;
      if (!w.isBefore(from)) {
        min += ss.minutes;
        count++;
      }
    }
    totalMin[s.id] = min;
    final since = last == null ? null : today.difference(DateTime(last.year, last.month, last.day)).inDays;
    int? exam;
    for (final e in d.exams.where((e) => e.subjectId == s.id)) {
      final x = e.daysUntil(n);
      if (x != null && x >= 0 && (exam == null || x < exam)) exam = x;
    }
    final g = gradeStatus(d.grading, d.grades, s.id);
    final open = d.mistakes.where((e) => e.subjectId == s.id && !e.learned).length;
    out.add(SubjectReport(
      subject: s,
      minutes: min,
      sessions: count,
      daysSinceLast: since,
      openMistakes: open,
      examInDays: exam,
      grade: g.launchedMax > 0 ? g : null,
      alerts: const [],
    ));
  }
  // média de minutos por matéria no período, para comparar
  final avg = out.isEmpty ? 0 : out.fold<int>(0, (a, r) => a + r.minutes) / out.length;
  return [
    for (final r in out)
      SubjectReport(
        subject: r.subject,
        minutes: r.minutes,
        sessions: r.sessions,
        daysSinceLast: r.daysSinceLast,
        openMistakes: r.openMistakes,
        examInDays: r.examInDays,
        grade: r.grade,
        alerts: [
          if (r.examInDays != null && r.examInDays! <= 14 && r.minutes < 60)
            'Prova ${r.examInDays == 0 ? 'hoje' : r.examInDays == 1 ? 'amanhã' : 'em ${r.examInDays} dias'} e pouco estudo no período',
          if (r.daysSinceLast == null) 'Ainda não estudou pelo temporizador',
          if (r.daysSinceLast != null && r.daysSinceLast! >= 7) 'Parada há ${r.daysSinceLast} dias',
          if (r.subject.hard && avg > 0 && r.minutes < avg) 'Matéria difícil com menos tempo que as outras',
          if (r.grade != null && (r.grade!.impossible || (r.grade!.neededPct ?? 0) > 70)) 'Nota apertada: precisa de ${r.grade!.neededPct?.round() ?? 100}% no que falta',
          if (r.openMistakes >= 5) '${r.openMistakes} questões no caderno de erros',
        ],
      ),
  ]..sort((a, b) {
      final c = b.alerts.length.compareTo(a.alerts.length);
      return c != 0 ? c : b.minutes.compareTo(a.minutes);
    });
}
