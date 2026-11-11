/* ---------- ações: o que cada botão, chave e formulário faz ---------- */
function dv(el) { return el.getAttribute('data-v'); }
function dk(el) { return el.getAttribute('data-k'); }
function fakeEl(value) { return { getAttribute: function (n) { return n === 'data-v' ? value : null; } }; }
function toggleIn(list, item) { var i = list.indexOf(item); if (i >= 0) list.splice(i, 1); else list.push(item); return i < 0; }
function intVal(id) { var s = String(val(id)).trim(); if (s === '') return null; var n = parseInt(s, 10); return isNaN(n) ? NaN : n; }
function resume() {
  var sess = S.device.session, i;
  S.user = null; S.data = null;
  if (sess === 'guest') { S.user = { id: 'guest' }; S.data = loadData('guest') || newData(); }
  else if (sess) {
    for (i = 0; i < S.device.profiles.length; i++) if (S.device.profiles[i].id === sess) { S.user = { id: sess, name: S.device.profiles[i].name }; S.data = loadData(sess) || newData(); }
  }
  if (!S.user) { S.device.session = null; return 'welcome'; }
  return S.data.onboarded ? 'home' : 'onboard';
}
function enter(route) {
  if (route === 'onboard') S.tmp.ob = 0;
  S.stack = [];
  S.route = { name: route, p: {} };
  S.modal = null;
  S.tmp.err = null;
}
function finishOnboard() {
  S.data.onboarded = true;
  save();
  enter('home');
  toast('Tudo pronto. Suas escolhas podem ser ajustadas em Mais.');
}
function confirmBox(title, text, yes, act, value, danger) { openModal({ t: 'confirm', title: title, text: text, yes: yes, act: act, v: value, danger: !!danger }); }
function busyTimer() {
  if (!S.data.timer) return false;
  go('timer');
  toast('Já existe um tempo em andamento.');
  return true;
}

/* navegação e sessão */
A.tab = function (el) { go(dv(el)); };
A.nav = function (el) { go(dv(el)); };
A.back = function () { back(); };
A.goWelcome = function () { enter('welcome'); };
A.goSignup = function () { go('signup'); };
A.goLogin = function () { go('login'); };
A.goGoals = function () { go('goals'); };
A.goPrefs = function () { go('prefs'); };
A.goPlan = function () { S.tmp.pl = null; go('plan'); };
A.goChallenges = function () { go('challenges'); };
A.goData = function () { go('datap'); };
A.guest = function () { startGuest(); enter(S.data.onboarded ? 'home' : 'onboard'); };
A.demoOn = function () {
  S.demo = true;
  S.device.demo = true;
  saveDevice();
  S.user = { id: 'demo', name: '' };
  S.data = demoData();
  S.tmp = {};
  enter('home');
  toast('Modo demonstração: os dados são fictícios.');
};
A.demoOff = function () {
  S.demo = false;
  S.device.demo = false;
  saveDevice();
  wakeOff();
  S.tmp = {};
  enter(resume());
};
A.signOut = function () { wakeOff(); signOut(); S.tmp = {}; enter('welcome'); toast('Você saiu. Seus dados continuam neste aparelho.'); };
A.pickProfile = function (el) { S.tmp.liName = dv(el); S.drop['li-name'] = true; S.focusField = 'li-pass'; };
A.forgot = function () { openModal({ t: 'forgot' }); };
A.closeModal = function () { if (S.modal && S.modal.busy) return false; closeModal(); };
A.scrim = function () { if (S.modal && S.modal.busy) return false; closeModal(); };
A.confirmYes = function () {
  var m = S.modal;
  closeModal();
  if (m && A[m.act]) A[m.act](fakeEl(m.v));
};

FORMS.signup = async function () {
  var name = val('su-name'), p1 = val('su-pass'), p2 = val('su-pass2');
  S.tmp.busy = true; S.tmp.err = null;
  render();
  var r = await createProfile(name, p1, p2);
  S.tmp.busy = false;
  if (!r.ok) { S.tmp.err = { msg: r.err, field: r.field }; S.focusField = r.field || null; return; }
  S.drop['su-pass'] = true; S.drop['su-pass2'] = true;
  enter(S.data.onboarded ? 'home' : 'onboard');
  toast(r.migrated ? 'Perfil criado. Seus dados foram guardados nele.' : 'Perfil criado neste aparelho.');
};
FORMS.login = async function () {
  var name = val('li-name'), pass = val('li-pass');
  S.tmp.liName = name;
  S.tmp.busy = true; S.tmp.err = null;
  render();
  var r = await login(name, pass);
  S.tmp.busy = false;
  if (!r.ok) { S.tmp.err = { msg: r.err, field: r.field }; S.drop['li-pass'] = true; S.focusField = 'li-pass'; return; }
  S.tmp = {};
  enter(S.data.onboarded ? 'home' : 'onboard');
};
FORMS.forgot = function () {
  var id = val('fg-prof'), typed = normName(val('fg-name')).toLowerCase(), prof = null;
  S.device.profiles.forEach(function (p) { if (p.id === id) prof = p; });
  if (!prof || prof.name.toLowerCase() !== typed) { S.modal.err = 'O nome digitado não é igual ao do perfil escolhido.'; return; }
  removeProfile(prof.id);
  closeModal();
  toast('Perfil apagado deste aparelho.');
  if (!S.device.profiles.length) enter('welcome');
};
FORMS.pwd = async function () {
  var a = val('pw-cur'), b = val('pw-new'), c = val('pw-new2');
  S.modal.busy = true; S.modal.err = null;
  render();
  var r = await changePassword(a, b, c);
  if (!S.modal) return;
  S.modal.busy = false;
  if (!r.ok) { S.modal.err = r.err; S.focusField = r.field || null; return; }
  closeModal();
  toast('Senha alterada.');
};
FORMS.delProfile = async function () {
  var prof = currentProfile(), pass = val('dp-pass'), ok = false;
  if (!prof) { closeModal(); return; }
  S.modal.busy = true; S.modal.err = null;
  render();
  try { ok = await checkPassword(prof, pass); } catch (e) { ok = false; }
  if (!S.modal) return;
  S.modal.busy = false;
  if (!ok) { S.modal.err = 'A senha não confere.'; S.drop['dp-pass'] = true; S.focusField = 'dp-pass'; return; }
  wakeOff();
  removeProfile(prof.id);
  S.user = null; S.data = null; S.tmp = {};
  enter('welcome');
  toast('Perfil e dados apagados deste aparelho.');
};
A.pwdOpen = function () { openModal({ t: 'pwd' }); };
A.delProfileOpen = function () { openModal({ t: 'delProfile' }); };
CHANGES.showPw = function (el) {
  el.getAttribute('data-ids').split(',').forEach(function (id) { var inp = document.getElementById(id); if (inp) inp.type = el.checked ? 'text' : 'password'; });
  return false;
};

/* preferências */
A.sport = function (el) { toggleIn(S.data.prefs.sports, dv(el)); save(); };
A.subject = function (el) {
  var m = dv(el), d = S.data;
  if (!toggleIn(d.prefs.subjects, m)) d.prefs.hard = d.prefs.hard.filter(function (x) { return x !== m; });
  save();
};
A.hard = function (el) { toggleIn(S.data.prefs.hard, dv(el)); save(); };
FORMS.addSport = function () {
  var name = str(val('sp-new'), 40), d = S.data, id = null;
  if (!name) return false;
  SPORTS.forEach(function (s) { if (s[1].toLowerCase() === name.toLowerCase()) id = s[0]; });
  if (!id) id = 'c:' + name;
  if (d.prefs.sports.indexOf(id) < 0 && d.prefs.sports.length < 40) d.prefs.sports.push(id);
  S.drop['sp-new'] = true;
  save();
};
FORMS.addSubject = function () {
  var name = str(val('sb-new'), 40), d = S.data;
  if (!name) return false;
  SUBJECTS.forEach(function (s) { if (s.toLowerCase() === name.toLowerCase()) name = s; });
  d.prefs.subjects.forEach(function (s) { if (s.toLowerCase() === name.toLowerCase()) name = s; });
  if (d.prefs.subjects.indexOf(name) < 0 && d.prefs.subjects.length < 40) d.prefs.subjects.push(name);
  S.drop['sb-new'] = true;
  save();
};
A.addExam = function () { openModal({ t: 'exam', id: null }); };
A.editExam = function (el) { openModal({ t: 'exam', id: dv(el) }); };
A.delExam = function (el) { var id = dv(el); S.data.prefs.exams = S.data.prefs.exams.filter(function (e) { return e.id !== id; }); save(); toast('Prova excluída.'); };
A.clearPastExams = function () { var t = dayKey(); S.data.prefs.exams = S.data.prefs.exams.filter(function (e) { return !e.date || e.date >= t; }); save(); };
FORMS.exam = function () {
  var d = S.data, m = S.modal, subj = str(val('ex-subj'), 40), topic = str(val('ex-topic'), 80), date = val('ex-date');
  if (!subj) { m.err = 'Escolha a matéria.'; return; }
  if (date && !isDayKey(date)) { m.err = 'Data inválida. Use o seletor de data ou deixe em branco.'; return; }
  var rec = null;
  if (m.id) d.prefs.exams.forEach(function (e) { if (e.id === m.id) rec = e; });
  if (rec) { rec.subject = subj; rec.topic = topic; rec.date = date || null; }
  else if (d.prefs.exams.length < 60) d.prefs.exams.push({ id: uid(), subject: subj, topic: topic, date: date || null });
  if (d.prefs.subjects.indexOf(subj) < 0) d.prefs.subjects.push(subj);
  save();
  closeModal();
  toast('Prova salva.');
};
A.askClearPrefs = function () { confirmBox('Apagar preferências?', 'Esportes, matérias, dificuldades e provas serão apagados. O histórico continua.', 'Apagar preferências', 'clearPrefsNow', null, true); return; };
A.clearPrefsNow = function () { S.data.prefs = newData().prefs; save(); toast('Preferências apagadas.'); };

/* metas, passos e chaves */
A.usual = function (el) { var d = S.data, x = dv(el); d.prefs.usual = d.prefs.usual === x ? null : x; save(); };
A.setGoalDefault = function (el) { S.data.goals.dailyMin = clamp(parseInt(dv(el), 10) || 300, 15, 960); save(); };
A.clearGoal = function () { var g = S.data.goals; g.dailyMin = null; g.byDay.on = false; g.gradual.on = false; save(); };
function tfv() { return tform(); }
var STEPS = {
  goal: { get: function (d) { return d.goals.dailyMin; }, set: function (d, x) { d.goals.dailyMin = x; if (d.goals.gradual.floor > x) d.goals.gradual.floor = x; }, min: 15, max: 960, step: 15 },
  gstep: { get: function (d) { return d.goals.gradual.step; }, set: function (d, x) { d.goals.gradual.step = x; }, min: 5, max: 60, step: 5 },
  gfloor: { get: function (d) { return d.goals.gradual.floor; }, set: function (d, x) { d.goals.gradual.floor = Math.min(x, d.goals.dailyMin || x); }, min: 15, max: 960, step: 15 },
  studyWeek: { get: function (d) { return d.goals.studyWeek; }, set: function (d, x) { d.goals.studyWeek = x; }, min: 30, max: 1500, step: 30 },
  moveWeek: { get: function (d) { return d.goals.moveWeek; }, set: function (d, x) { d.goals.moveWeek = x; }, min: 30, max: 1500, step: 30 },
  cf: { get: function () { return tfv().cf; }, set: function (d, x) { tfv().cf = x; }, min: 5, max: 90, step: 5, mem: true },
  cr: { get: function () { return tfv().cr; }, set: function (d, x) { tfv().cr = x; }, min: 1, max: 30, step: 1, mem: true },
  cn: { get: function () { return tfv().cn; }, set: function (d, x) { tfv().cn = x; }, min: 2, max: 8, step: 1, mem: true }
};
function gdStep(i) {
  return { get: function (d) { return d.goals.byDay.min[i] != null ? d.goals.byDay.min[i] : d.goals.dailyMin; }, set: function (d, x) { d.goals.byDay.min[i] = x; }, min: 15, max: 960, step: 15 };
}
A.step = function (el) {
  var key = dk(el), dir = parseInt(dv(el), 10), d = S.data, s, cur, nx;
  if (key === 'done') {
    var fn = d.timer && d.timer.finished;
    if (!fn) return;
    cur = fn.doneMin;
    if (dir > 0) nx = cur < 10 ? cur + 1 : Math.floor(cur / 5) * 5 + 5;
    else nx = cur <= 10 ? cur - 1 : Math.ceil(cur / 5) * 5 - 5;
    fn.doneMin = clamp(nx, 0, 600);
    save();
    return;
  }
  s = /^gd[0-6]$/.test(key) ? gdStep(+key.charAt(2)) : STEPS[key];
  if (!s) return;
  cur = s.get(d);
  if (cur == null) return;
  s.set(d, clamp(cur + dir * s.step, s.min, s.max));
  if (!s.mem) save();
};
var TOG = {
  quiet: function (d) { d.rem.quiet.on = !d.rem.quiet.on; },
  byDay: function (d) { d.goals.byDay.on = !d.goals.byDay.on; },
  gradual: function (d) {
    var g = d.goals.gradual;
    g.on = !g.on;
    if (g.on) { g.week = weekStart(dayKey()); if (d.goals.dailyMin != null && g.floor > d.goals.dailyMin) g.floor = d.goals.dailyMin; }
  },
  studyWeek: function (d) { d.goals.studyWeek = d.goals.studyWeek == null ? 240 : null; },
  moveWeek: function (d) { d.goals.moveWeek = d.goals.moveWeek == null ? 120 : null; },
  remOn: function (d) { d.rem.on = !d.rem.on; },
  sound: function (d) { d.ui.sound = !d.ui.sound; if (d.ui.sound) { primeAudio(); chime(); } },
  vibrate: function (d) { d.ui.vibrate = !d.ui.vibrate; if (d.ui.vibrate) buzz(); },
  awake: function (d) { d.ui.awake = !d.ui.awake; if (!d.ui.awake) wakeOff(); else if (d.timer && !d.timer.paused && !d.timer.finished) wakeOn(); },
  mood: function (d) { d.ui.mood = !d.ui.mood; },
  obStudy: function (d) { toggleObRem(d, 'estudo'); },
  obMove: function (d) { toggleObRem(d, 'exercicio'); }
};
function toggleObRem(d, kind) {
  var id = 'ob-' + kind, had = d.rem.list.some(function (r) { return r.id === id; });
  if (had) { d.rem.list = d.rem.list.filter(function (r) { return r.id !== id; }); return; }
  var p = REM_PRESET[kind], r = { id: id, label: p[0], kind: kind, time: p[1], days: p[2].slice(), on: true };
  d.rem.list.push(r);
  markTodayIfPast(d, r);
}
A.toggle = function (el) {
  var key = dk(el);
  if (key === 'tCyc') { tform().cyc = !tform().cyc; return; }
  if (!TOG[key]) return;
  TOG[key](S.data);
  save();
};
CHANGES.time = function (el) {
  var d = S.data, key = dk(el), t = hm(el.value, null);
  if (!t) return false;
  if (key === 'q-from') d.rem.quiet.from = t;
  else if (key === 'q-to') d.rem.quiet.to = t;
  else d.rem.list.forEach(function (r) { if (r.id === key) { r.time = t; markTodayIfPast(d, r); } });
  save();
  return false;
};
A.sessMin = function (el) {
  var x = dv(el), g = S.data.goals;
  if (x === 'off') { g.sessionMin = null; S.tmp.sessCustom = false; }
  else if (x === 'x') { S.tmp.sessCustom = true; if (g.sessionMin == null) g.sessionMin = 45; }
  else { g.sessionMin = parseInt(x, 10); S.tmp.sessCustom = false; }
  save();
};
CHANGES.sessInput = function (el) {
  var n = parseInt(el.value, 10);
  if (isNaN(n)) return false;
  S.data.goals.sessionMin = clamp(n, 5, 480);
  save();
  return false;
};
A.gradualYes = function () {
  var d = S.data, g = d.goals, s = gradualSuggestion(d);
  if (!s) return;
  g.dailyMin = s.to;
  for (var i = 0; i < 7; i++) if (g.byDay.min[i] != null) g.byDay.min[i] = Math.max(g.gradual.floor, g.byDay.min[i] - g.gradual.step);
  g.gradual.week = s.week;
  save();
  toast('Meta ajustada para ' + fmtMin(s.to) + ' por dia.');
};
A.gradualNo = function () { var s = gradualSuggestion(S.data); if (s) { S.data.goals.gradual.week = s.week; save(); } };
A.askNotif = function () {
  notifAsk(function (state) {
    if (state === 'granted') {
      if (sysNotify('Foquinho', 'Notificações liberadas neste navegador.')) toast('Notificações liberadas.');
      else toast('O navegador liberou a permissão, mas não deixa esta página enviar notificações.');
    } else toast('Notificações não liberadas. Os lembretes aparecem dentro do app.');
    render();
  });
  return false;
};

/* configuração inicial */
A.obNext = function () { if ((S.tmp.ob || 0) >= OB_STEPS - 1) finishOnboard(); else S.tmp.ob = (S.tmp.ob || 0) + 1; };
A.obBack = function () { S.tmp.ob = Math.max(0, (S.tmp.ob || 0) - 1); };
A.obSkipAll = function () { finishOnboard(); };

/* tempo de tela */
A.logUsage = function (el) { openModal({ t: 'usage', day: dv(el) }); };
A.whereUsage = function () { openModal({ t: 'whereUsage' }); };
A.delUsage = function (el) { delete S.data.usage[dv(el)]; save(); closeModal(); toast('Registro apagado.'); };
A.skipYday = function () { S.data.flags.yday = dayKey(); save(); };
FORMS.usage = function () {
  var d = S.data, m = S.modal, h = intVal('us-h'), mi = intVal('us-m');
  if (h == null && mi == null) { m.err = 'Informe as horas, os minutos ou os dois.'; return; }
  h = h == null ? 0 : h; mi = mi == null ? 0 : mi;
  if (isNaN(h) || isNaN(mi) || h < 0 || h > 24 || mi < 0 || mi > 59 || h * 60 + mi > 1440) { m.err = 'Use horas de 0 a 24 e minutos de 0 a 59.'; return; }
  var total = h * 60 + mi, day = m.day;
  setUsage(d, day, total);
  save();
  closeModal();
  var goal = d.usage[day].goal;
  if (day === dayKey() && goal != null && total > goal) toast('Registrado. Hoje passou da meta, e tudo bem: amanhã você tenta de novo.');
  else if (day === dayKey() && goal != null && total >= goal * 0.8) toast('Registrado. Você está perto da meta de hoje. Que tal uma pausa?');
  else toast('Tempo de tela registrado: ' + fmtMin(total) + '.');
};

/* painel */
A.quickPause = function () {
  if (busyTimer()) return;
  timerStart({ kind: 'pausa', min: 5, title: '' });
  go('timer');
};
A.quickFocus = function () { if (busyTimer()) return; S.tmp.tf = null; go('timer'); };
A.nextSug = function () { S.tmp.sug = (S.tmp.sug || 0) + 1; };
A.studyExam = function (el) {
  var d = S.data, id = dv(el), e = null;
  d.prefs.exams.forEach(function (x) { if (x.id === id) e = x; });
  if (!e || busyTimer()) return;
  S.tmp.tf = null;
  var f = tform();
  f.subject = d.prefs.subjects.indexOf(e.subject) >= 0 ? e.subject : '';
  f.title = 'Estudar para a prova: ' + e.subject + (e.topic ? ' · ' + e.topic : '');
  go('timer');
};
A.doPlan = function () {
  var p = S.data.plan;
  if (!p || busyTimer()) return;
  timerStart({ kind: p.kind, min: p.min, title: p.text });
  go('timer');
};
A.startUse = function () {
  var d = S.data;
  d.useSession = { start: now(), limit: d.goals.sessionMin || 60, alerted: false, snooze: 0 };
  save();
  toast('Contagem iniciada. Aviso em ' + fmtMin(d.useSession.limit) + '.');
};
A.endUse = function () { S.data.useSession = null; save(); };
A.unmute = function () { S.data.rem.pausedUntil = 0; save(); };
A.mute = function (el) {
  var d = S.data, x = dv(el);
  if (x === 'amanha') { var t = keyToDate(addDays(dayKey(), 1)); t.setHours(6, 0, 0, 0); d.rem.pausedUntil = t.getTime(); }
  else d.rem.pausedUntil = now() + parseInt(x, 10) * 60000;
  save();
  toast('Lembretes em silêncio até ' + fmtClock(d.rem.pausedUntil) + '.');
};

/* atividades */
A.startAct = function (el) {
  var a = actById(S.data, dv(el));
  if (!a || busyTimer()) return;
  S.tmp.tf = null;
  var f = tform();
  f.kind = a.kind; f.min = a.min; f.custom = [5, 10, 25, 50].indexOf(a.min) < 0;
  f.subject = a.subject || ''; f.sport = a.sport || ''; f.actId = a.id; f.title = a.title;
  go('timer');
};
A.fav = function (el) { var on = toggleIn(S.data.fav, dv(el)); save(); announce(on ? 'Adicionada às favoritas.' : 'Removida das favoritas.'); };
A.later = function (el) { var on = toggleIn(S.data.later, dv(el)); save(); announce(on ? 'Guardada para depois.' : 'Removida da lista para depois.'); };
A.delCustom = function (el) {
  var id = dv(el), d = S.data, aid = 'c:' + id;
  d.custom = d.custom.filter(function (c) { return c.id !== id; });
  d.fav = d.fav.filter(function (x) { return x !== aid; });
  d.later = d.later.filter(function (x) { return x !== aid; });
  save();
  toast('Atividade excluída.');
};
A.surprise = function () {
  var list = filteredActs(S.data, actFilters()), prev = (S.modal && S.modal.t === 'surprise') ? S.modal.id : null;
  if (!list.length) { toast('Nenhuma atividade com esses filtros para sortear.'); return; }
  var pool = list.length > 1 ? list.filter(function (a) { return a.id !== prev; }) : list;
  openModal({ t: 'surprise', id: pool[Math.floor(Math.random() * pool.length)].id });
};
A.actTab = function (el) { var f = actFilters(); f.tab = dv(el); f.n = 10; };
A.filter = function (el) {
  var f = actFilters();
  f[dk(el)] = dv(el);
  f.n = 10;
  announce(plural(filteredActs(S.data, f).length, 'atividade encontrada', 'atividades encontradas') + '.');
};
A.moreFilters = function () { var f = actFilters(); f.more = !f.more; if (!f.more) { f.place = ''; f.energy = ''; } };
A.clearFilters = function () { var f = actFilters(); f.kind = ''; f.dur = ''; f.place = ''; f.energy = ''; f.n = 10; };
A.moreActs = function () { actFilters().n += 10; };
A.newAct = function () { openModal({ t: 'newAct', kind: actFilters().kind || 'estudo' }); };
A.naKind = function (el) { S.modal.kind = dv(el); };
FORMS.newAct = function () {
  var d = S.data, m = S.modal, title = str(val('na-title'), 80), min = intVal('na-min');
  if (!title) { m.err = 'Escreva o que você vai fazer.'; S.focusField = 'na-title'; return; }
  if (min == null || isNaN(min) || min < 1 || min > 240) { m.err = 'A duração vai de 1 a 240 minutos.'; S.focusField = 'na-min'; return; }
  if (d.custom.length >= 200) { m.err = 'Limite de 200 atividades próprias.'; return; }
  d.custom.push({ id: uid(), kind: m.kind === 'exercicio' ? 'exercicio' : 'estudo', title: title, min: min, place: oneOf(val('na-place'), ['c', 'f', 'q', 'l'], 'q'), energy: oneOf(val('na-energy'), ['t', 'm', 'a'], 't') });
  save();
  closeModal();
  var f = actFilters(); f.tab = 'mine'; f.kind = ''; f.dur = ''; f.place = ''; f.energy = '';
  toast('Atividade criada.');
};

/* temporizador */
A.tKind = function (el) {
  var f = tform(), x = dv(el);
  if (f.kind === x) return;
  f.kind = x; f.actId = null; f.title = ''; f.idea = ''; f.custom = false;
  f.min = x === 'estudo' ? 25 : (x === 'exercicio' ? 10 : 5);
};
A.pickAct = function () { var f = tform(); openModal({ t: 'pickAct', kind: f.kind === 'exercicio' ? 'exercicio' : 'estudo' }); };
A.clearAct = function () { var f = tform(); f.actId = null; f.title = ''; };
A.choosePick = function (el) {
  var a = actById(S.data, dv(el)), f = tform();
  closeModal();
  if (!a) return;
  f.actId = a.id; f.title = a.title; f.min = a.min; f.custom = [5, 10, 25, 50].indexOf(a.min) < 0; f.cyc = false;
  f.subject = a.subject || ''; f.sport = a.sport || '';
};
A.tSubject = function (el) { var f = tform(); f.subject = dv(el); if (f.actId) { f.actId = null; f.title = ''; } };
A.tSport = function (el) { var f = tform(); f.sport = dv(el); if (f.actId) { f.actId = null; f.title = ''; } };
A.tIdea = function (el) { tform().idea = dv(el); };
A.tMin = function (el) { var f = tform(), x = dv(el); if (x === 'x') f.custom = true; else { f.custom = false; f.min = parseInt(x, 10); } };
CHANGES.tMinInput = function (el) { var n = parseInt(el.value, 10); if (isNaN(n)) return false; tform().min = clamp(n, 1, 180); };
A.tStart = function () {
  var d = S.data, f = tform();
  if (d.timer) { go('timer'); return; }
  var cfg = { kind: f.kind, title: f.title || (f.kind === 'pausa' ? f.idea : ''), subject: f.kind === 'estudo' ? f.subject : '', sport: f.kind === 'exercicio' ? f.sport : '', actId: f.actId, planId: f.planId || null, min: clamp(f.min || 5, 1, 180) };
  if (f.kind === 'estudo' && f.cyc) cfg.cycles = { focus: f.cf, rest: f.cr, total: f.cn };
  if (d.ui.mood) { openModal({ t: 'mood0', cfg: cfg }); return; }
  timerStart(cfg);
};
A.mood0 = function (el) {
  var cfg = S.modal && S.modal.cfg, n = parseInt(dv(el), 10);
  closeModal();
  if (!cfg || S.data.timer) return;
  cfg.mood0 = n >= 1 && n <= 5 ? n : null;
  timerStart(cfg);
};
A.mood1 = function (el) { S.tmp.mood1 = S.tmp.mood1 === dv(el) ? '' : dv(el); };
A.tPause = function () { timerPause(); announce('Temporizador pausado.'); };
A.tResume = function () { timerResume(); announce('Temporizador retomado.'); };
A.tStop = function () {
  var t = S.data.timer;
  if (!t || t.finished) return;
  var ms = t.doneFocusMs + ((!t.cyc || t.cyc.phase === 'foco') ? Math.max(0, t.phaseMs - timerRemain(t)) : 0);
  confirmBox('Encerrar agora?', 'Você fez ' + fmtMin(Math.round(ms / 60000)) + ' até aqui. Dá para registrar esse tempo na próxima tela.', 'Encerrar', 'tStopNow', null, false);
};
A.tStopNow = function () { timerStopEarly(); };
A.tSave = function () {
  var t = S.data.timer;
  if (!t || !t.finished) return;
  var rec = timerSave(t.finished.doneMin, S.tmp.mood1 ? parseInt(S.tmp.mood1, 10) : null);
  S.tmp.mood1 = ''; S.tmp.tf = null;
  go('home');
  toast(rec ? 'Registrado: ' + fmtMin(rec.min) + ' de ' + KIND_LABEL[rec.kind].toLowerCase() + '.' : 'Nada para registrar.');
};
A.tDiscard = function () { timerDiscard(); S.tmp.mood1 = ''; S.tmp.tf = null; };

/* histórico */
A.weekPrev = function () { S.tmp.hw = addDays(S.tmp.hw || weekStart(dayKey()), -7); };
A.weekNext = function () { var cur = weekStart(dayKey()), nx = addDays(S.tmp.hw || cur, 7); S.tmp.hw = nx > cur ? cur : nx; };
A.delSession = function (el) {
  var id = dv(el), s = null;
  S.data.sessions.forEach(function (x) { if (x.id === id) s = x; });
  if (s) confirmBox('Excluir esta sessão?', (s.title || KIND_LABEL[s.kind]) + ', ' + fmtMin(s.min) + ' em ' + fmtDay(s.day) + '.', 'Excluir sessão', 'delSessionNow', id, true);
};
A.delSessionNow = function (el) { var id = dv(el); S.data.sessions = S.data.sessions.filter(function (x) { return x.id !== id; }); save(); toast('Sessão excluída.'); };
A.askClearHistory = function () { confirmBox('Apagar todo o histórico?', 'Todas as sessões e todos os tempos de tela informados serão apagados. Preferências e metas continuam. Não tem volta.', 'Apagar histórico', 'clearHistoryNow', null, true); };
A.clearHistoryNow = function () { var d = S.data; d.sessions = []; d.usage = {}; save(); toast('Histórico apagado.'); };
A.askClearAll = function () { confirmBox('Apagar todos os dados?', 'Preferências, metas, lembretes e histórico deste perfil serão apagados deste aparelho. Não tem volta.', 'Apagar tudo', 'clearAllNow', null, true); };
A.clearAllNow = function () {
  wakeOff();
  if (S.user.id === 'guest') {
    lsDel(keyData('guest'));
    signOut();
    S.tmp = {};
    enter('welcome');
  } else {
    var ui = S.data.ui;
    S.data = newData();
    S.data.ui = ui;
    S.data.onboarded = true;
    S.tmp = {};
    save();
    enter('home');
  }
  toast('Dados apagados deste aparelho.');
};

/* lembretes */
A.remToggle = function (el) {
  var d = S.data, id = dv(el);
  d.rem.list.forEach(function (r) { if (r.id === id) { r.on = !r.on; if (r.on) markTodayIfPast(d, r); } });
  save();
};
A.editRem = function (el) {
  var id = dv(el);
  S.data.rem.list.forEach(function (r) { if (r.id === id) openModal({ t: 'rem', id: r.id, kind: r.kind, label: r.label, time: r.time, days: r.days.slice() }); });
};
A.addRem = function (el) { var kind = dv(el), p = REM_PRESET[kind] || REM_PRESET.outro; openModal({ t: 'rem', id: null, kind: kind, label: p[0], time: p[1], days: p[2].slice() }); };
A.remDay = function (el) { toggleIn(S.modal.days, parseInt(dv(el), 10)); };
A.delRem = function (el) { var id = dv(el), d = S.data; d.rem.list = d.rem.list.filter(function (r) { return r.id !== id; }); delete d.rem.snooze[id]; save(); closeModal(); toast('Lembrete excluído.'); };
FORMS.rem = function () {
  var d = S.data, m = S.modal, label = str(val('rm-label'), 60), time = hm(val('rm-time'), null), rec = null;
  if (!label) { m.err = 'Dê um nome ao lembrete.'; S.focusField = 'rm-label'; return; }
  if (!time) { m.err = 'Escolha um horário.'; S.focusField = 'rm-time'; return; }
  if (!m.days.length) { m.err = 'Marque pelo menos um dia da semana.'; return; }
  if (m.id) d.rem.list.forEach(function (r) { if (r.id === m.id) rec = r; });
  if (rec) { rec.label = label; rec.time = time; rec.days = m.days.slice().sort(); }
  else if (d.rem.list.length < 40) { rec = { id: uid(), label: label, kind: oneOf(m.kind, REM_KINDS, 'outro'), time: time, days: m.days.slice().sort(), on: true }; d.rem.list.push(rec); }
  if (rec) markTodayIfPast(d, rec);
  save();
  closeModal();
  toast('Lembrete salvo.');
};
A.alertSnooze = function () { var key = S.modal.a.key; S.data.rem.snooze[key] = now() + 600000; save(); closeModal(); toast('Lembrete adiado por 10 minutos.'); };
A.alertMute1h = function () { S.data.rem.pausedUntil = now() + 3600000; save(); closeModal(); toast('Lembretes em silêncio por 1 hora.'); };
A.alertGoStudy = function () { closeModal(); if (busyTimer()) return; S.tmp.tf = null; go('timer'); };
A.alertGoMove = function () { closeModal(); if (busyTimer()) return; S.tmp.tf = null; var f = tform(); f.kind = 'exercicio'; f.min = 10; go('timer'); };
A.alertPause = function () {
  closeModal();
  S.data.useSession = null;
  save();
  if (busyTimer()) return;
  timerStart({ kind: 'pausa', min: 5, title: '' });
  go('timer');
};
A.alertSnoozeUse = function () { var u = S.data.useSession; if (u) { u.snooze = now() + 600000; save(); } closeModal(); toast('Aviso adiado por 10 minutos.'); };
A.alertEndUse = function () { S.data.useSession = null; save(); closeModal(); };

/* plano e desafios */
A.planIdea = function (el) { var inp = document.getElementById('pl-text'); if (inp) { inp.value = dv(el); inp.focus(); } return false; };
A.planKind = function (el) { S.tmp.pl.kind = dv(el); };
A.planMin = function (el) { S.tmp.pl.min = parseInt(dv(el), 10); };
FORMS.plan = function () {
  var text = str(val('pl-text'), 160), p = S.tmp.pl || { min: 5, kind: 'pausa' };
  if (!text) { S.tmp.err = { msg: 'Escreva o que você vai fazer no lugar.' }; S.focusField = 'pl-text'; return; }
  S.data.plan = { text: text, min: p.min, kind: oneOf(p.kind, KINDS, 'pausa') };
  S.tmp.err = null;
  save();
  back();
  toast('Plano salvo.');
};
A.delPlan = function () { S.data.plan = null; S.drop['pl-text'] = true; save(); toast('Plano apagado.'); };
A.addChallenge = function (el) {
  var p = dv(el).split('|'), d = S.data, wk = weekStart(dayKey());
  if (d.challenges.filter(function (c) { return c.week === wk; }).length >= 4) return;
  d.challenges.push({ id: uid(), type: p[0], target: parseInt(p[1], 10), param: p[2] || null, week: wk });
  save();
  toast('Desafio iniciado. Ele é só seu.');
};
A.delChallenge = function (el) { var id = dv(el); S.data.challenges = S.data.challenges.filter(function (c) { return c.id !== id; }); save(); };
A.clearPastChallenges = function () { var wk = weekStart(dayKey()); S.data.challenges = S.data.challenges.filter(function (c) { return c.week >= wk; }); save(); };

/* aparência */
A.theme = function (el) { S.data.ui.theme = oneOf(dv(el), ['auto', 'light', 'dark'], 'auto'); save(); };
A.font = function (el) { S.data.ui.font = clamp(parseInt(dv(el), 10) || 0, 0, 2); save(); };
A.testSound = function () { primeAudio(); if (!chime()) toast(S.data.ui.sound ? 'Não foi possível tocar o som neste navegador.' : 'O som de aviso está desligado.'); buzz(); return false; };

/* dados: exportar, importar */
function exportPayload() {
  var copy = JSON.parse(JSON.stringify(S.data));
  copy.timer = null; copy.useSession = null;
  return JSON.stringify({ app: 'Foquinho', version: APP_VERSION, exportedAt: new Date().toISOString(), profile: (S.user && S.user.name) || null, demo: S.demo || undefined, data: copy }, null, 2);
}
function exportCsvText() {
  var d = S.data, keys = Object.keys(d.usage).concat(d.sessions.map(function (s) { return s.day; })).sort();
  var rows = ['data;dia;tela_min;tela_parcial;meta_min;dentro_da_meta;estudo_min;exercicio_min;pausa_min'];
  if (keys.length) {
    var k0 = keys[0], k1 = keys[keys.length - 1], guard = 0;
    for (var day = k0; day <= k1 && guard++ < 4000; day = addDays(day, 1)) {
      var s = dayStats(d, day);
      rows.push([day, WD_SHORT[wdIndex(day)], s.usage == null ? '' : s.usage, s.usage == null ? '' : (s.partial ? 'sim' : 'nao'), s.goal == null ? '' : s.goal, s.within == null ? '' : (s.within ? 'sim' : 'nao'), s.study, s.move, s.pause].join(';'));
    }
  }
  return '﻿' + rows.join('\r\n') + '\r\n';
}
function deliver(name, text) {
  if (!S.dl) { openModal({ t: 'exportText', name: name, text: text }); return; }
  S.dl.save({ filename: name, data: text }).then(function () { toast('Arquivo entregue para salvar: ' + name); }, function (e) {
    if (e && e.code === 'declined') { toast('Exportação cancelada.'); return; }
    openModal({ t: 'exportText', name: name, text: text });
    render();
  });
}
A.exportJson = function () { deliver('foquinho-dados-' + dayKey() + '.json', exportPayload()); };
A.exportCsv = function () { deliver('foquinho-historico-' + dayKey() + '.csv', exportCsvText()); };
A.copyExport = function () {
  var ta = document.getElementById('ex-text');
  if (!ta) return false;
  function fallback() {
    try { ta.focus(); ta.select(); var ok = document.execCommand && document.execCommand('copy'); toast(ok ? 'Copiado.' : 'Texto selecionado. Use o menu do aparelho para copiar.'); }
    catch (e) { toast('Texto selecionado. Use o menu do aparelho para copiar.'); }
  }
  try {
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(ta.value).then(function () { toast('Copiado.'); }, fallback);
    else fallback();
  } catch (e) { fallback(); }
  return false;
};
A.importOpen = function () { if (!S.demo) openModal({ t: 'importData' }); };
CHANGES.importFile = function (el) {
  var file = el.files && el.files[0];
  if (!file || !window.FileReader) return false;
  if (file.size > 5000000) { toast('Arquivo grande demais para ser uma cópia do Foquinho.'); return false; }
  var fr = new FileReader();
  fr.onload = function () { var ta = document.getElementById('im-text'); if (ta) ta.value = String(fr.result || ''); };
  fr.onerror = function () { toast('Não foi possível ler o arquivo.'); };
  fr.readAsText(file);
  return false;
};
FORMS.importData = function () {
  var m = S.modal, raw = String(val('im-text')).trim(), x;
  if (!raw) { m.err = 'Escolha um arquivo ou cole o conteúdo da cópia.'; return; }
  try { x = JSON.parse(raw); } catch (e) { m.err = 'O conteúdo não é um JSON válido.'; return; }
  if (!x || (x.app !== 'Foquinho' && x.app !== 'Pausa+') || !x.data || typeof x.data !== 'object') { m.err = 'Este arquivo não parece uma cópia exportada pelo Foquinho.'; return; }
  wakeOff();
  S.data = normalizeData(x.data);
  S.data.onboarded = true;
  S.data.timer = null;
  S.data.useSession = null;
  S.tmp = {};
  save();
  enter('home');
  toast('Cópia importada.');
};
