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

  const PlannedNotice({required this.id, required this.when, required this.title, required this.body, this.alarm = false, this.loop = false});

  PlannedNotice withId(int newId) => PlannedNotice(id: newId, when: when, title: title, body: body, alarm: alarm, loop: loop);
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

const List<String> kNudgeTexts = [
  'Se você está no celular há um tempo, levante, alongue o corpo e beba água.',
  'Pausa de tela: olhe para longe por um minuto e respire fundo.',
  'Que tal trocar 10 minutos de tela por uma caminhada curta?',
  'Deixe o celular de lado um pouco. Seu plano de estudo está esperando.',
  'Hora boa para uma pausa ativa de 5 minutos.',
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

/// Lembretes dos próximos [days] dias: estudo, movimento, pausas de tela,
/// tarefas com prazo e provas. Respeita o período "não me incomodar".
List<PlannedNotice> planReminderNotices(AppData d, DateTime now, {int days = 7, int max = 50}) {
  final p = d.profile;
  if (p == null || !p.remindersOn) return const [];
  final out = <PlannedNotice>[];
  final today = DateTime(now.year, now.month, now.day);
  final winFrom = hmToMinutes(p.remindFrom);
  final winTo = hmToMinutes(p.remindTo);
  final studyAt = hmToMinutes(p.studyRemindAt);
  final moveAt = hmToMinutes(p.moveRemindAt);

  void add(DateTime when, String title, String body) {
    if (!when.isAfter(now)) return;
    if (inQuietHours(p, when.hour * 60 + when.minute)) return;
    out.add(PlannedNotice(id: 0, when: when, title: title, body: body));
  }

  final st = dayStats(d, dayKey(now));
  final studySug = studySuggestions(d, now: now, limit: 1);
  final moveSug = moveSuggestions(d, limit: 1);

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
    if (p.moveRemindOn && !(i == 0 && st.moveMin >= p.moveGoalMin)) {
      add(
        _at(day, moveAt),
        'Hora de se mexer',
        moveSug.isNotEmpty ? '${moveSug.first.title} (${moveSug.first.minutes} min).' : 'Uma pausa ativa de 10 minutos já ajuda.',
      );
    }
    if (p.nudgeOn && winFrom < winTo && p.nudgeEveryMin >= 30) {
      var k = 0;
      for (var m = winFrom + p.nudgeEveryMin; m < winTo; m += p.nudgeEveryMin) {
        k++;
        final nearStudy = p.studyRemindOn && (m - studyAt).abs() < 20;
        final nearMove = p.moveRemindOn && (m - moveAt).abs() < 20;
        if (nearStudy || nearMove) continue;
        add(_at(day, m), 'Pausa de tela', kNudgeTexts[(i + k) % kNudgeTexts.length]);
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
  // Nenhuma pausa de tela a menos de 45 minutos de outro aviso: evita vários de uma vez.
  final others = out.where((n) => n.title != 'Pausa de tela').map((n) => n.when).toList();
  out.removeWhere((n) => n.title == 'Pausa de tela' && others.any((t) => t.difference(n.when).inMinutes.abs() < 45));
  final list = out.where((n) => n.when.isBefore(horizon)).toList()..sort((a, b) => a.when.compareTo(b.when));
  final capped = list.take(max).toList();
  return [for (var i = 0; i < capped.length; i++) capped[i].withId(1000 + i)];
}
