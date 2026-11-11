// Planejamento de estudos: distribui sessões pelos dias e horários livres.
// Algoritmo determinístico, sem IA e sem sorteio. Usa só o que o estudante cadastrou.
//
// Regras:
//  1. No máximo 80% do tempo livre de cada dia e nunca acima do limite diário.
//  2. Prioridade: prova/trabalho em até 7 dias, depois em até 14, depois matéria difícil.
//  3. Matéria difícil recebe o dobro de sessões de uma matéria comum.
//  4. No máximo 2 sessões da mesma matéria por dia, nunca seguidas.
//  5. Cada prova ganha uma revisão na véspera (ou no dia livre mais próximo antes).
//  6. Sessões concluídas, fixadas e manuais nunca são alteradas ao gerar de novo.

import '../models/models.dart';

String hmFromMinutes(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day, 12);
DateTime addDaysTo(DateTime d, int n) => DateTime(d.year, d.month, d.day + n, 12);

class PlanLeftover {
  final String subjectId;
  final int wanted;
  final int placed;
  final bool beforeExam; // o mínimo era antes de uma prova
  const PlanLeftover({required this.subjectId, required this.wanted, required this.placed, this.beforeExam = false});
}

class PlanResult {
  /// Sessões novas, geradas agora.
  final List<PlanSession> sessions;

  /// Sessões que já existiam no período e foram preservadas.
  final List<PlanSession> kept;

  /// O que não coube (vazio quando deu para encaixar o mínimo de tudo).
  final List<PlanLeftover> leftovers;

  /// Horários livres encontrados no período.
  final int slots;

  const PlanResult({required this.sessions, required this.kept, required this.leftovers, required this.slots});
}

bool dayAvailable(PlanSettings s, DateTime day) {
  final a = s.days[day.weekday - 1];
  return a.on && a.minutes > 0 && !s.blocked.contains(dayKey(day));
}

/// Minutos de estudo que cabem no dia: 80% da faixa livre, limitado ao máximo diário.
int dayCapacity(PlanSettings s, DateTime day) {
  if (!dayAvailable(s, day)) return 0;
  final cap = (s.days[day.weekday - 1].minutes * 0.8).floor();
  return cap < s.dailyMaxMin ? cap : s.dailyMaxMin;
}

bool _overlaps(int aStart, int aEnd, int bStart, int bEnd) => aStart < bEnd && bStart < aEnd;

/// Horários de início livres em um dia para sessões de [minutes], em sequência,
/// respeitando as sessões já existentes ([busy]), o intervalo e a capacidade do dia.
List<int> freeStarts(PlanSettings s, DateTime day, int minutes, List<PlanSession> busy, {int? notBefore}) {
  if (!dayAvailable(s, day)) return const [];
  final a = s.days[day.weekday - 1];
  final from = hmToMinutes(a.from), to = hmToMinutes(a.to);
  final cap = dayCapacity(s, day);
  var used = 0;
  for (final b in busy) {
    if (b.occupies) used += b.minutes;
  }
  final out = <int>[];
  var t = from;
  if (notBefore != null && t < notBefore) t = ((notBefore + 4) ~/ 5) * 5;
  var guard = 0;
  while (t + minutes <= to && guard < 500) {
    guard++;
    PlanSession? hit;
    for (final b in busy) {
      if (b.occupies && _overlaps(t, t + minutes, b.startMin - s.gapMin, b.endMin + s.gapMin)) {
        hit = b;
        break;
      }
    }
    if (hit != null) {
      final next = hit.endMin + s.gapMin;
      t = next > t ? next : t + 5;
      continue;
    }
    if (used + minutes > cap) break;
    out.add(t);
    used += minutes;
    t += minutes + s.gapMin;
  }
  return out;
}

/// Próxima prova/trabalho da matéria com data depois de [day] (estritamente).
Exam? nextExamAfter(AppData d, String subjectId, DateTime day) {
  final k = dayKey(day);
  Exam? best;
  for (final e in d.exams) {
    if (e.subjectId != subjectId || e.date == null) continue;
    if (e.date!.compareTo(k) <= 0) continue;
    if (best == null || e.date!.compareTo(best.date!) < 0) best = e;
  }
  return best;
}

/// Texto que muda quando as provas mudam (para avisar que o plano pode estar desatualizado).
String examSignature(AppData d) {
  final list = d.exams.map((e) => '${e.id}|${e.date ?? ''}|${e.title}').toList()..sort();
  return list.join(';');
}

PlanResult generatePlan(AppData d, DateTime from, DateTime to, DateTime now, {Set<String> prioritize = const {}}) {
  final s = d.plan;
  final fromD = dayOnly(from), toD = dayOnly(to), today = dayOnly(now);
  final fromK = dayKey(fromD), toK = dayKey(toD), todayK = dayKey(today);

  bool inRange(PlanSession p) => p.day.compareTo(fromK) >= 0 && p.day.compareTo(toK) <= 0;
  // Preserva: fixadas, manuais, as que já têm resultado e as de dias que já passaram.
  bool keep(PlanSession p) => p.pinned || p.manual || p.state != PlanState.planejada || p.day.compareTo(todayK) < 0;

  final kept = d.planSessions.where((p) => inRange(p) && keep(p)).toList();
  final subjects = d.subjects;
  if (subjects.isEmpty || !s.configured) {
    return PlanResult(sessions: const [], kept: kept, leftovers: const [], slots: 0);
  }

  final base = fromD.isBefore(today) ? today : fromD;

  // 1. Horários livres do período.
  final slotDay = <DateTime>[];
  final slotStart = <int>[];
  for (var day = base; !day.isAfter(toD); day = addDaysTo(day, 1)) {
    final k = dayKey(day);
    final busy = kept.where((p) => p.day == k).toList();
    final nb = k == todayK ? now.hour * 60 + now.minute + 5 : null;
    for (final st in freeStarts(s, day, s.sessionMin, busy, notBefore: nb)) {
      slotDay.add(day);
      slotStart.add(st);
    }
  }
  final total = slotDay.length;
  final n = subjects.length;

  // 2. Peso de cada matéria.
  final weight = List<double>.filled(n, 1);
  final examInRange = List<Exam?>.filled(n, null);
  for (var i = 0; i < n; i++) {
    final sub = subjects[i];
    var w = sub.hard ? 2.0 : 1.0;
    final ex = nextExamAfter(d, sub.id, addDaysTo(base, -1));
    if (ex != null) {
      final days = parseDayKey(ex.date)!.difference(base).inDays;
      if (days <= 7) {
        w += 2;
      } else if (days <= 14) {
        w += 1;
      }
      if (ex.date!.compareTo(dayKey(addDaysTo(toD, 1))) <= 0 && ex.date!.compareTo(dayKey(base)) > 0) examInRange[i] = ex;
    }
    if (prioritize.contains(sub.id)) w *= 3;
    weight[i] = w;
  }
  final wSum = weight.fold<double>(0, (a, b) => a + b);

  // 3. Quantas sessões cada matéria deve receber.
  final distinctDays = slotDay.map(dayKey).toSet().length;
  final maxPer = 2 * distinctDays;
  final desired = List<int>.filled(n, 0);
  if (total > 0) {
    final frac = List<double>.filled(n, 0);
    var given = 0;
    for (var i = 0; i < n; i++) {
      final raw = total * weight[i] / wSum;
      desired[i] = raw.floor();
      frac[i] = raw - desired[i];
      given += desired[i];
    }
    while (given < total) {
      var bi = 0;
      for (var i = 1; i < n; i++) {
        if (frac[i] > frac[bi]) bi = i;
      }
      desired[bi]++;
      frac[bi] = -1;
      given++;
    }
    // Toda matéria ganha pelo menos uma sessão, se houver horários para isso.
    if (total >= n) {
      for (var i = 0; i < n; i++) {
        if (desired[i] > 0) continue;
        var donor = -1;
        for (var j = 0; j < n; j++) {
          if (desired[j] > 1 && (donor < 0 || desired[j] > desired[donor])) donor = j;
        }
        if (donor < 0) break;
        desired[donor]--;
        desired[i] = 1;
      }
    }
    for (var i = 0; i < n; i++) {
      if (desired[i] > maxPer) desired[i] = maxPer;
    }
  }

  // 4. Encaixe.
  final assigned = List<int>.filled(total, -1); // índice da matéria em cada horário
  final forcedTopic = List<String?>.filled(total, null);
  final remaining = List<int>.of(desired);
  final placed = List<int>.filled(n, 0);
  final perDay = <String, List<int>>{};
  List<int> dayCount(DateTime day) => perDay.putIfAbsent(dayKey(day), () => List<int>.filled(n, 0));

  bool neighborSame(int slot, int subj) {
    if (slot > 0 && dayKey(slotDay[slot - 1]) == dayKey(slotDay[slot]) && assigned[slot - 1] == subj) return true;
    if (slot < total - 1 && dayKey(slotDay[slot + 1]) == dayKey(slotDay[slot]) && assigned[slot + 1] == subj) return true;
    return false;
  }

  void put(int slot, int subj) {
    assigned[slot] = subj;
    placed[subj]++;
    if (remaining[subj] > 0) remaining[subj]--;
    dayCount(slotDay[slot])[subj]++;
  }

  // 4a. Revisão na véspera de cada prova (ou no dia livre mais próximo antes dela).
  final exams = <int>[for (var i = 0; i < n; i++) if (examInRange[i] != null) i]
    ..sort((a, b) => examInRange[a]!.date!.compareTo(examInRange[b]!.date!));
  for (final i in exams) {
    final ex = examInRange[i]!;
    final exK = ex.date!;
    var chosen = -1;
    for (var sl = total - 1; sl >= 0; sl--) {
      if (dayKey(slotDay[sl]).compareTo(exK) >= 0) continue;
      if (assigned[sl] >= 0) continue;
      if (dayCount(slotDay[sl])[i] >= 2 || neighborSame(sl, i)) continue;
      chosen = sl;
      break;
    }
    if (chosen >= 0) {
      put(chosen, i);
      if (ex.title.isNotEmpty) forcedTopic[chosen] = ex.title;
    }
  }

  // 4b. Demais horários, em ordem de data.
  for (var sl = 0; sl < total; sl++) {
    if (assigned[sl] >= 0) continue;
    final day = slotDay[sl];
    var best = -1;
    var bestScore = -1.0;
    for (var i = 0; i < n; i++) {
      if (remaining[i] <= 0) continue;
      if (dayCount(day)[i] >= 2 || neighborSame(sl, i)) continue;
      var score = desired[i] == 0 ? 0.0 : remaining[i] / desired[i] * 10;
      final ex = nextExamAfter(d, subjects[i].id, day);
      if (ex != null) {
        final until = parseDayKey(ex.date)!.difference(day).inDays;
        score += 100 / (until + 1);
      }
      if (subjects[i].hard) score += 3;
      if (prioritize.contains(subjects[i].id)) score += 50;
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    if (best >= 0) put(sl, best);
  }

  // 5. Monta as sessões, escolhendo o assunto entre os cadastrados.
  final topicTurn = List<int>.filled(n, 0);
  final out = <PlanSession>[];
  var seq = 0;
  final stamp = now.millisecondsSinceEpoch.toRadixString(36);
  final usedIds = d.planSessions.map((p) => p.id).toSet();
  String nextId() {
    String id;
    do {
      id = 'p$stamp${(seq++).toRadixString(36)}';
    } while (usedIds.contains(id));
    return id;
  }

  for (var sl = 0; sl < total; sl++) {
    final i = assigned[sl];
    if (i < 0) continue;
    final sub = subjects[i];
    String? topic = forcedTopic[sl];
    if (topic == null) {
      final ex = nextExamAfter(d, sub.id, slotDay[sl]);
      if (ex != null && ex.title.isNotEmpty) {
        topic = ex.title;
      } else if (sub.topics.isNotEmpty) {
        topic = sub.topics[topicTurn[i] % sub.topics.length];
        topicTurn[i]++;
      }
    }
    out.add(PlanSession(
      id: nextId(),
      subjectId: sub.id,
      topic: topic,
      day: dayKey(slotDay[sl]),
      start: hmFromMinutes(slotStart[sl]),
      minutes: s.sessionMin,
    ));
  }

  // 6. O que não coube: cada matéria precisa de 1 sessão; com prova no período, 2 antes dela.
  final left = <PlanLeftover>[];
  for (var i = 0; i < n; i++) {
    final ex = examInRange[i];
    if (ex != null) {
      var before = 0;
      for (final p in out) {
        if (p.subjectId == subjects[i].id && p.day.compareTo(ex.date!) < 0) before++;
      }
      for (final p in kept) {
        if (p.subjectId == subjects[i].id && p.occupies && p.day.compareTo(ex.date!) < 0 && p.day.compareTo(dayKey(base)) >= 0) before++;
      }
      if (before < 2) left.add(PlanLeftover(subjectId: subjects[i].id, wanted: 2, placed: before, beforeExam: true));
    } else {
      final keptN = kept.where((p) => p.subjectId == subjects[i].id && p.occupies).length;
      if (placed[i] + keptN < 1) left.add(PlanLeftover(subjectId: subjects[i].id, wanted: 1, placed: 0));
    }
  }

  return PlanResult(sessions: out, kept: kept, leftovers: left, slots: total);
}

// ---------- conferência de horário para sessões manuais e reagendadas ----------

class SlotCheck {
  final bool overlap; // bate com outra sessão
  final bool overLimit; // passa do limite diário
  final bool unavailable; // dia ou horário fora da disponibilidade
  const SlotCheck({required this.overlap, required this.overLimit, required this.unavailable});
  bool get ok => !overlap && !overLimit && !unavailable;
}

SlotCheck checkSlot(AppData d, {required String day, required int startMin, required int minutes, String? ignoreId}) {
  final s = d.plan;
  final dt = parseDayKey(day);
  var overlap = false;
  var used = 0;
  for (final p in d.planSessions) {
    if (p.day != day || p.id == ignoreId || !p.occupies) continue;
    used += p.minutes;
    if (_overlaps(startMin, startMin + minutes, p.startMin, p.endMin)) overlap = true;
  }
  var unavailable = true;
  if (dt != null && dayAvailable(s, dt)) {
    final a = s.days[dt.weekday - 1];
    unavailable = startMin < hmToMinutes(a.from) || startMin + minutes > hmToMinutes(a.to);
  }
  return SlotCheck(overlap: overlap, overLimit: used + minutes > s.dailyMaxMin, unavailable: unavailable);
}

class SlotOption {
  final String day;
  final int startMin;
  const SlotOption(this.day, this.startMin);
}

/// Até [count] horários livres a partir de [fromDay], um por dia, para oferecer como alternativa.
List<SlotOption> suggestSlots(AppData d, DateTime fromDay, int minutes, DateTime now, {String? ignoreId, int count = 3}) {
  final s = d.plan;
  final out = <SlotOption>[];
  final today = dayOnly(now);
  var day = dayOnly(fromDay);
  if (day.isBefore(today)) day = today;
  for (var i = 0; i < 28 && out.length < count; i++) {
    final k = dayKey(day);
    final busy = d.planSessions.where((p) => p.day == k && p.id != ignoreId).toList();
    final nb = k == dayKey(today) ? now.hour * 60 + now.minute + 5 : null;
    final starts = freeStarts(s, day, minutes, busy, notBefore: nb);
    if (starts.isNotEmpty) out.add(SlotOption(k, starts.first));
    day = addDaysTo(day, 1);
  }
  return out;
}

// ---------- resumo ----------

class PlanProgress {
  final int total;
  final int done;
  final int plannedMin;
  final int doneMin;
  const PlanProgress({required this.total, required this.done, required this.plannedMin, required this.doneMin});
}

PlanProgress planProgress(Iterable<PlanSession> list) {
  var total = 0, done = 0, pm = 0, dm = 0;
  for (final p in list) {
    total++;
    pm += p.minutes;
    if (p.state == PlanState.concluida) {
      done++;
      dm += p.minutes;
    }
  }
  return PlanProgress(total: total, done: done, plannedMin: pm, doneMin: dm);
}

/// Sessões de um intervalo de dias, em ordem de data e hora.
List<PlanSession> sessionsBetween(AppData d, String fromKey, String toKey) {
  final list = d.planSessions.where((p) => p.day.compareTo(fromKey) >= 0 && p.day.compareTo(toKey) <= 0).toList();
  list.sort((a, b) {
    final c = a.day.compareTo(b.day);
    return c != 0 ? c : a.startMin.compareTo(b.startMin);
  });
  return list;
}

/// Próxima sessão planejada a partir de agora.
PlanSession? nextPlanned(AppData d, DateTime now) {
  PlanSession? best;
  for (final p in d.planSessions) {
    if (p.state != PlanState.planejada) continue;
    final end = p.dateTime.add(Duration(minutes: p.minutes));
    if (end.isBefore(now)) continue;
    if (best == null || p.dateTime.isBefore(best.dateTime)) best = p;
  }
  return best;
}

/// Sessões planejadas cujo dia já passou e que ficaram sem resultado.
List<PlanSession> missedSessions(AppData d, DateTime now) {
  final todayK = dayKey(now);
  return d.planSessions.where((p) => p.state == PlanState.planejada && p.day.compareTo(todayK) < 0).toList();
}
