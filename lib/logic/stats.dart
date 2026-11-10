// Resumos diários e semanais. Só usa sessões realmente registradas e
// tempo de tela informado manualmente. Dia sem registro = "sem dados".

import '../models/models.dart';

class DayStats {
  final String day;
  final int studyMin;
  final int moveMin;
  final int sessions;
  final int? screenMin; // null = sem dados
  final Map<String, int> bySubject; // subjectId -> minutos

  const DayStats({
    required this.day,
    required this.studyMin,
    required this.moveMin,
    required this.sessions,
    required this.screenMin,
    required this.bySubject,
  });

  bool get hasData => sessions > 0 || screenMin != null;
}

class WeekStats {
  final String start; // segunda-feira
  final List<DayStats> days;
  final int studyMin;
  final int moveMin;
  final int sessions;
  final int studyDays;
  final int moveDays;
  final int screenDays;
  final int screenSum;
  final Map<String, int> bySubject;

  const WeekStats({
    required this.start,
    required this.days,
    required this.studyMin,
    required this.moveMin,
    required this.sessions,
    required this.studyDays,
    required this.moveDays,
    required this.screenDays,
    required this.screenSum,
    required this.bySubject,
  });

  double? get screenAvg => screenDays == 0 ? null : screenSum / screenDays;
}

DayStats dayStats(AppData d, String day) {
  var study = 0, move = 0, n = 0;
  final bySubject = <String, int>{};
  for (final s in d.sessions) {
    if (s.day != day) continue;
    n++;
    if (s.kind == SessionKind.estudo) {
      study += s.minutes;
      if (s.subjectId != null) {
        bySubject[s.subjectId!] = (bySubject[s.subjectId!] ?? 0) + s.minutes;
      }
    } else {
      move += s.minutes;
    }
  }
  return DayStats(
    day: day,
    studyMin: study,
    moveMin: move,
    sessions: n,
    screenMin: d.screenLog[day],
    bySubject: bySubject,
  );
}

/// Segunda-feira da semana que contém [date].
DateTime weekStart(DateTime date) {
  final d = DateTime(date.year, date.month, date.day, 12);
  return d.subtract(Duration(days: d.weekday - 1));
}

WeekStats weekStats(AppData d, DateTime start) {
  final days = <DayStats>[];
  var study = 0, move = 0, n = 0, sd = 0, md = 0, scd = 0, scs = 0;
  final bySubject = <String, int>{};
  for (var i = 0; i < 7; i++) {
    final dt = DateTime(start.year, start.month, start.day + i, 12);
    final s = dayStats(d, dayKey(dt));
    days.add(s);
    study += s.studyMin;
    move += s.moveMin;
    n += s.sessions;
    if (s.studyMin > 0) sd++;
    if (s.moveMin > 0) md++;
    if (s.screenMin != null) {
      scd++;
      scs += s.screenMin!;
    }
    s.bySubject.forEach((k, v) => bySubject[k] = (bySubject[k] ?? 0) + v);
  }
  return WeekStats(
    start: dayKey(start),
    days: days,
    studyMin: study,
    moveMin: move,
    sessions: n,
    studyDays: sd,
    moveDays: md,
    screenDays: scd,
    screenSum: scs,
    bySubject: bySubject,
  );
}

String fmtMin(num m) {
  final n = m.round();
  if (n < 60) return '$n min';
  final h = n ~/ 60;
  final r = n % 60;
  return r == 0 ? '${h}h' : '${h}h${r.toString().padLeft(2, '0')}';
}

String fmtClock(int ms) {
  final s = (ms / 1000).ceil();
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}

const List<String> kWeekdayShort = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

String fmtDay(String key) {
  final p = key.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}' : key;
}

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String relativeDays(int days) {
  if (days == 0) return 'hoje';
  if (days == 1) return 'amanhã';
  if (days < 0) return 'há ${-days} dia${days == -1 ? '' : 's'}';
  return 'em $days dias';
}
