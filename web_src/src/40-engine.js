/* ---------- recursos do aparelho: som, vibração, tela ligada, notificações ---------- */
var DEV = { ac: null, wake: null };

function primeAudio() {
  try {
    var AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    if (!DEV.ac) DEV.ac = new AC();
    if (DEV.ac.state === 'suspended' && DEV.ac.resume) DEV.ac.resume();
  } catch (e) { /* sem som neste navegador */ }
}
function soundSupported() { return !!(window.AudioContext || window.webkitAudioContext); }
function chime() {
  if (!S.data || !S.data.ui.sound || !DEV.ac) return false;
  try {
    var ac = DEV.ac, t0 = ac.currentTime + 0.02;
    [660, 880, 1100].forEach(function (f, i) {
      var o = ac.createOscillator(), g = ac.createGain(), at = t0 + i * 0.22;
      o.type = 'sine';
      o.frequency.value = f;
      g.gain.setValueAtTime(0.0001, at);
      g.gain.exponentialRampToValueAtTime(0.22, at + 0.03);
      g.gain.exponentialRampToValueAtTime(0.0001, at + 0.5);
      o.connect(g); g.connect(ac.destination);
      o.start(at); o.stop(at + 0.55);
    });
    return true;
  } catch (e) { return false; }
}
function vibrateSupported() { return typeof navigator.vibrate === 'function'; }
function buzz() {
  if (!S.data || !S.data.ui.vibrate || !vibrateSupported()) return;
  try { navigator.vibrate([180, 90, 180]); } catch (e) { /* ignorado */ }
}
function wakeSupported() { return !!(navigator.wakeLock && navigator.wakeLock.request); }
function wakeOn() {
  if (!S.data || !S.data.ui.awake || !wakeSupported() || DEV.wake) return;
  try {
    navigator.wakeLock.request('screen').then(function (w) {
      DEV.wake = w;
      S.wakeActive = true;
      w.addEventListener('release', function () { if (DEV.wake === w) DEV.wake = null; S.wakeActive = false; paintWake(); });
      paintWake();
    }, function () { S.wakeActive = false; paintWake(); });
  } catch (e) { S.wakeActive = false; }
}
function wakeOff() {
  try { if (DEV.wake) DEV.wake.release(); } catch (e) { /* ignorado */ }
  DEV.wake = null;
  S.wakeActive = false;
}
function notifState() {
  if (!('Notification' in window)) return 'unsupported';
  try { return Notification.permission; } catch (e) { return 'unsupported'; }
}
function notifAsk(done) {
  var finished = false;
  function end() { if (!finished) { finished = true; done(notifState()); } }
  try {
    var p = Notification.requestPermission(function () { end(); });
    if (p && p.then) p.then(end, end);
  } catch (e) { end(); }
}
/* só considera a notificação utilizável depois de conseguir criar uma de verdade */
function sysNotify(title, body) {
  if (notifState() !== 'granted' || S.notifBroken) return false;
  try { var n = new Notification(title, { body: body, tag: 'pausa-mais' }); return !!n; }
  catch (e) { S.notifBroken = true; return false; }
}

/* ---------- temporizador (contagem pelo relógio, não por ticks: continua certa se a tela apagar) ---------- */
function timerStart(cfg) {
  var t = {
    kind: cfg.kind, title: cfg.title || '', subject: cfg.subject || null, sport: cfg.sport || null, actId: cfg.actId || null, planId: cfg.planId || null,
    startedAt: now(), paused: false, remainMs: 0, doneFocusMs: 0, mood0: cfg.mood0 || null, cyc: null, finished: null
  };
  if (cfg.cycles) {
    t.cyc = { focus: cfg.cycles.focus, rest: cfg.cycles.rest, total: cfg.cycles.total, n: 1, phase: 'foco' };
    t.phaseMs = cfg.cycles.focus * 60000;
    t.planMin = cfg.cycles.focus * cfg.cycles.total;
  } else {
    t.phaseMs = cfg.min * 60000;
    t.planMin = cfg.min;
  }
  t.endsAt = now() + t.phaseMs;
  S.data.timer = t;
  S.data.useSession = null;
  save();
  primeAudio();
  wakeOn();
  announce(KIND_LABEL[t.kind] + ' iniciado: ' + spokenMin(t.phaseMs / 60000) + '.');
}
function timerRemain(t) { return t.paused ? t.remainMs : Math.max(0, t.endsAt - now()); }
function timerFinish(t, early) {
  var ms = t.doneFocusMs;
  if (early && (!t.cyc || t.cyc.phase === 'foco')) ms += Math.max(0, t.phaseMs - timerRemain(t));
  t.finished = { doneMin: Math.round(ms / 60000), early: !!early, at: early ? now() : t.endsAt };
  t.paused = false;
  wakeOff();
}
/* avança as fases que já venceram; devolve o último evento para avisar uma vez só */
function timerSync() {
  var t = S.data && S.data.timer;
  if (!t || t.paused || t.finished) return null;
  var n = now(), ev = null, guard = 0;
  while (n >= t.endsAt && guard++ < 60) {
    if (!t.cyc) { t.doneFocusMs += t.phaseMs; timerFinish(t, false); ev = 'fim'; break; }
    if (t.cyc.phase === 'foco') {
      t.doneFocusMs += t.phaseMs;
      if (t.cyc.n >= t.cyc.total) { timerFinish(t, false); ev = 'fim'; break; }
      t.cyc.phase = 'intervalo';
      t.phaseMs = t.cyc.rest * 60000;
      t.endsAt += t.phaseMs;
      ev = 'intervalo';
    } else {
      t.cyc.n++;
      t.cyc.phase = 'foco';
      t.phaseMs = t.cyc.focus * 60000;
      t.endsAt += t.phaseMs;
      ev = 'foco';
    }
  }
  if (ev) save();
  return ev;
}
function timerPause() {
  var t = S.data.timer;
  if (!t || t.finished || t.paused) return;
  t.remainMs = timerRemain(t);
  t.paused = true;
  wakeOff();
  save();
}
function timerResume() {
  var t = S.data.timer;
  if (!t || t.finished || !t.paused) return;
  t.endsAt = now() + t.remainMs;
  t.paused = false;
  save();
  primeAudio();
  wakeOn();
}
function timerStopEarly() {
  var t = S.data.timer;
  if (!t || t.finished) return;
  timerFinish(t, true);
  save();
}
function timerDiscard() { S.data.timer = null; wakeOff(); save(); }
function timerSave(doneMin, mood1) {
  var t = S.data.timer;
  if (!t) return null;
  var m = clamp(Math.round(doneMin), 0, 1000), rec = null;
  if (m >= 1) {
    rec = {
      id: uid(), kind: t.kind, title: t.title, subject: t.subject, sport: t.sport, actId: t.actId, plan: t.planMin, min: m,
      start: t.startedAt, end: t.finished ? t.finished.at : now(), day: dayKey(new Date(t.startedAt)), m0: t.mood0 || null, m1: mood1 || null
    };
    S.data.sessions.push(rec);
    var pp = t.planId ? planById(S.data, t.planId) : null;
    if (pp && pp.state !== 'concluida') pp.state = m >= Math.round(pp.minutes * 0.8) ? 'concluida' : 'incompleta';
  }
  S.data.timer = null;
  wakeOff();
  save();
  return rec;
}

/* ---------- lembretes: funcionam enquanto o Foquinho está aberto ---------- */
function inQuiet(d) {
  var q = d.rem.quiet;
  if (!q.on) return false;
  var a = hmToMin(q.from), b = hmToMin(q.to), n = nowHM();
  if (a == null || b == null || a === b) return false;
  return a < b ? (n >= a && n < b) : (n >= a || n < b);
}
function remMuted(d) { return !d.rem.on || now() < d.rem.pausedUntil || inQuiet(d); }
function remStatusToday(d, r) {
  /* texto de estado de cada lembrete no dia de hoje */
  var wd = wdIndex(dayKey());
  if (!r.on) return 'desligado';
  if (r.days.indexOf(wd) < 0) return 'não toca hoje';
  var f = d.rem.firedDay === dayKey() ? d.rem.fired[r.id] : null;
  if (f === 'ok') return 'avisado às ' + r.time;
  if (f === 'mudo') return 'silenciado às ' + r.time;
  if (f === 'perdido') return 'passou com o app fechado';
  if (f === 'novo') return 'vale a partir de amanhã';
  return 'hoje às ' + r.time;
}
function markTodayIfPast(d, r) {
  /* lembrete criado ou alterado depois do horário: não conta como perdido hoje */
  var t = hmToMin(r.time);
  if (d.rem.firedDay !== dayKey()) { d.rem.firedDay = dayKey(); d.rem.fired = {}; }
  if (t != null && nowHM() > t) d.rem.fired[r.id] = 'novo'; else delete d.rem.fired[r.id];
}
var lastRemTick = 0;
function remTick(force) {
  var d = S.data;
  if (!d) return false;
  var n = now();
  if (!force && n - lastRemTick < 5000) return false;
  lastRemTick = n;
  var today = dayKey(), wd = wdIndex(today), nowMin = nowHM(), changed = false, muted = remMuted(d);
  if (d.rem.firedDay !== today) { d.rem.firedDay = today; d.rem.fired = {}; changed = true; }
  d.rem.list.forEach(function (r) {
    if (!r.on || r.days.indexOf(wd) < 0 || d.rem.fired[r.id]) return;
    var t = hmToMin(r.time);
    if (t == null || nowMin < t) return;
    var late = nowMin - t;
    if (muted) d.rem.fired[r.id] = 'mudo';
    else if (late <= 20) { d.rem.fired[r.id] = 'ok'; pushAlert(remAlert(r)); }
    else d.rem.fired[r.id] = 'perdido';
    changed = true;
  });
  Object.keys(d.rem.snooze).forEach(function (k) {
    if (n < d.rem.snooze[k]) return;
    delete d.rem.snooze[k];
    changed = true;
    if (muted) return;
    for (var i = 0; i < d.rem.list.length; i++) if (d.rem.list[i].id === k && d.rem.list[i].on) pushAlert(remAlert(d.rem.list[i]));
  });
  if (!muted && !d.rem.fired.examHoje) {
    var exs = d.prefs.exams.filter(function (e) { return e.date === today; });
    if (exs.length) {
      d.rem.fired.examHoje = 'ok';
      changed = true;
      pushAlert({ key: 'examHoje', title: exs.length === 1 ? 'Compromisso de hoje: já está pronto?' : 'Compromissos de hoje: já estão prontos?', text: exs.map(function (e) { return e.subject + (e.topic ? ': ' + e.topic : ''); }).join(' · ') + '. Uma revisão rápida de 10 minutos ainda ajuda.', actions: [['Estudar agora', 'alertGoStudy'], ['Fechar', 'closeModal']] });
    }
  }
  if (!muted && d.splan.configured && !d.splan.paused) {
    d.planSessions.forEach(function (p) {
      if (p.day !== today || p.state !== 'planejada' || d.rem.fired['ps' + p.id]) return;
      var left = psStart(p) - nowMin;
      if (left > 10 || left < -15) return;
      d.rem.fired['ps' + p.id] = 'ok';
      changed = true;
      if (!d.timer) pushAlert({ key: 'ps' + p.id, title: left > 0 ? 'Sessão de estudo em ' + left + ' min' : 'Hora da sessão de estudo', text: psLabel(p) + ' às ' + p.start + ' (' + p.minutes + ' min).', planId: p.id, actions: [['Iniciar no temporizador', 'alertPsStart'], ['Ver o planejamento', 'alertGoAgenda'], ['Fechar', 'closeModal']] });
    });
  }
  var u = d.useSession;
  if (u) {
    var mins = (n - u.start) / 60000;
    if (mins >= u.limit && ((!u.alerted) || (u.snooze && n >= u.snooze))) {
      u.alerted = true;
      u.snooze = 0;
      changed = true;
      pushAlert({
        key: 'uso', title: 'Hora de uma pausa?', text: 'Você iniciou esta contagem há ' + fmtMin(mins) + '. O aviso estava marcado para ' + fmtMin(u.limit) + '.',
        actions: [['Fazer uma pausa de 5 min', 'alertPause'], ['Adiar 10 min', 'alertSnoozeUse'], ['Encerrar a contagem', 'alertEndUse']]
      });
    }
  }
  if (changed) save();
  return changed;
}
function remAlert(r) {
  var acts = [];
  if (r.kind === 'estudo') acts.push(['Estudar agora', 'alertGoStudy']);
  if (r.kind === 'exercicio') acts.push(['Me exercitar agora', 'alertGoMove']);
  acts.push(['Adiar 10 min', 'alertSnooze'], ['Silenciar por 1 hora', 'alertMute1h'], ['Fechar', 'closeModal']);
  return { key: r.id, title: r.label, text: 'Lembrete das ' + r.time + '.', actions: acts };
}
function pushAlert(a) {
  for (var i = 0; i < S.alerts.length; i++) if (S.alerts[i].key === a.key) return;
  if (S.modal && S.modal.t === 'alert' && S.modal.a.key === a.key) return;
  S.alerts.push(a);
}
function pumpAlerts() {
  if (S.modal || !S.alerts.length || !inApp()) return false;
  var a = S.alerts.shift();
  S.modal = { t: 'alert', a: a, fresh: true };
  chime();
  buzz();
  if (document.hidden) sysNotify('Foquinho · ' + a.title, a.text);
  return true;
}

/* ---------- metas, histórico e resumos ---------- */
function goalFor(d, key) {
  var g = d.goals;
  if (g.byDay.on) { var v = g.byDay.min[wdIndex(key)]; if (v != null) return v; }
  return g.dailyMin;
}
function usagePartial(u, key) {
  /* informado no próprio dia antes das 22h: o dia ainda não tinha terminado */
  var dt = new Date(u.at);
  return dayKey(dt) === key && dt.getHours() < 22;
}
function setUsage(d, key, min) {
  d.usage[key] = { min: clamp(Math.round(min), 0, 1440), at: now(), goal: goalFor(d, key) };
}
function dayStats(d, key) {
  var u = d.usage[key] || null, st = 0, mv = 0, pa = 0, cnt = 0, subjects = {};
  d.sessions.forEach(function (s) {
    if (s.day !== key) return;
    cnt++;
    if (s.kind === 'estudo') { st += s.min; if (s.subject) subjects[s.subject] = (subjects[s.subject] || 0) + s.min; }
    else if (s.kind === 'exercicio') mv += s.min;
    else pa += s.min;
  });
  var goal = u && u.goal != null ? u.goal : goalFor(d, key);
  return {
    key: key, usage: u ? u.min : null, at: u ? u.at : null, partial: u ? usagePartial(u, key) : false, goal: goal,
    within: (u && goal != null) ? u.min <= goal : null, study: st, move: mv, pause: pa, count: cnt, subjects: subjects
  };
}
function weekStats(d, start) {
  var w = { start: start, days: [], studyTotal: 0, moveTotal: 0, pauseTotal: 0, count: 0, usageDays: 0, usageSum: 0, usageAvg: null, withinDays: 0, overDays: 0, studyDays: 0, moveDays: 0, subjects: {} };
  for (var i = 0; i < 7; i++) {
    var s = dayStats(d, addDays(start, i));
    w.days.push(s);
    w.studyTotal += s.study; w.moveTotal += s.move; w.pauseTotal += s.pause; w.count += s.count;
    if (s.study > 0) w.studyDays++;
    if (s.move > 0) w.moveDays++;
    if (s.usage != null) { w.usageDays++; w.usageSum += s.usage; }
    if (s.within === true) w.withinDays++;
    if (s.within === false) w.overDays++;
    Object.keys(s.subjects).forEach(function (m) { w.subjects[m] = (w.subjects[m] || 0) + s.subjects[m]; });
  }
  if (w.usageDays) w.usageAvg = w.usageSum / w.usageDays;
  return w;
}
function weekSummary(d, start) {
  var w = weekStats(d, start), prev = weekStats(d, addDays(start, -7)), good, tip, today = dayKey();
  if (w.studyTotal > 0 && prev.studyTotal > 0 && w.studyTotal > prev.studyTotal) good = 'Você estudou ' + fmtMin(w.studyTotal - prev.studyTotal) + ' a mais que na semana anterior.';
  else if (w.usageDays >= 2 && prev.usageDays >= 2 && w.usageAvg <= prev.usageAvg - 5) good = 'Sua média de tela ficou ' + fmtMin(prev.usageAvg - w.usageAvg) + ' abaixo da semana anterior, nos dias informados.';
  else if (w.withinDays > 0) good = 'Você ficou dentro da meta de tela em ' + plural(w.withinDays, 'dia', 'dias') + '.';
  else if (w.studyDays > 0 && w.moveDays > 0) good = 'Você estudou em ' + plural(w.studyDays, 'dia', 'dias') + ' e se exercitou em ' + plural(w.moveDays, 'dia', 'dias') + '.';
  else if (w.studyDays > 0) good = 'Você estudou em ' + plural(w.studyDays, 'dia', 'dias') + ', ' + fmtMin(w.studyTotal) + ' no total.';
  else if (w.moveDays > 0) good = 'Você se exercitou em ' + plural(w.moveDays, 'dia', 'dias') + ', ' + fmtMin(w.moveTotal) + ' no total.';
  else if (w.count > 0) good = 'Você fez ' + plural(w.count, 'pausa', 'pausas') + ' longe da tela.';
  else good = 'Esta semana ainda não tem registros. Qualquer começo vale, até 5 minutos.';

  var soon = upcomingExams(d).filter(function (e) { return e.date && diffDays(e.date, today) <= 7; });
  var idle = d.prefs.hard.filter(function (m) { return !w.subjects[m]; });
  var firstSport = d.prefs.sports.length ? sportName(d.prefs.sports[0]).toLowerCase() : 'caminhada';
  if (soon.length) tip = 'A prova de ' + soon[0].subject + ' é ' + relDay(soon[0].date) + '. Reserve duas sessões de 25 minutos' + (soon[0].topic ? ' para revisar: ' + soon[0].topic + '.' : ' para revisar.');
  else if (idle.length) tip = 'Você marcou ' + idle[0] + ' como matéria difícil e ela ainda não apareceu nesta semana. Que tal 10 minutos?';
  else if (w.moveTotal === 0) tip = 'Experimente 10 minutos de ' + firstSport + ' em um dia desta semana.';
  else if (w.studyTotal === 0) tip = 'Marque uma sessão curta de estudo, de 10 ou 25 minutos, para o próximo dia.';
  else if (w.usageDays < 3) tip = 'Informe o tempo de tela em mais dias para enxergar a tendência.';
  else if (w.overDays > w.withinDays && d.goals.dailyMin) tip = 'Se a meta estiver distante, ajuste para um valor perto da sua média e reduza aos poucos.';
  else tip = 'Repita o que funcionou e deixe uma sessão curta já combinada para amanhã.';
  return { good: good, tip: tip, w: w, prev: prev };
}
/* ---------- sequência de dias (foguinho): gentil, com um dia de folga por semana ---------- */
function streakWalk(active, start) {
  var d = start, count = 0, sinceRest = 7, rests = {}, guard = 0;
  while (guard++ < 4000) {
    if (active[d]) count++;
    else if (sinceRest >= 7 && active[addDays(d, -1)]) { rests[d] = 1; sinceRest = -1; }
    else break;
    sinceRest++;
    d = addDays(d, -1);
  }
  return { count: count, rests: rests };
}
function streakInfo(d) {
  var active = {}, today = dayKey(), yesterday = addDays(today, -1);
  d.sessions.forEach(function (s) { active[s.day] = 1; });
  var todayDone = !!active[today], cur = streakWalk(active, todayDone ? today : yesterday), best = cur.count, week = [];
  Object.keys(active).forEach(function (k) { var c = streakWalk(active, k).count; if (c > best) best = c; });
  for (var i = 6; i >= 0; i--) { var k = addDays(today, -i); week.push({ key: k, st: active[k] ? 'ativo' : (cur.rests[k] ? 'folga' : 'vazio') }); }
  var marks = [3, 7, 14, 30, 60, 100], next = (Math.floor(cur.count / 100) + 1) * 100;
  for (var m = 0; m < marks.length; m++) if (cur.count < marks[m]) { next = marks[m]; break; }
  return {
    count: cur.count, todayDone: todayDone, restedYesterday: !todayDone && !!cur.rests[yesterday], best: best, week: week, next: next,
    milestone: [3, 7, 14, 30, 60].indexOf(cur.count) >= 0 || (cur.count >= 100 && cur.count % 100 === 0)
  };
}
function streakMessage(s) {
  if (s.count === 0) return s.best > 0 ? 'Recomeçar faz parte. Uma sessão hoje e a sequência volta para o dia 1.' : 'Registre uma sessão de estudo, exercício ou pausa hoje para acender o foguinho.';
  if (s.todayDone) {
    if (s.milestone) return 'Marca de ' + s.count + ' dias alcançada. Bonito de ver.';
    var left = s.next - s.count;
    return 'Hoje já contou. ' + (left === 1 ? 'Falta 1 dia' : 'Faltam ' + left + ' dias') + ' para a marca de ' + s.next + '.';
  }
  if (s.restedYesterday) return 'Ontem foi seu dia de folga. Uma sessão hoje mantém a sequência.';
  return 'Uma sessão hoje, mesmo de 5 minutos, mantém a sequência.';
}
function homeMessage(d) {
  var s = dayStats(d, dayKey());
  if (s.study > 0 && s.move > 0) return 'Hoje já teve estudo e movimento. Belo equilíbrio.';
  if (s.study > 0) return 'Você já estudou ' + fmtMin(s.study) + ' hoje. Bom ritmo.';
  if (s.move > 0) return 'Corpo em movimento: ' + fmtMin(s.move) + ' de exercício hoje.';
  var msgs = ['Um passo de cada vez.', 'Começar com 5 minutos já vale.', 'Você decide o ritmo.', 'Pausas curtas somam bastante.', 'Hoje é um bom dia para uma pausa curta.', 'Cada minuto longe da tela conta.'];
  return msgs[hashStr(dayKey()) % msgs.length];
}
function gradualSuggestion(d) {
  var g = d.goals;
  if (!g.gradual.on || g.dailyMin == null) return null;
  var wk = weekStart(dayKey());
  if (g.gradual.week === wk) return null;
  var to = g.dailyMin - g.gradual.step;
  if (to < g.gradual.floor) return null;
  return { from: g.dailyMin, to: to, week: wk };
}

/* ---------- desafios pessoais (privados, opcionais, por semana) ---------- */
var CHALLENGE_PRESETS = [
  ['studyDays', 3], ['studyDays', 5], ['moveMin', 60], ['moveMin', 120], ['pauses', 5], ['goalDays', 3]
];
function challengeLabel(c) {
  if (c.type === 'studyDays') return 'Estudar em ' + c.target + ' dias da semana';
  if (c.type === 'moveMin') return 'Somar ' + fmtMin(c.target) + ' de exercício na semana';
  if (c.type === 'pauses') return 'Fazer ' + c.target + ' pausas ou sessões na semana';
  if (c.type === 'goalDays') return 'Ficar dentro da meta de tela em ' + c.target + ' dias';
  return 'Estudar ' + fmtMin(c.target) + ' de ' + (c.param || 'uma matéria') + ' na semana';
}
function challengeProgress(d, c) {
  var w = weekStats(d, c.week), done = 0;
  if (c.type === 'studyDays') done = w.studyDays;
  else if (c.type === 'moveMin') done = w.moveTotal;
  else if (c.type === 'pauses') done = w.count;
  else if (c.type === 'goalDays') done = w.withinDays;
  else done = w.subjects[c.param] || 0;
  var unit = (c.type === 'moveMin' || c.type === 'hardMin') ? 'min' : '';
  return { done: done, target: c.target, pct: clamp(Math.round(done * 100 / c.target), 0, 100), ok: done >= c.target, unit: unit };
}
