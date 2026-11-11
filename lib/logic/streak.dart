// Sequência de dias ("foguinho").
// Um dia conta quando há pelo menos uma sessão de estudo ou exercício registrada.
// Regra gentil: um dia de folga a cada 7 não quebra a sequência, desde que
// fique entre dois dias ativos. Sem punição: quebrou, recomeça do 1.

import '../models/models.dart';

class StreakInfo {
  /// Dias ativos seguidos (folgas não entram na conta).
  final int count;

  /// Hoje já tem sessão registrada.
  final bool todayDone;

  /// Ontem foi a folga da sequência: hoje é o último dia para mantê-la.
  final bool restedYesterday;

  /// Maior sequência já feita.
  final int best;

  /// Últimos 7 dias, do mais antigo para hoje: 'ativo', 'folga' ou 'vazio'.
  final List<String> week;

  const StreakInfo({required this.count, required this.todayDone, required this.restedYesterday, required this.best, required this.week});

  /// Próxima marca a alcançar (3, 7, 14, 30, 60, 100, depois de 100 em 100).
  int get nextMilestone {
    for (final m in const [3, 7, 14, 30, 60, 100]) {
      if (count < m) return m;
    }
    return (count ~/ 100 + 1) * 100;
  }

  bool get isMilestone => const [3, 7, 14, 30, 60].contains(count) || (count >= 100 && count % 100 == 0);
}

DateTime _prev(DateTime d) => DateTime(d.year, d.month, d.day - 1, 12);

/// Caminha para trás a partir de [start]. Devolve os dias ativos contados e os dias de folga usados.
({int count, Set<String> rests}) _walk(Set<String> active, DateTime start) {
  var d = DateTime(start.year, start.month, start.day, 12);
  var count = 0;
  var sinceRest = 7; // folga disponível no começo
  final rests = <String>{};
  var guard = 0;
  while (guard < 4000) {
    guard++;
    final k = dayKey(d);
    if (active.contains(k)) {
      count++;
    } else {
      final older = dayKey(_prev(d));
      if (sinceRest >= 7 && active.contains(older)) {
        rests.add(k);
        sinceRest = -1;
      } else {
        break;
      }
    }
    sinceRest++;
    d = _prev(d);
  }
  return (count: count, rests: rests);
}

StreakInfo computeStreak(AppData d, DateTime now) {
  final active = <String>{for (final s in d.sessions) s.day};
  final today = DateTime(now.year, now.month, now.day, 12);
  final todayKey = dayKey(today);
  final todayDone = active.contains(todayKey);
  final yesterday = _prev(today);

  final cur = _walk(active, todayDone ? today : yesterday);
  final restedYesterday = !todayDone && cur.rests.contains(dayKey(yesterday));

  var best = cur.count;
  for (final k in active) {
    final dt = parseDayKey(k);
    if (dt == null) continue;
    final c = _walk(active, dt).count;
    if (c > best) best = c;
  }

  final week = <String>[];
  for (var i = 6; i >= 0; i--) {
    final k = dayKey(DateTime(today.year, today.month, today.day - i, 12));
    week.add(active.contains(k) ? 'ativo' : (cur.rests.contains(k) ? 'folga' : 'vazio'));
  }
  return StreakInfo(count: cur.count, todayDone: todayDone, restedYesterday: restedYesterday, best: best, week: week);
}

/// Frase curta e sem cobrança para o cartão da sequência.
String streakMessage(StreakInfo s) {
  if (s.count == 0) {
    return s.best > 0
        ? 'Recomeçar faz parte. Uma sessão hoje e a sequência volta para o dia 1.'
        : 'Registre uma sessão de estudo ou exercício hoje para acender o foguinho.';
  }
  if (s.todayDone) {
    if (s.isMilestone) return 'Marca de ${s.count} dias alcançada. Bonito de ver.';
    final left = s.nextMilestone - s.count;
    return 'Hoje já contou. ${left == 1 ? 'Falta 1 dia' : 'Faltam $left dias'} para a marca de ${s.nextMilestone}.';
  }
  if (s.restedYesterday) return 'Ontem foi seu dia de folga. Uma sessão hoje mantém a sequência.';
  return 'Uma sessão hoje, mesmo de 5 minutos, mantém a sequência.';
}
