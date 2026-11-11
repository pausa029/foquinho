import 'package:flutter_test/flutter_test.dart';
import 'package:foquinho/logic/streak.dart';
import 'package:foquinho/models/models.dart';

AppData withDays(List<String> days) {
  final d = AppData(profile: Profile(nickname: 'x'));
  for (final k in days) {
    final dt = parseDayKey(k)!;
    d.sessions.add(Session(id: k, kind: SessionKind.estudo, title: 't', minutes: 10, startedAt: dt.millisecondsSinceEpoch));
  }
  return d;
}

void main() {
  final now = DateTime(2026, 6, 10, 15); // quarta-feira

  test('sem sessões: zero', () {
    final s = computeStreak(withDays([]), now);
    expect(s.count, 0);
    expect(s.todayDone, isFalse);
    expect(s.best, 0);
    expect(s.week, List.filled(7, 'vazio'));
  });

  test('dias seguidos até hoje', () {
    final s = computeStreak(withDays(['2026-06-08', '2026-06-09', '2026-06-10']), now);
    expect(s.count, 3);
    expect(s.todayDone, isTrue);
    expect(s.isMilestone, isTrue);
    expect(s.nextMilestone, 7);
    expect(s.week.sublist(4), ['ativo', 'ativo', 'ativo']);
  });

  test('hoje ainda pendente: a sequência de ontem continua valendo', () {
    final s = computeStreak(withDays(['2026-06-08', '2026-06-09']), now);
    expect(s.count, 2);
    expect(s.todayDone, isFalse);
    expect(s.restedYesterday, isFalse);
  });

  test('um dia de folga entre dias ativos não quebra', () {
    final s = computeStreak(withDays(['2026-06-06', '2026-06-07', '2026-06-09', '2026-06-10']), now);
    expect(s.count, 4);
    expect(s.week[4], 'folga'); // segunda, 08/06
  });

  test('duas faltas na mesma semana quebram', () {
    final s = computeStreak(withDays(['2026-06-04', '2026-06-06', '2026-06-08', '2026-06-10']), now);
    expect(s.count, 2, reason: 'conta 10 e 08 (folga em 09); a falta de 07 encerra');
  });

  test('ontem foi a folga e hoje está pendente', () {
    final s = computeStreak(withDays(['2026-06-07', '2026-06-08']), now);
    expect(s.count, 2);
    expect(s.restedYesterday, isTrue);
    expect(streakMessage(s), contains('folga'));
  });

  test('dois dias sem sessão: recomeça, mas guarda o recorde', () {
    final s = computeStreak(withDays(['2026-06-01', '2026-06-02', '2026-06-03', '2026-06-04', '2026-06-07']), now);
    expect(s.count, 0);
    expect(s.best, 4);
    expect(streakMessage(s), contains('Recomeçar'));
  });
}
