// Planejamento das notificações do sistema.
// Funções puras: recebem os dados e a hora atual e devolvem a lista do que
// deve ser agendado. Quem agenda de fato é o serviço em services/notifier.dart.

import '../models/models.dart';
import 'stats.dart';
import 'streak.dart';
import 'suggestions.dart';

class PlannedNotice {
  final int id;
  final DateTime when;
  final String title;
  final String body;

  /// true = alarme do temporizador (som de alarme, horário exato).
  final bool alarm;

  /// true = o som repete até a pessoa parar (fim da sessão).
  final bool loop;

  /// true = aviso do rodízio do dia (água, alongar, estudo, revisão...).
  final bool rotating;

  /// Minutos até o aviso sumir sozinho da barra (0 = padrão do canal).
  final int ttlMin;

  const PlannedNotice({required this.id, required this.when, required this.title, required this.body, this.alarm = false, this.loop = false, this.rotating = false, this.ttlMin = 0});

  PlannedNotice withId(int newId) =>
      PlannedNotice(id: newId, when: when, title: title, body: body, alarm: alarm, loop: loop, rotating: rotating, ttlMin: ttlMin);
}

/// O minuto do dia [m] cai no período "não me incomodar"?
bool inQuietHours(Profile p, int m) {
  final a = hmToMinutes(p.quietFrom), b = hmToMinutes(p.quietTo);
  if (a == b) return false;
  return a < b ? (m >= a && m < b) : (m >= a || m < b);
}

DateTime _at(DateTime day, int minutes) => DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

/// Faixa de ids reservada aos alarmes do temporizador.
const int kTimerIdBase = 100;
const int kTimerIdCount = 30;

const List<String> kReviewTexts = [
  'Releia por 5 minutos o resumo do que estudou ontem.',
  'Tente explicar em voz alta, sem olhar, o último assunto que estudou.',
  'Faça 3 questões rápidas de uma matéria difícil.',
  'Revise as anotações da última aula antes que esfriem.',
  'Escreva num papel 3 coisas que lembra do último estudo e confira.',
];

/// Alarmes do temporizador em andamento: fim de cada fase e fim da sessão.
List<PlannedNotice> planTimerNotices(ActiveSession? a, int nowMs) {
  if (a == null || a.paused) return const [];
  final out = <PlannedNotice>[];
  var t = a.phaseEndsAt;
  var phase = a.phase;
  var idx = a.cycleIndex;
  final what = a.kind == SessionKind.estudo ? 'estudo' : 'exercício';
  // Número fixo de cada fase dentro da sessão: o id do aviso não muda quando a lista é refeita.
  var ordinal = 2 * (idx - 1) + (phase == Phase.foco ? 0 : 1);
  var guard = 0;
  while (guard < 30) {
    guard++;
    final PlannedNotice n;
    var last = false;
    if (phase == Phase.foco) {
      if (idx >= a.cycles) {
        n = PlannedNotice(
          id: 0,
          when: DateTime.fromMillisecondsSinceEpoch(t),
          title: 'Tempo concluído',
          body: '${a.title}. Abra o Foquinho para registrar seu $what.',
          alarm: true,
          loop: true,
        );
        last = true;
      } else {
        n = PlannedNotice(
          id: 0,
          when: DateTime.fromMillisecondsSinceEpoch(t),
          title: 'Hora do intervalo',
          body: 'Descanse ${a.breakMin} min: levante, beba água, olhe para longe.',
          alarm: true,
        );
        phase = Phase.intervalo;
      }
    } else {
      idx++;
      n = PlannedNotice(
        id: 0,
        when: DateTime.fromMillisecondsSinceEpoch(t),
        title: 'De volta ao foco',
        body: 'Ciclo $idx de ${a.cycles}: ${a.title}.',
        alarm: true,
      );
      phase = Phase.foco;
    }
    if (t > nowMs) out.add(n.withId(kTimerIdBase + ordinal));
    ordinal++;
    if (last) break;
    t += (phase == Phase.foco ? a.focusMin : a.breakMin) * 60000;
  }
  return out;
}

/// Lembretes dos próximos [days] dias: estudo, revisão,
/// tarefas com prazo e provas. Respeita o período "não me incomodar".
const List<String> kWaterTexts = [
  'Um copo de água agora ajuda a manter o foco.',
  'Hora de se hidratar. Aproveite e levante um pouco.',
];
const List<String> kStretchTexts = [
  'Gire os ombros e estique os braços e o pescoço por um minuto.',
  'Levante, estique as pernas e respire fundo três vezes.',
  'Solte os punhos e as mãos. Olhe para longe por alguns segundos.',
];

const kTipThemes = ['agua', 'estudo', 'alongar', 'compromisso', 'revisar'];

/// Ordem dos temas na rodada [round]. Muda a cada rodada (parece sorteio, mas é
/// sempre igual para a mesma rodada) e nunca começa pelo tema que fechou a anterior:
/// assim dois avisos seguidos nunca falam do mesmo assunto.
List<String> themeOrder(int round, {bool withCommitments = true}) {
  List<String> raw(int r) {
    final l = kTipThemes.where((t) => withCommitments || t != 'compromisso').toList();
    var x = (r * 131 + 17) % 65537;
    for (var i = l.length - 1; i > 0; i--) {
      x = (x * 75 + 74) % 65537;
      final j = x % (i + 1);
      final t = l[i];
      l[i] = l[j];
      l[j] = t;
    }
    return l;
  }

  final cur = raw(round);
  if (round > 0 && raw(round - 1).last == cur.first) {
    final t = cur[0];
    cur[0] = cur[1];
    cur[1] = t;
  }
  return cur;
}

/// Compromissos para o tema "compromisso" no dia [day]: primeiro o que é de hoje
/// ("já fez?"), depois provas chegando e tarefas pendentes.
List<List<String>> commitmentTips(AppData d, DateTime day) {
  final key = dayKey(day);
  final items = dueItems(d, day);
  final exams = d.exams.where((e) {
    final n = e.daysUntil(day);
    return n != null && n >= 1 && n <= 14;
  }).toList()
    ..sort((a, b) => a.daysUntil(day)!.compareTo(b.daysUntil(day)!));
  for (final e in exams) {
    final kind = e.kind == ExamKind.trabalho ? 'Trabalho' : 'Prova';
    final name = '${d.subjectName(e.subjectId)}${e.title.isEmpty ? '' : ': ${e.title}'}';
    items.add(['$kind chegando', '$name, ${relativeDays(e.daysUntil(day)!)}. Dez minutos de revisão hoje ajudam.']);
  }
  for (final t in d.tasks.where((t) => t.status != TaskStatus.done)) {
    final dl = parseDayKey(t.deadline);
    if (dl != null && t.deadline!.compareTo(key) <= 0) continue; // já está em "para hoje" ou "atrasada"
    items.add(['Tarefa pendente', '${d.subjectName(t.subjectId)} · ${t.topic}${dl == null ? '' : ', prazo ${fmtDay(t.deadline!)}'}.']);
  }
  return items;
}

/// Rodízio de avisos: água, estudo, alongar, compromisso e revisão.
/// Devolve [título, texto] para a posição [g], usando só o que foi cadastrado.
/// Cada tema aparece uma vez por rodada; sem compromissos, esse tema fica de fora.
List<String> rotatingTip(AppData d, DateTime now, int g, List<Suggestion> study, List<Suggestion> move, {DateTime? day}) {
  final items = commitmentTips(d, day ?? now);
  final n = items.isEmpty ? kTipThemes.length - 1 : kTipThemes.length;
  final round = g ~/ n;
  final type = themeOrder(round, withCommitments: items.isNotEmpty)[g % n];
  if (type == 'compromisso') return items[round % items.length];
  switch (type) {
    case 'agua':
      return ['Beba água', kWaterTexts[round % kWaterTexts.length]];
    case 'alongar':
      return ['Alongue o corpo', kStretchTexts[round % kStretchTexts.length]];
    case 'estudo':
      return ['Que tal estudar um pouco?', study.isEmpty ? 'Dez minutos de estudo agora já contam.' : '${study[round % study.length].title}.'];
    case 'movimento':
      return ['Movimente-se', move.isEmpty ? 'Uma pausa ativa de 5 minutos faz bem.' : '${move[round % move.length].title} (${move[round % move.length].minutes} min).'];
    default:
      return ['Hora de revisar', kReviewTexts[round % kReviewTexts.length]];
  }
}

/// Revisões pendentes no dia de [when] (inclui as atrasadas).
List<String> reviewsDueOn(AppData d, DateTime when) {
  final k = dayKey(when);
  return [
    for (final r in d.reviews)
      if (!r.done && r.due.compareTo(k) <= 0) '${d.subjectName(r.subjectId)}${r.topic == null ? '' : ' · ${r.topic}'}',
  ];
}

/// Texto de um tema do rodízio; [idx] = quantas vezes o tema já apareceu.
List<String> _themeTip(String theme, int idx, List<List<String>> items, List<Suggestion> study, List<String> reviews) {
  switch (theme) {
    case 'compromisso':
      return items[idx % items.length];
    case 'agua':
      return ['Beba água', kWaterTexts[idx % kWaterTexts.length]];
    case 'alongar':
      return ['Alongue o corpo', kStretchTexts[idx % kStretchTexts.length]];
    case 'estudo':
      return ['Que tal estudar um pouco?', study.isEmpty ? 'Dez minutos de estudo agora já contam.' : '${study[idx % study.length].title}.'];
    default:
      if (reviews.isNotEmpty) return ['Hora de revisar', 'Revisão de hoje: ${reviews[idx % reviews.length]}. 15 minutos bastam.'];
      return ['Hora de revisar', kReviewTexts[idx % kReviewTexts.length]];
  }
}

/// Compromissos do dia [day] que ainda pedem atenção: tarefas com prazo no dia
/// (ou atrasadas) que não foram concluídas, e provas ou trabalhos marcados para o dia.
/// Devolve pares [título, texto] no tom "já fez?".
List<List<String>> dueItems(AppData d, DateTime day, {bool includeExams = true}) {
  final key = dayKey(day);
  final out = <List<String>>[];
  for (final t in d.tasks) {
    if (t.status == TaskStatus.done || t.deadline == null || parseDayKey(t.deadline) == null) continue;
    final name = '${d.subjectName(t.subjectId)} · ${t.topic}';
    if (t.deadline == key) {
      out.add(['Atividade para hoje: já fez?', '$name. Se já fez, marque como concluída no Foquinho.']);
    } else if (t.deadline!.compareTo(key) < 0) {
      out.add(['Atividade atrasada', '$name (prazo ${fmtDay(t.deadline!)}). Dá para resolver hoje? Se já fez, marque como concluída.']);
    }
  }
  if (includeExams) {
    for (final e in d.exams) {
      if (e.date != key) continue;
      final name = '${d.subjectName(e.subjectId)}${e.title.isEmpty ? '' : ': ${e.title}'}';
      if (e.kind == ExamKind.trabalho) {
        out.add(['Trabalho para hoje: já fez?', '$name. Confira se está pronto para entregar.']);
      } else {
        out.add(['Prova hoje', '$name. Uma revisão rápida de 10 minutos ainda ajuda.']);
      }
    }
  }
  return out;
}

List<PlannedNotice> planReminderNotices(AppData d, DateTime now, {int days = 7, int nudgeDays = 3, int max = 150}) {
  final p = d.profile;
  if (p == null || !p.remindersOn) return const [];
  final out = <PlannedNotice>[];
  final today = DateTime(now.year, now.month, now.day);
  final winFrom = hmToMinutes(p.remindFrom);
  final winTo = hmToMinutes(p.remindTo);
  final studyAt = hmToMinutes(p.studyRemindAt);

  void add(DateTime when, String title, String body) {
    if (!when.isAfter(now)) return;
    if (inQuietHours(p, when.hour * 60 + when.minute)) return;
    out.add(PlannedNotice(id: 0, when: when, title: title, body: body));
  }

  final st = dayStats(d, dayKey(now));
  final studySug = studySuggestions(d, now: now, limit: 1);

  // Dias com sessão planejada já têm o aviso da própria sessão: sem "Hora de estudar" repetido.
  final plannedDays = <String>{
    if (!d.plan.paused)
      for (final ps in d.planSessions)
        if (ps.state == PlanState.planejada) dayKey(ps.dateTime),
  };

  for (var i = 0; i < days; i++) {
    final day = DateTime(today.year, today.month, today.day + i);

    if (p.studyRemindOn && !plannedDays.contains(dayKey(day)) && !(i == 0 && st.studyMin >= p.studyGoalMin)) {
      add(
        _at(day, studyAt),
        'Hora de estudar',
        studySug.isNotEmpty ? studySug.first.title : 'Que tal ${fmtMin(p.studyGoalMin)} de estudo hoje? Comece com 10 minutos.',
      );
    }
  }

  // Rodízio do dia: horários a cada N minutos. Os temas são escolhidos no fim,
  // depois de saber quais horários sobram (longe dos outros avisos).
  final rotSlots = <DateTime>[];
  if (p.nudgeOn && winFrom < winTo && p.nudgeEveryMin >= 30) {
    for (var i = 0; i < nudgeDays && i < days; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      for (var m = winFrom + p.nudgeEveryMin; m < winTo; m += p.nudgeEveryMin) {
        final when = _at(day, m);
        if (!when.isAfter(now) || inQuietHours(p, m)) continue;
        rotSlots.add(when);
      }
    }
  }

  // Tarefas e provas: no máximo UM aviso de manhã e UM no fim da tarde por dia,
  // juntando tudo o que vence (várias tarefas não viram várias notificações).
  final morning = <String, List<List<String>>>{};
  final evening = <String, List<List<String>>>{};
  void put(Map<String, List<List<String>>> m, DateTime day, String label, String text) {
    m.putIfAbsent(dayKey(day), () => <List<String>>[]).add([label, text]);
  }

  for (final t in d.tasks) {
    if (t.status == TaskStatus.done) continue;
    final dl = parseDayKey(t.deadline);
    if (dl == null) continue;
    final name = '${d.subjectName(t.subjectId)} · ${t.topic}';
    put(morning, DateTime(dl.year, dl.month, dl.day - 1), 'Tarefa para amanhã', name);
    put(morning, DateTime(dl.year, dl.month, dl.day), 'Prazo hoje', name);
  }
  for (final e in d.exams) {
    final dt = parseDayKey(e.date);
    if (dt == null) continue;
    final kind = e.kind == ExamKind.trabalho ? 'Trabalho' : 'Prova';
    final name = '${d.subjectName(e.subjectId)}${e.title.isEmpty ? '' : ': ${e.title}'}';
    put(evening, DateTime(dt.year, dt.month, dt.day - 3), '$kind em 3 dias', name);
    put(evening, DateTime(dt.year, dt.month, dt.day - 1), '$kind amanhã', name);
    put(morning, DateTime(dt.year, dt.month, dt.day), '$kind hoje', name);
  }
  // Revisões espaçadas: entram no aviso da manhã do dia em que vencem (atrasadas, hoje).
  for (final r in d.reviews) {
    if (r.done) continue;
    final due = parseDayKey(r.due);
    if (due == null) continue;
    final day = due.isBefore(today) ? today : due;
    put(morning, day, 'Revisão hoje', '${d.subjectName(r.subjectId)}${r.topic == null ? '' : ' · ${r.topic}'}');
  }
  void digest(Map<String, List<List<String>>> m, int minutes, String manyTitle) {
    m.forEach((k, items) {
      final day = parseDayKey(k);
      if (day == null) return;
      if (items.length == 1) {
        add(_at(day, minutes), items.first[0], '${items.first[1]}.');
      } else {
        final shown = items.take(3).map((x) => '${x[0]}: ${x[1]}').join(' · ');
        final extra = items.length > 3 ? ' · e mais ${items.length - 3}' : '';
        add(_at(day, minutes), manyTitle, '$shown$extra.');
      }
    });
  }

  digest(morning, winFrom + 5, 'Tarefas e provas de hoje');
  digest(evening, inQuietHours(p, 18 * 60) ? winFrom + 20 : 18 * 60, 'Provas e trabalhos chegando');

  // Planejamento: aviso 10 minutos antes de cada sessão planejada.
  if (!d.plan.paused) {
    for (final ps in d.planSessions) {
      if (ps.state != PlanState.planejada) continue;
      add(
        ps.dateTime.subtract(const Duration(minutes: 10)),
        'Sessão de estudo em 10 minutos',
        '${d.subjectName(ps.subjectId)}${ps.topic == null ? '' : ': ${ps.topic}'}, ${ps.minutes} min.',
      );
    }
  }

  // Sequência: um aviso à noite, só hoje e só se ainda falta a sessão do dia.
  final streak = computeStreak(d, now);
  if (streak.count >= 2 && !streak.todayDone) {
    final at = inQuietHours(p, 20 * 60) ? winTo - 30 : 20 * 60;
    add(_at(today, at), 'Sua sequência de ${streak.count} dias', 'Uma sessão hoje, mesmo de 5 minutos, mantém o foguinho aceso.');
  }

  final horizon = now.add(Duration(days: days));
  // Só um aviso por vez: o rodízio cede a vez quando há outro aviso a menos de 30 minutos.
  // Cada tema só volta depois de passarem os outros: em qualquer sequência de 4 avisos,
  // os assuntos são diferentes. Entre os temas livres, vai o menos usado.
  final fixed = out.map((n) => n.when).toList();
  if (rotSlots.isNotEmpty) {
    final studyPool = studySuggestions(d, now: now, limit: 6);
    final recent = <String>[];
    final used = <String, int>{};
    var k = 0;
    for (final when in rotSlots) {
      if (fixed.any((t) => t.difference(when).inMinutes.abs() < 30)) continue;
      final items = commitmentTips(d, when);
      final themes = kTipThemes.where((t) => items.isNotEmpty || t != 'compromisso').toList();
      final block = themes.length - 1 < 3 ? themes.length - 1 : 3;
      final last = recent.length > block ? recent.sublist(recent.length - block) : recent;
      final cands = themes.where((t) => !last.contains(t)).toList();
      var minU = 1 << 30;
      for (final t in cands) {
        if ((used[t] ?? 0) < minU) minU = used[t] ?? 0;
      }
      final pool = cands.where((t) => (used[t] ?? 0) == minU).toList();
      final theme = pool[(k * 7 + when.day) % pool.length];
      final idx = used[theme] ?? 0;
      used[theme] = idx + 1;
      recent.add(theme);
      k++;
      final tip = _themeTip(theme, idx, items, studyPool, reviewsDueOn(d, when));
      out.add(PlannedNotice(id: 0, when: when, title: tip[0], body: tip[1], rotating: true, ttlMin: p.nudgeEveryMin));
    }
  }
  final list = out.where((n) => n.when.isBefore(horizon)).toList()..sort((a, b) => a.when.compareTo(b.when));
  final capped = list.take(max).toList();
  return [for (var i = 0; i < capped.length; i++) capped[i].withId(1000 + i)];
}
