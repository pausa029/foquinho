/* ---------- planejamento de estudos (mesmas regras do app Android) ----------
   Determinístico, sem sorteio. Usa só matérias, dificuldades e provas cadastradas.
   1. No máximo 80% do tempo livre de cada dia e nunca acima do limite diário.
   2. Prioridade: prova em até 7 dias, depois em até 14, depois matéria difícil.
   3. Matéria difícil recebe o dobro de sessões de uma matéria comum.
   4. No máximo 2 sessões da mesma matéria por dia, sem repetir em sequência.
   5. Cada prova ganha uma revisão na véspera (ou no dia livre mais próximo antes).
   6. Sessões concluídas, fixadas e manuais nunca mudam ao gerar de novo. */
function planDefaults() {
  var days = [];
  for (var i = 0; i < 7; i++) days.push({ on: false, from: '18:00', to: '20:00' });
  return { days: days, dailyMaxMin: 90, sessionMin: 25, gapMin: 10, blocked: [], configured: false, paused: false, examSig: null };
}
var PLAN_STATES = ['planejada', 'concluida', 'incompleta', 'naoRealizada'];
var PLAN_STATE_LABEL = { planejada: 'Planejada', concluida: 'Concluída', incompleta: 'Incompleta', naoRealizada: 'Não realizada' };

function normPlan(x) {
  var p = planDefaults();
  if (!x || typeof x !== 'object') return p;
  var raw = arr(x.days, 7);
  for (var i = 0; i < 7; i++) {
    var r = raw[i];
    if (r && typeof r === 'object') p.days[i] = { on: !!r.on, from: hm(r.from, '18:00'), to: hm(r.to, '20:00') };
  }
  p.dailyMaxMin = num(x.dailyMaxMin, 15, 600, 90);
  p.sessionMin = num(x.sessionMin, 10, 120, 25);
  p.gapMin = num(x.gapMin, 0, 60, 10);
  p.blocked = uniq(arr(x.blocked, 200).filter(isDayKey));
  p.configured = !!x.configured;
  p.paused = !!x.paused;
  p.examSig = typeof x.examSig === 'string' && x.examSig ? x.examSig.slice(0, 4000) : null;
  return p;
}
function normPlanSessions(list, subjects) {
  return arr(list, 3000).map(function (s) {
    if (!s || typeof s !== 'object') return null;
    var o = {
      id: str(s.id, 40), subject: str(s.subject, 40), topic: str(s.topic, 80) || null, day: isDayKey(s.day) ? s.day : null, start: hm(s.start, null),
      minutes: num(s.minutes, 5, 240, 25), state: oneOf(s.state, PLAN_STATES, 'planejada'), pinned: !!s.pinned, manual: !!s.manual, moved: !!s.moved
    };
    return (o.id && o.subject && o.day && o.start && subjects.indexOf(o.subject) >= 0) ? o : null;
  }).filter(Boolean);
}

function psStart(p) { return hmToMin(p.start); }
function psEnd(p) { return hmToMin(p.start) + p.minutes; }
function psOccupies(p) { return p.state !== 'naoRealizada'; }
function psTime(p) { var m = psStart(p), d = keyToDate(p.day); return new Date(d.getFullYear(), d.getMonth(), d.getDate(), Math.floor(m / 60), m % 60).getTime(); }
function hmFromMin(m) { return pad2(Math.floor(m / 60)) + ':' + pad2(m % 60); }
function availMinutes(a) { var m = hmToMin(a.to) - hmToMin(a.from); return m < 0 ? 0 : m; }

function planDayAvailable(s, key) {
  var a = s.days[wdIndex(key)];
  return a.on && availMinutes(a) > 0 && s.blocked.indexOf(key) < 0;
}
function planDayCapacity(s, key) {
  if (!planDayAvailable(s, key)) return 0;
  return Math.min(Math.floor(availMinutes(s.days[wdIndex(key)]) * 0.8), s.dailyMaxMin);
}
function overlaps(a0, a1, b0, b1) { return a0 < b1 && b0 < a1; }

/* horários de início livres em um dia, em sequência, respeitando o que já existe (busy) */
function planFreeStarts(s, key, minutes, busy, notBefore) {
  if (!planDayAvailable(s, key)) return [];
  var a = s.days[wdIndex(key)], from = hmToMin(a.from), to = hmToMin(a.to), cap = planDayCapacity(s, key), used = 0, out = [], t = from, guard = 0;
  busy.forEach(function (b) { if (psOccupies(b)) used += b.minutes; });
  if (notBefore != null && t < notBefore) t = Math.floor((notBefore + 4) / 5) * 5;
  while (t + minutes <= to && guard++ < 500) {
    var hit = null;
    for (var i = 0; i < busy.length; i++) {
      var b = busy[i];
      if (psOccupies(b) && overlaps(t, t + minutes, psStart(b) - s.gapMin, psEnd(b) + s.gapMin)) { hit = b; break; }
    }
    if (hit) { var next = psEnd(hit) + s.gapMin; t = next > t ? next : t + 5; continue; }
    if (used + minutes > cap) break;
    out.push(t);
    used += minutes;
    t += minutes + s.gapMin;
  }
  return out;
}
/* próxima prova da matéria com data depois de key */
function planNextExam(d, subject, key) {
  var best = null;
  d.prefs.exams.forEach(function (e) {
    if (e.subject !== subject || !e.date || e.date <= key) return;
    if (!best || e.date < best.date) best = e;
  });
  return best;
}
function planExamSig(d) {
  return d.prefs.exams.map(function (e) { return e.id + '|' + (e.date || '') + '|' + (e.topic || ''); }).sort().join(';');
}

function generatePlan(d, fromKey, toKey, nowDate, prioritize) {
  var s = d.splan, todayK = dayKey(nowDate), pri = prioritize || [];
  function keep(p) { return p.pinned || p.manual || p.state !== 'planejada' || p.day < todayK; }
  var kept = d.planSessions.filter(function (p) { return p.day >= fromKey && p.day <= toKey && keep(p); });
  var subjects = d.prefs.subjects, n = subjects.length;
  if (!n || !s.configured) return { sessions: [], kept: kept, leftovers: [], slots: 0 };
  var base = fromKey < todayK ? todayK : fromKey, nowMin = nowDate.getHours() * 60 + nowDate.getMinutes();

  /* 1. horários livres */
  var slotDay = [], slotStart = [], guard = 0;
  for (var day = base; day <= toKey && guard++ < 400; day = addDays(day, 1)) {
    var busy = kept.filter(function (p) { return p.day === day; });
    planFreeStarts(s, day, s.sessionMin, busy, day === todayK ? nowMin + 5 : null).forEach(function (st) { slotDay.push(day); slotStart.push(st); });
  }
  var total = slotDay.length, i, j;

  /* 2. peso de cada matéria */
  var weight = [], examIn = [], wSum = 0, dayBefore = addDays(base, -1), afterTo = addDays(toKey, 1);
  for (i = 0; i < n; i++) {
    var w = d.prefs.hard.indexOf(subjects[i]) >= 0 ? 2 : 1, ex = planNextExam(d, subjects[i], dayBefore);
    examIn.push(null);
    if (ex) {
      var days = diffDays(ex.date, base);
      if (days <= 7) w += 2; else if (days <= 14) w += 1;
      if (ex.date <= afterTo && ex.date > base) examIn[i] = ex;
    }
    if (pri.indexOf(subjects[i]) >= 0) w *= 3;
    weight.push(w);
    wSum += w;
  }

  /* 3. quantas sessões cada matéria deve receber */
  var distinct = {}, desired = [], frac = [], given = 0;
  slotDay.forEach(function (k) { distinct[k] = 1; });
  var maxPer = 2 * Object.keys(distinct).length;
  for (i = 0; i < n; i++) { desired.push(0); frac.push(0); }
  if (total > 0) {
    for (i = 0; i < n; i++) { var raw = total * weight[i] / wSum; desired[i] = Math.floor(raw); frac[i] = raw - desired[i]; given += desired[i]; }
    while (given < total) {
      var bi = 0;
      for (i = 1; i < n; i++) if (frac[i] > frac[bi]) bi = i;
      desired[bi]++; frac[bi] = -1; given++;
    }
    if (total >= n) {
      for (i = 0; i < n; i++) {
        if (desired[i] > 0) continue;
        var donor = -1;
        for (j = 0; j < n; j++) if (desired[j] > 1 && (donor < 0 || desired[j] > desired[donor])) donor = j;
        if (donor < 0) break;
        desired[donor]--; desired[i] = 1;
      }
    }
    for (i = 0; i < n; i++) if (desired[i] > maxPer) desired[i] = maxPer;
  }

  /* 4. encaixe */
  var assigned = [], forced = [], remaining = desired.slice(), placed = [], perDay = {};
  for (i = 0; i < total; i++) { assigned.push(-1); forced.push(null); }
  for (i = 0; i < n; i++) placed.push(0);
  function dayCount(k) { if (!perDay[k]) { perDay[k] = []; for (var q = 0; q < n; q++) perDay[k].push(0); } return perDay[k]; }
  function neighborSame(sl, subj) {
    if (sl > 0 && slotDay[sl - 1] === slotDay[sl] && assigned[sl - 1] === subj) return true;
    if (sl < total - 1 && slotDay[sl + 1] === slotDay[sl] && assigned[sl + 1] === subj) return true;
    return false;
  }
  function put(sl, subj) { assigned[sl] = subj; placed[subj]++; if (remaining[subj] > 0) remaining[subj]--; dayCount(slotDay[sl])[subj]++; }

  /* 4a. revisão na véspera de cada prova */
  var examIdx = [];
  for (i = 0; i < n; i++) if (examIn[i]) examIdx.push(i);
  examIdx.sort(function (a, b) { return examIn[a].date < examIn[b].date ? -1 : (examIn[a].date > examIn[b].date ? 1 : a - b); });
  examIdx.forEach(function (si) {
    var e = examIn[si], chosen = -1;
    for (var sl = total - 1; sl >= 0; sl--) {
      if (slotDay[sl] >= e.date || assigned[sl] >= 0) continue;
      if (dayCount(slotDay[sl])[si] >= 2 || neighborSame(sl, si)) continue;
      chosen = sl;
      break;
    }
    if (chosen >= 0) { put(chosen, si); if (e.topic) forced[chosen] = e.topic; }
  });

  /* 4b. demais horários, em ordem de data */
  for (var sl = 0; sl < total; sl++) {
    if (assigned[sl] >= 0) continue;
    var best = -1, bestScore = -1;
    for (i = 0; i < n; i++) {
      if (remaining[i] <= 0) continue;
      if (dayCount(slotDay[sl])[i] >= 2 || neighborSame(sl, i)) continue;
      var score = desired[i] === 0 ? 0 : remaining[i] / desired[i] * 10, ex2 = planNextExam(d, subjects[i], slotDay[sl]);
      if (ex2) score += 100 / (diffDays(ex2.date, slotDay[sl]) + 1);
      if (d.prefs.hard.indexOf(subjects[i]) >= 0) score += 3;
      if (pri.indexOf(subjects[i]) >= 0) score += 50;
      if (score > bestScore) { bestScore = score; best = i; }
    }
    if (best >= 0) put(sl, best);
  }

  /* 5. monta as sessões */
  var out = [], used = {}, seq = 0, stamp = nowDate.getTime().toString(36);
  d.planSessions.forEach(function (p) { used[p.id] = 1; });
  function nextId() { var id; do { id = 'p' + stamp + (seq++).toString(36); } while (used[id]); return id; }
  for (sl = 0; sl < total; sl++) {
    var si = assigned[sl];
    if (si < 0) continue;
    var topic = forced[sl];
    if (!topic) { var e3 = planNextExam(d, subjects[si], slotDay[sl]); if (e3 && e3.topic) topic = e3.topic; }
    out.push({ id: nextId(), subject: subjects[si], topic: topic || null, day: slotDay[sl], start: hmFromMin(slotStart[sl]), minutes: s.sessionMin, state: 'planejada', pinned: false, manual: false, moved: false });
  }

  /* 6. o que não coube: 1 sessão por matéria; com prova no período, 2 antes dela */
  var left = [];
  for (i = 0; i < n; i++) {
    var e4 = examIn[i], subj = subjects[i];
    if (e4) {
      var before = out.filter(function (p) { return p.subject === subj && p.day < e4.date; }).length +
        kept.filter(function (p) { return p.subject === subj && psOccupies(p) && p.day < e4.date && p.day >= base; }).length;
      if (before < 2) left.push({ subject: subj, wanted: 2, placed: before, beforeExam: true });
    } else if (placed[i] + kept.filter(function (p) { return p.subject === subj && psOccupies(p); }).length < 1) {
      left.push({ subject: subj, wanted: 1, placed: 0, beforeExam: false });
    }
  }
  return { sessions: out, kept: kept, leftovers: left, slots: total };
}

/* troca só as sessões geradas e intocadas do período; o resto fica como está */
function applyPlan(d, fromKey, toKey, result) {
  var keepIds = {};
  result.kept.forEach(function (p) { keepIds[p.id] = 1; });
  d.planSessions = d.planSessions.filter(function (p) { return p.day < fromKey || p.day > toKey || keepIds[p.id]; }).concat(result.sessions);
  d.splan.examSig = planExamSig(d);
}

/* conferência de horário para sessões manuais e reagendadas */
function planCheckSlot(d, day, startMin, minutes, ignoreId) {
  var s = d.splan, overlap = false, used = 0, unavailable = true;
  d.planSessions.forEach(function (p) {
    if (p.day !== day || p.id === ignoreId || !psOccupies(p)) return;
    used += p.minutes;
    if (overlaps(startMin, startMin + minutes, psStart(p), psEnd(p))) overlap = true;
  });
  if (isDayKey(day) && planDayAvailable(s, day)) {
    var a = s.days[wdIndex(day)];
    unavailable = startMin < hmToMin(a.from) || startMin + minutes > hmToMin(a.to);
  }
  var overLimit = used + minutes > s.dailyMaxMin;
  return { overlap: overlap, overLimit: overLimit, unavailable: unavailable, ok: !overlap && !overLimit && !unavailable };
}
function planSuggestSlots(d, fromDay, minutes, nowDate, ignoreId, count) {
  var out = [], todayK = dayKey(nowDate), day = fromDay < todayK ? todayK : fromDay, nowMin = nowDate.getHours() * 60 + nowDate.getMinutes();
  for (var i = 0; i < 28 && out.length < (count || 3); i++) {
    var busy = d.planSessions.filter(function (p) { return p.day === day && p.id !== ignoreId; });
    var starts = planFreeStarts(d.splan, day, minutes, busy, day === todayK ? nowMin + 5 : null);
    if (starts.length) out.push({ day: day, startMin: starts[0] });
    day = addDays(day, 1);
  }
  return out;
}
function planSessionsBetween(d, fromKey, toKey) {
  return d.planSessions.filter(function (p) { return p.day >= fromKey && p.day <= toKey; }).sort(function (a, b) {
    return a.day < b.day ? -1 : (a.day > b.day ? 1 : psStart(a) - psStart(b));
  });
}
function planProgress(list) {
  var o = { total: 0, done: 0, plannedMin: 0, doneMin: 0 };
  list.forEach(function (p) { o.total++; o.plannedMin += p.minutes; if (p.state === 'concluida') { o.done++; o.doneMin += p.minutes; } });
  return o;
}
function planNext(d, t) {
  var best = null;
  d.planSessions.forEach(function (p) {
    if (p.state !== 'planejada' || psTime(p) + p.minutes * 60000 < t) return;
    if (!best || psTime(p) < psTime(best)) best = p;
  });
  return best;
}
function planMissed(d) {
  var todayK = dayKey();
  return d.planSessions.filter(function (p) { return p.state === 'planejada' && p.day < todayK; });
}
function planById(d, id) {
  for (var i = 0; i < d.planSessions.length; i++) if (d.planSessions[i].id === id) return d.planSessions[i];
  return null;
}
function psLabel(p) { return p.subject + (p.topic ? ': ' + p.topic : ''); }
