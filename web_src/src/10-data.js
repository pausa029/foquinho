/* ---------- estado e armazenamento (tudo fica neste navegador) ---------- */
var KEY_DEVICE = 'pausa+.v1.device';
function keyData(id) { return 'pausa+.v1.data.' + id; }

var S = {
  device: null,       /* perfis locais e sessão */
  data: null,         /* dados do perfil em uso (ou do modo demonstração) */
  user: null,         /* { id, name } | { id: 'guest' } */
  demo: false,
  route: { name: 'welcome', p: {} },
  stack: [],
  modal: null,
  storageOk: true,
  saveFailed: false,
  tmp: {},
  alerts: [],
  wakeActive: false,
  notifBroken: false,
  dl: null,           /* capacidade de salvar arquivos, quando o visualizador oferece */
  drop: {}, returnFocus: null, focusAfter: null, focusField: null,
  today: null
};
var mem = {};

function probeStorage() {
  try {
    var ls = window.localStorage, k = 'pausa+.probe';
    ls.setItem(k, '1');
    var ok = ls.getItem(k) === '1';
    ls.removeItem(k);
    return ok;
  } catch (e) { return false; }
}
function lsGet(k) {
  if (S.storageOk) { try { return window.localStorage.getItem(k); } catch (e) { /* cai para a memória */ } }
  return has(mem, k) ? mem[k] : null;
}
function lsSet(k, v) {
  mem[k] = v;
  if (!S.storageOk) return false;
  try { window.localStorage.setItem(k, v); return true; } catch (e) { S.saveFailed = true; return false; }
}
function lsDel(k) {
  delete mem[k];
  if (!S.storageOk) return;
  try { window.localStorage.removeItem(k); } catch (e) { /* nada a fazer */ }
}

/* ---------- limpeza de dados lidos (armazenamento ou importação) ---------- */
function str(v, max) { return typeof v === 'string' ? v.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, max || 80) : ''; }
function num(v, lo, hi, def) {
  if (typeof v !== 'number' || !isFinite(v)) return def;
  return clamp(Math.round(v), lo, hi);
}
function numOrNull(v, lo, hi) { return (typeof v === 'number' && isFinite(v)) ? clamp(Math.round(v), lo, hi) : null; }
function arr(v, max) { return Array.isArray(v) ? v.slice(0, max || 500) : []; }
function oneOf(v, list, def) { return list.indexOf(v) >= 0 ? v : def; }
function hm(v, def) { return hmToMin(v) == null ? def : (pad2(Math.floor(hmToMin(v) / 60)) + ':' + pad2(hmToMin(v) % 60)); }

function newDevice() { return { v: 1, profiles: [], session: null, demo: false, lock: { fails: 0, until: 0 } }; }
function loadDevice() {
  var d = newDevice(), raw = lsGet(KEY_DEVICE);
  if (!raw) return d;
  try {
    var x = JSON.parse(raw) || {};
    d.profiles = arr(x.profiles, 30).map(function (p) {
      if (!p || typeof p !== 'object') return null;
      var o = { id: str(p.id, 30), name: str(p.name, 20), salt: str(p.salt, 64), hash: str(p.hash, 128), iter: num(p.iter, 1000, 5000000, 0), createdAt: num(p.createdAt, 0, 9e15, 0) };
      return (o.id && o.name && o.salt && o.hash && o.iter) ? o : null;
    }).filter(Boolean);
    var sess = str(x.session, 30);
    d.session = (sess === 'guest' || d.profiles.some(function (p) { return p.id === sess; })) ? sess : null;
    d.demo = !!x.demo;
    if (x.lock && typeof x.lock === 'object') d.lock = { fails: num(x.lock.fails, 0, 99, 0), until: num(x.lock.until, 0, 9e15, 0) };
  } catch (e) { /* dados ilegíveis: começa do zero */ }
  return d;
}
function saveDevice() { lsSet(KEY_DEVICE, JSON.stringify(S.device)); }

function newData() {
  return {
    v: 1, createdAt: now(), onboarded: false,
    prefs: { sports: [], subjects: [], hard: [], exams: [], usual: null },
    goals: {
      dailyMin: null,
      byDay: { on: false, min: [null, null, null, null, null, null, null] },
      sessionMin: 60,
      gradual: { on: false, step: 15, floor: 120, week: null },
      studyWeek: null, moveWeek: null
    },
    rem: { on: true, pausedUntil: 0, quiet: { on: false, from: '22:00', to: '07:00' }, list: [], firedDay: null, fired: {}, snooze: {} },
    usage: {}, sessions: [], fav: [], later: [], custom: [], plan: null, challenges: [],
    useSession: null, timer: null, splan: planDefaults(), planSessions: [],
    ui: { theme: 'auto', font: 0, sound: true, vibrate: true, awake: true, mood: false },
    flags: {}
  };
}

var KINDS = ['estudo', 'exercicio', 'pausa'];
var REM_KINDS = ['estudo', 'exercicio', 'refeicao', 'dormir', 'outro'];

function normTimer(t) {
  if (!t || typeof t !== 'object') return null;
  var kind = oneOf(t.kind, KINDS, null);
  if (!kind) return null;
  var o = {
    kind: kind, title: str(t.title, 120), subject: str(t.subject, 40) || null, sport: str(t.sport, 44) || null,
    actId: str(t.actId, 160) || null, planId: str(t.planId, 60) || null,
    startedAt: num(t.startedAt, 0, 9e15, now()), paused: !!t.paused,
    remainMs: num(t.remainMs, 0, 6e7, 0), doneFocusMs: num(t.doneFocusMs, 0, 6e8, 0),
    phaseMs: num(t.phaseMs, 1000, 6e7, 60000), planMin: num(t.planMin, 1, 2000, 1),
    endsAt: num(t.endsAt, 0, 9e15, now()), mood0: numOrNull(t.mood0, 1, 5), cyc: null, finished: null
  };
  if (t.cyc && typeof t.cyc === 'object') {
    o.cyc = { focus: num(t.cyc.focus, 1, 180, 25), rest: num(t.cyc.rest, 1, 60, 5), total: num(t.cyc.total, 1, 12, 4), n: num(t.cyc.n, 1, 12, 1), phase: oneOf(t.cyc.phase, ['foco', 'intervalo'], 'foco') };
  }
  if (t.finished && typeof t.finished === 'object') {
    o.finished = { doneMin: num(t.finished.doneMin, 0, 2000, 0), early: !!t.finished.early, at: num(t.finished.at, 0, 9e15, now()) };
  }
  return o;
}

function normalizeData(x) {
  var d = newData();
  if (!x || typeof x !== 'object') return d;
  d.createdAt = num(x.createdAt, 0, 9e15, d.createdAt);
  d.onboarded = !!x.onboarded;

  var p = (x.prefs && typeof x.prefs === 'object') ? x.prefs : {};
  d.prefs.sports = uniq(arr(p.sports, 40).map(function (s) { return str(s, 44); }).filter(Boolean));
  d.prefs.subjects = uniq(arr(p.subjects, 40).map(function (s) { return str(s, 40); }).filter(Boolean));
  d.prefs.hard = uniq(arr(p.hard, 40).map(function (s) { return str(s, 40); })).filter(function (m) { return d.prefs.subjects.indexOf(m) >= 0; });
  d.prefs.exams = arr(p.exams, 60).map(function (e) {
    if (!e || typeof e !== 'object') return null;
    var o = { id: str(e.id, 30) || uid(), subject: str(e.subject, 40), topic: str(e.topic, 80), date: isDayKey(e.date) ? e.date : null };
    return o.subject ? o : null;
  }).filter(Boolean);
  d.prefs.usual = oneOf(p.usual, ['lt2', '2a4', '4a6', '6a8', 'gt8', 'ns'], null);

  var g = (x.goals && typeof x.goals === 'object') ? x.goals : {};
  d.goals.dailyMin = numOrNull(g.dailyMin, 15, 1440);
  if (g.byDay && typeof g.byDay === 'object') {
    d.goals.byDay.on = !!g.byDay.on;
    var mins = arr(g.byDay.min, 7);
    for (var i = 0; i < 7; i++) d.goals.byDay.min[i] = numOrNull(mins[i], 15, 1440);
  }
  d.goals.sessionMin = g.sessionMin === null ? null : num(g.sessionMin, 5, 480, 60);
  if (g.gradual && typeof g.gradual === 'object') {
    d.goals.gradual = { on: !!g.gradual.on, step: num(g.gradual.step, 5, 60, 15), floor: num(g.gradual.floor, 15, 1440, 120), week: isDayKey(g.gradual.week) ? g.gradual.week : null };
  }
  d.goals.studyWeek = numOrNull(g.studyWeek, 10, 3000);
  d.goals.moveWeek = numOrNull(g.moveWeek, 10, 3000);

  var r = (x.rem && typeof x.rem === 'object') ? x.rem : {};
  d.rem.on = r.on !== false;
  d.rem.pausedUntil = num(r.pausedUntil, 0, 9e15, 0);
  if (r.quiet && typeof r.quiet === 'object') d.rem.quiet = { on: !!r.quiet.on, from: hm(r.quiet.from, '22:00'), to: hm(r.quiet.to, '07:00') };
  d.rem.list = arr(r.list, 40).map(function (it) {
    if (!it || typeof it !== 'object') return null;
    var o = {
      id: str(it.id, 30) || uid(), label: str(it.label, 60), kind: oneOf(it.kind, REM_KINDS, 'outro'), time: hm(it.time, null),
      days: uniq(arr(it.days, 7).filter(function (n) { return typeof n === 'number' && n >= 0 && n <= 6 && Math.floor(n) === n; })), on: it.on !== false
    };
    return (o.label && o.time) ? o : null;
  }).filter(Boolean);
  d.rem.firedDay = isDayKey(r.firedDay) ? r.firedDay : null;
  if (r.fired && typeof r.fired === 'object') Object.keys(r.fired).slice(0, 80).forEach(function (k) { d.rem.fired[str(k, 40)] = str(r.fired[k], 10); });
  if (r.snooze && typeof r.snooze === 'object') Object.keys(r.snooze).slice(0, 80).forEach(function (k) { var v = numOrNull(r.snooze[k], 0, 9e15); if (v) d.rem.snooze[str(k, 40)] = v; });

  if (x.usage && typeof x.usage === 'object') {
    Object.keys(x.usage).slice(0, 4000).forEach(function (k) {
      var u = x.usage[k];
      if (!isDayKey(k) || !u || typeof u !== 'object') return;
      var m = numOrNull(u.min, 0, 1440);
      if (m == null) return;
      d.usage[k] = { min: m, at: num(u.at, 0, 9e15, keyToDate(k).getTime()), goal: numOrNull(u.goal, 15, 1440) };
    });
  }
  d.sessions = arr(x.sessions, 20000).map(function (s) {
    if (!s || typeof s !== 'object') return null;
    var kind = oneOf(s.kind, KINDS, null), m = numOrNull(s.min, 1, 1000), start = numOrNull(s.start, 0, 9e15);
    if (!kind || m == null || start == null) return null;
    return {
      id: str(s.id, 30) || uid(), kind: kind, title: str(s.title, 120), subject: str(s.subject, 40) || null, sport: str(s.sport, 44) || null,
      actId: str(s.actId, 160) || null, plan: num(s.plan, 1, 2000, m), min: m, start: start, end: num(s.end, 0, 9e15, start),
      day: isDayKey(s.day) ? s.day : dayKey(new Date(start)), m0: numOrNull(s.m0, 1, 5), m1: numOrNull(s.m1, 1, 5)
    };
  }).filter(Boolean);
  d.fav = uniq(arr(x.fav, 400).map(function (s) { return str(s, 160); }).filter(Boolean));
  d.later = uniq(arr(x.later, 400).map(function (s) { return str(s, 160); }).filter(Boolean));
  d.custom = arr(x.custom, 200).map(function (c) {
    if (!c || typeof c !== 'object') return null;
    var o = { id: str(c.id, 30) || uid(), kind: oneOf(c.kind, ['estudo', 'exercicio'], 'estudo'), title: str(c.title, 80), min: num(c.min, 1, 240, 10), place: oneOf(c.place, ['c', 'f', 'q', 'l'], 'q'), energy: oneOf(c.energy, ['t', 'm', 'a'], 't') };
    return o.title ? o : null;
  }).filter(Boolean);
  if (x.plan && typeof x.plan === 'object' && str(x.plan.text, 160)) d.plan = { text: str(x.plan.text, 160), min: num(x.plan.min, 1, 120, 5), kind: oneOf(x.plan.kind, KINDS, 'pausa') };
  d.challenges = arr(x.challenges, 200).map(function (c) {
    if (!c || typeof c !== 'object') return null;
    var type = oneOf(c.type, ['studyDays', 'moveMin', 'pauses', 'goalDays', 'hardMin'], null);
    if (!type || !isDayKey(c.week)) return null;
    return { id: str(c.id, 30) || uid(), type: type, target: num(c.target, 1, 3000, 1), param: str(c.param, 40) || null, week: c.week };
  }).filter(Boolean);
  if (x.useSession && typeof x.useSession === 'object' && numOrNull(x.useSession.start, 0, 9e15) != null) {
    d.useSession = { start: num(x.useSession.start, 0, 9e15, now()), limit: num(x.useSession.limit, 5, 480, 60), alerted: !!x.useSession.alerted, snooze: num(x.useSession.snooze, 0, 9e15, 0) };
  }
  d.timer = normTimer(x.timer);
  d.splan = normPlan(x.splan);
  d.planSessions = normPlanSessions(x.planSessions, d.prefs.subjects);

  var u2 = (x.ui && typeof x.ui === 'object') ? x.ui : {};
  d.ui = {
    theme: oneOf(u2.theme, ['auto', 'light', 'dark'], 'auto'), font: num(u2.font, 0, 2, 0),
    sound: u2.sound !== false, vibrate: u2.vibrate !== false, awake: u2.awake !== false, mood: !!u2.mood
  };
  if (x.flags && typeof x.flags === 'object') Object.keys(x.flags).slice(0, 60).forEach(function (k) { d.flags[str(k, 40)] = str(String(x.flags[k]), 40); });
  return d;
}

function loadData(id) {
  var raw = lsGet(keyData(id));
  if (!raw) return null;
  try { return normalizeData(JSON.parse(raw)); }
  catch (e) {
    lsSet(keyData(id) + '.ilegivel', raw);
    S.tmp.loadError = true;
    return null;
  }
}
function save() {
  if (S.demo || !S.user || !S.data) return;
  lsSet(keyData(S.user.id), JSON.stringify(S.data));
}

/* ---------- modo demonstração: dados fictícios, gerados na hora e nunca salvos ---------- */
function demoData() {
  var d = newData(), today = dayKey(), rnd = seeded(hashStr('pausa-demo-' + today));
  var startToday = new Date(); startToday.setHours(0, 0, 0, 0);
  d.onboarded = true;
  d.prefs.sports = ['futebol', 'corrida', 'corda'];
  d.prefs.subjects = ['Matemática', 'Português', 'História', 'Física', 'Inglês'];
  d.prefs.hard = ['Matemática', 'Física'];
  d.prefs.exams = [
    { id: 'demo1', subject: 'Matemática', topic: 'Equações do 2º grau', date: addDays(today, 4) },
    { id: 'demo2', subject: 'História', topic: 'Era Vargas', date: addDays(today, 9) },
    { id: 'demo3', subject: 'Física', topic: 'Leis de Newton', date: addDays(today, 16) }
  ];
  d.prefs.usual = '4a6';
  d.goals.dailyMin = 285;
  d.goals.gradual = { on: true, step: 15, floor: 180, week: weekStart(addDays(today, -7)) };
  d.goals.studyWeek = 240;
  d.goals.moveWeek = 120;
  d.rem.list = [
    { id: 'r1', label: 'Hora de estudar', kind: 'estudo', time: '19:00', days: [0, 1, 2, 3, 4], on: true },
    { id: 'r2', label: 'Treino ou caminhada', kind: 'exercicio', time: '17:00', days: [0, 2, 4, 5], on: true },
    { id: 'r3', label: 'Celular longe na hora de dormir', kind: 'dormir', time: '22:30', days: [0, 1, 2, 3, 4, 5, 6], on: true }
  ];
  d.rem.quiet = { on: true, from: '22:45', to: '07:00' };

  var subs = d.prefs.subjects, i, k;
  for (i = 20; i >= 1; i--) {
    k = addDays(today, -i);
    var wknd = wdIndex(k) >= 5;
    if (i !== 5 && i !== 12) {
      var base = 268 + i * 5.5 + (wknd ? 35 : 0);
      var min = Math.round((base + (rnd() - 0.5) * 50) / 5) * 5;
      d.usage[k] = { min: min, at: keyToDate(addDays(k, 1)).getTime() - 4 * 3600000, goal: i > 13 ? 315 : (i > 6 ? 300 : 285) };
    }
    var noon = keyToDate(k).getTime();
    if (rnd() < (wknd ? 0.45 : 0.8)) {
      var m = subs[Math.floor(rnd() * subs.length)], sm = [20, 25, 25, 30, 50][Math.floor(rnd() * 5)];
      d.sessions.push({ id: 'ds' + i, kind: 'estudo', title: 'Resolver 5 exercícios: ' + m, subject: m, sport: null, actId: null, plan: sm, min: sm, start: noon + 7 * 3600000, end: noon + 7 * 3600000 + sm * 60000, day: k, m0: 3, m1: 4 });
    }
    if (rnd() < (wknd ? 0.7 : 0.5)) {
      var em = [10, 20, 20, 30][Math.floor(rnd() * 4)], sp = rnd() < 0.5 ? ['futebol', 'Embaixadinhas: tente bater seu recorde'] : ['corrida', 'Corrida leve, em ritmo de conversa'];
      d.sessions.push({ id: 'de' + i, kind: 'exercicio', title: sp[1], subject: null, sport: sp[0], actId: null, plan: em, min: em, start: noon + 5 * 3600000, end: noon + 5 * 3600000 + em * 60000, day: k, m0: 3, m1: 5 });
    }
    if (rnd() < 0.4) {
      d.sessions.push({ id: 'dp' + i, kind: 'pausa', title: 'Alongar pescoço, ombros e punhos', subject: null, sport: null, actId: null, plan: 5, min: 5, start: noon + 3 * 3600000, end: noon + 3 * 3600000 + 300000, day: k, m0: null, m1: null });
    }
  }
  var t0 = Math.max(startToday.getTime(), now() - 150 * 60000);
  d.usage[today] = { min: 150, at: Math.max(startToday.getTime(), now() - 35 * 60000), goal: 285 };
  d.sessions.push({ id: 'dt1', kind: 'estudo', title: 'Revisar as anotações: Matemática · Equações do 2º grau', subject: 'Matemática', sport: null, actId: null, plan: 25, min: 25, start: t0, end: t0 + 25 * 60000, day: today, m0: 3, m1: 4 });
  d.sessions.push({ id: 'dt2', kind: 'pausa', title: 'Levantar, beber água e andar um pouco', subject: null, sport: null, actId: null, plan: 5, min: 5, start: t0 + 40 * 60000, end: t0 + 45 * 60000, day: today, m0: null, m1: null });
  d.plan = { text: 'Fazer 10 polichinelos e beber água', min: 5, kind: 'pausa' };
  d.challenges = [
    { id: 'dc1', type: 'studyDays', target: 4, param: null, week: weekStart(today) },
    { id: 'dc2', type: 'moveMin', target: 90, param: null, week: weekStart(today) }
  ];
  d.ui.mood = true;
  d.splan.days.forEach(function (a, i) { a.on = i < 5; a.from = '18:00'; a.to = '20:00'; });
  d.splan.configured = true;
  var gp = generatePlan(d, weekStart(today), addDays(weekStart(today), 6), new Date(), []);
  applyPlan(d, weekStart(today), addDays(weekStart(today), 6), gp);
  d.rem.list.forEach(function (r) { markTodayIfPast(d, r); });
  return d;
}
