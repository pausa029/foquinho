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

  for (var i = 0; i < days; i++) {
    final day = DateTime(today.year, today.month, today.day + i);

    if (p.studyRemindOn && !(i == 0 && st.studyMin >= p.studyGoalMin)) {
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

  // Tarefas com prazo: na véspera e no dia.
  var stagger = 0;
  for (final t in d.tasks) {
    if (t.status == TaskStatus.done) continue;
    final dl = parseDayKey(t.deadline);
    if (dl == null) continue;
    final name = '${d.subjectName(t.subjectId)} · ${t.topic}';
    final base = winFrom + 5 + (stagger % 10);
    stagger++;
    add(_at(DateTime(dl.year, dl.month, dl.day - 1), base), 'Tarefa para amanhã', '$name (${fmtMin(t.minutes)}).');
    add(_at(DateTime(dl.year, dl.month, dl.day), base), 'Prazo hoje', '$name. Um bloco de foco resolve?');
  }

  // Provas e trabalhos: 3 dias antes, na véspera e no dia.
  for (final e in d.exams) {
    final dt = parseDayKey(e.date);
    if (dt == null) continue;
    final kind = e.kind == ExamKind.trabalho ? 'Trabalho' : 'Prova';
    final name = '${d.subjectName(e.subjectId)}${e.title.isEmpty ? '' : ': ${e.title}'}';
    final evening = inQuietHours(p, 18 * 60) ? winFrom + 15 : 18 * 60;
    add(_at(DateTime(dt.year, dt.month, dt.day - 3), evening), '$kind em 3 dias', '$name. Revise 10 minutos hoje.');
    add(_at(DateTime(dt.year, dt.month, dt.day - 1), evening), '$kind amanhã', '$name. Uma revisão curta e depois descanso.');
    add(_at(DateTime(dt.year, dt.month, dt.day), winFrom + 2), '$kind hoje', '$name. Vai dar certo!');
  }

  // Sequência: um aviso à noite, só hoje e só se ainda falta a sessão do dia.
  final streak = computeStreak(d, now);
  if (streak.count >= 2 && !streak.todayDone) {
    final at = inQuietHours(p, 20 * 60) ? winTo - 30 : 20 * 60;
    add(_at(today, at), 'Sua sequência de ${streak.count} dias', 'Uma sessão hoje, mesmo de 5 minutos, mantém o foguinho aceso.');
  }

  final horizon = now.add(Duration(days: days));
  final list = out.where((n) => n.when.isBefore(horizon)).toList()..sort((a, b) => a.when.compareTo(b.when));
  final capped = list.take(max).toList();
  return [for (var i = 0; i < capped.length; i++) capped[i].withId(1000 + i)];
}
