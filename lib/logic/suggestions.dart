// Sugestões personalizadas de estudo e movimento.
// Usa somente o que o estudante cadastrou: matérias, dificuldades, provas,
// tarefas e esportes. Não inventa dados escolares.

import '../models/models.dart';

enum SuggestionKind { estudo, exercicio }

class Suggestion {
  final SuggestionKind kind;
  final String title;
  final String reason;
  final int minutes;
  final String? subjectId;
  final String? topic;
  final String? taskId;
  final Activity? activity;

  const Suggestion({
    required this.kind,
    required this.title,
    required this.reason,
    required this.minutes,
    this.subjectId,
    this.topic,
    this.taskId,
    this.activity,
  });
}

/// Sugestões de estudo, da mais urgente para a menos urgente.
List<Suggestion> studySuggestions(AppData d, {DateTime? now, int limit = 6}) {
  final n = now ?? DateTime.now();
  final out = <Suggestion>[];
  final seen = <String>{};

  void add(Suggestion s) {
    final key = '${s.subjectId}|${s.topic}|${s.title}';
    if (seen.contains(key)) return;
    seen.add(key);
    out.add(s);
  }

  // 1. Provas e trabalhos próximos.
  final exams = d.exams.where((e) {
    final days = e.daysUntil(n);
    return days == null || days >= 0;
  }).toList()
    ..sort((a, b) => (a.daysUntil(n) ?? 9999).compareTo(b.daysUntil(n) ?? 9999));
  for (final e in exams) {
    final subj = d.subjectById(e.subjectId);
    if (subj == null) continue;
    final days = e.daysUntil(n);
    final what = e.title.isEmpty ? subj.name : '${subj.name}: ${e.title}';
    final whenTxt = days == null
        ? 'sem data marcada'
        : (days == 0 ? 'é hoje' : days == 1 ? 'é amanhã' : 'em $days dias');
    final isWork = e.kind == ExamKind.trabalho;
    add(Suggestion(
      kind: SuggestionKind.estudo,
      title: isWork ? 'Avance 25 minutos no trabalho de $what' : 'Revise por 10 minutos um assunto da prova: $what',
      reason: '${isWork ? 'Trabalho' : 'Prova'} de ${subj.name} $whenTxt.',
      minutes: isWork ? 25 : 10,
      subjectId: subj.id,
      topic: e.title.isEmpty ? null : e.title,
    ));
  }

  // 2. Matérias marcadas como difíceis.
  for (final s in d.subjects.where((s) => s.hard)) {
    final topic = s.topics.isNotEmpty ? s.topics.first : null;
    add(Suggestion(
      kind: SuggestionKind.estudo,
      title: 'Faça algumas questões de ${s.name}${topic != null ? ' sobre $topic' : ''}',
      reason: 'Você marcou ${s.name} como matéria difícil. Pouco e sempre funciona.',
      minutes: 20,
      subjectId: s.id,
      topic: topic,
    ));
  }

  // 3. Tarefas pendentes, com prazo primeiro.
  final tasks = d.tasks.where((t) => t.status != TaskStatus.done).toList()
    ..sort((a, b) => (a.deadline ?? '9999').compareTo(b.deadline ?? '9999'));
  for (final t in tasks) {
    final subj = d.subjectById(t.subjectId);
    if (subj == null) continue;
    add(Suggestion(
      kind: SuggestionKind.estudo,
      title: '${t.status == TaskStatus.doing ? 'Continue' : 'Comece'} a tarefa: ${subj.name} · ${t.topic}',
      reason: t.deadline != null ? 'Prazo: ${t.deadline!.split('-').reversed.join('/')}.' : 'Tarefa do seu plano de estudo.',
      minutes: t.minutes,
      subjectId: subj.id,
      topic: t.topic,
      taskId: t.id,
    ));
  }

  // 4. Assuntos cadastrados nas outras matérias.
  for (final s in d.subjects.where((s) => !s.hard)) {
    for (final topic in s.topics) {
      add(Suggestion(
        kind: SuggestionKind.estudo,
        title: 'Revise $topic (${s.name}) por 15 minutos',
        reason: 'Assunto que você anotou para ${s.name}.',
        minutes: 15,
        subjectId: s.id,
        topic: topic,
      ));
    }
  }

  // 5. Matérias sem nada específico.
  for (final s in d.subjects.where((s) => !s.hard && s.topics.isEmpty)) {
    add(Suggestion(
      kind: SuggestionKind.estudo,
      title: 'Releia as anotações de hoje de ${s.name}',
      reason: 'Revisar no mesmo dia ajuda a lembrar depois.',
      minutes: 10,
      subjectId: s.id,
    ));
  }

  return out.take(limit).toList();
}

/// Sugestões de movimento conforme esportes preferidos, tempo disponível e local.
List<Suggestion> moveSuggestions(
  AppData d, {
  int? maxMinutes,
  Place? place,
  int limit = 6,
}) {
  final prefs = d.profile?.sports ?? const <String>[];
  var list = d.activities.where((a) {
    if (maxMinutes != null && a.minutes > maxMinutes) return false;
    if (place != null && place != Place.qualquer && a.place != place && a.place != Place.qualquer) return false;
    return true;
  }).toList();

  int score(Activity a) {
    var s = 0;
    if (prefs.any((p) => p.toLowerCase() == a.sport.toLowerCase())) s += 100;
    if (a.sport == 'Alongamento') s += 5; // pausa ativa serve sempre
    return s;
  }

  list.sort((a, b) {
    final c = score(b).compareTo(score(a));
    return c != 0 ? c : a.minutes.compareTo(b.minutes);
  });

  return list.take(limit).map((a) {
    final liked = prefs.any((p) => p.toLowerCase() == a.sport.toLowerCase());
    return Suggestion(
      kind: SuggestionKind.exercicio,
      title: a.name,
      reason: liked ? 'Você escolheu ${a.sport} entre os seus esportes.' : '${a.sport} · ${placeLabel(a.place)}',
      minutes: a.minutes,
      activity: a,
    );
  }).toList();
}

/// Uma frase curta para o painel, com base no dia (sem culpa, sem bronca).
String homeMessage({required int studyMin, required int moveMin, required int studyGoal, required int moveGoal}) {
  if (studyMin >= studyGoal && moveMin >= moveGoal) return 'Metas de hoje alcançadas. Você pode parar por aqui ou continuar no seu ritmo.';
  if (studyMin > 0 && moveMin > 0) return 'Hoje já teve estudo e movimento. Bom equilíbrio.';
  if (studyMin > 0) return 'Você já estudou hoje. Uma pausa ativa cai bem.';
  if (moveMin > 0) return 'Corpo em movimento hoje. Que tal alguns minutos de estudo?';
  return 'Qualquer começo vale, até 5 minutos.';
}
