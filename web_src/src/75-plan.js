/* ---------- planejamento de estudos: telas e ações ---------- */
ROUTES.agenda = { tab: 'more', title: 'Mural de estudos', sub: true };
ROUTES.avail = { tab: 'more', title: 'Quando posso estudar', sub: true };

function monthStart(k) { return k.slice(0, 8) + '01'; }
function monthEnd(k) { var d = keyToDate(k); return dayKey(new Date(d.getFullYear(), d.getMonth() + 1, 0, 12)); }
var MONTHS = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
function ag() {
  if (!S.tmp.ag) S.tmp.ag = { mode: 'semana', start: weekStart(dayKey()), sel: dayKey(), left: null, pri: [] };
  return S.tmp.ag;
}
function agRange(a) { return a.mode === 'semana' ? { from: a.start, to: addDays(a.start, 6) } : { from: monthStart(a.start), to: monthEnd(a.start) }; }
function planRefreshConfigured(d) {
  var s = d.splan;
  s.configured = s.days.some(function (x) { return x.on && availMinutes(x) >= s.sessionMin; });
}

function psRow(p) {
  var st = p.state, icon = st === 'concluida' ? 'check' : (st === 'incompleta' ? 'clock' : (st === 'naoRealizada' ? 'x' : 'book'));
  var extra = (p.moved && st === 'planejada' ? ' · reagendada' : '') + (p.pinned ? ' · fixada' : '') + (p.manual ? ' · manual' : '');
  return '<li><button type="button" class="nav-row ps" id="ps-' + esc(p.id) + '" data-act="psOpen" data-v="' + esc(p.id) + '">' +
    '<span class="li-ic ' + (st === 'concluida' ? 'ok' : (st === 'naoRealizada' ? 'no' : 'estudo')) + '" aria-hidden="true">' + ic(icon) + '</span>' +
    '<span class="li-main"><span class="li-t">' + p.start + ' · ' + esc(psLabel(p)) + '</span>' +
    '<span class="li-d">' + p.minutes + ' min · ' + PLAN_STATE_LABEL[st] + extra + '</span></span>' + ic('right', 'sm') + '</button></li>';
}
function dayBlock(d, key, list) {
  var today = dayKey(), act = list.filter(psOccupies), mins = 0;
  act.forEach(function (p) { mins += p.minutes; });
  var head = WD_SHORT[wdIndex(key)] + ' ' + fmtDay(key) + (key === today ? ' · hoje' : '');
  var info = act.length ? plural(act.length, 'sessão', 'sessões') + ' · ' + fmtMin(mins) : (planDayAvailable(d.splan, key) ? 'sem sessões' : (d.splan.blocked.indexOf(key) >= 0 ? 'data bloqueada' : 'descanso'));
  return '<section class="card flush dayblock' + (key === today ? ' today' : '') + '"><h3 class="day-h"><span>' + esc(head) + '</span><span class="day-i">' + esc(info) + '</span></h3>' +
    d.prefs.exams.filter(function (e) { return e.date === key; }).map(function (e) {
      return '<p class="status near dayitem">' + ic('info', 'sm') + '<span>Prova ou trabalho neste dia: ' + esc(e.subject + (e.topic ? ' · ' + e.topic : '')) + '</span></p>';
    }).join('') +
    (list.length ? '<ul class="list pslist">' + list.map(psRow).join('') + '</ul>' : '') + '</section>';
}
/* Provas dos próximos 14 dias e sugestão de sessão antes de cada uma. */
function boardSuggestions(d) {
  var today = dayKey(), out = [];
  d.prefs.exams.slice().sort(function (a, b) { return a.date < b.date ? -1 : 1; }).forEach(function (e) {
    if (!isDayKey(e.date)) return;
    var left = diffDays(e.date, today);
    if (left < 0 || left > 14) return;
    var lastK = addDays(e.date, -1), wanted = Math.min(3, left);
    var planned = d.planSessions.filter(function (p) { return p.subject === e.subject && (p.state === 'planejada' || p.state === 'concluida') && p.day >= today && p.day <= lastK; }).length;
    var slot = null;
    if (planned < wanted && d.splan.configured) {
      var opts = planSuggestSlots(d, today, d.splan.sessionMin, new Date(), null, 14).filter(function (o) { return o.day <= lastK; });
      slot = opts.filter(function (o) { return !d.planSessions.some(function (p) { return p.day === o.day && p.subject === e.subject && psOccupies(p); }); })[0] || opts[0] || null;
    }
    out.push({ exam: e, left: left, planned: planned, wanted: wanted, slot: slot });
  });
  return out;
}
function comingCard(d) {
  var list = boardSuggestions(d);
  if (!list.length) return '';
  var h = '<section class="card" aria-labelledby="cm-t"><h2 id="cm-t">' + ic('info') + 'Chegando</h2><p class="muted">Provas e trabalhos que você cadastrou, nos próximos 14 dias.</p><ul class="list">';
  list.slice(0, 5).forEach(function (x, i) {
    var e = x.exam, quando = x.left === 0 ? 'hoje' : (x.left === 1 ? 'amanhã' : 'em ' + x.left + ' dias');
    h += '<li class="li"><div class="li-main"><p class="li-t">' + esc(e.subject + (e.topic ? ' · ' + e.topic : '')) + '</p><p class="li-d">' + quando + ' (' + WD_SHORT[wdIndex(e.date)] + ' ' + fmtDay(e.date) + ')' +
      (x.wanted ? ' · ' + x.planned + ' de ' + x.wanted + ' sessões sugeridas no mural' : '') + '</p>' +
      (x.planned < x.wanted ? '<div class="act-btns">' + (x.slot ? btn('Reservar ' + d.splan.sessionMin + ' min ' + WD_SHORT[wdIndex(x.slot.day)] + ' ' + fmtDay(x.slot.day) + ' às ' + hmFromMin(x.slot.startMin), 'boardAdd', { v: e.id, id: 'b-board-' + i, cls: 'small', icon: 'plus' })
        : '<span class="muted">Sem horário livre antes da data.</span>' + btn('Ver horários', 'nav', { v: 'avail', id: 'b-board-av-' + i, cls: 'small ghost' })) + '</div>' : '') + '</div></li>';
  });
  return h + '</ul></section>';
}
function planHomeCard(d) {
  if (!d.splan.configured || d.splan.paused) return '';
  var today = dayKey(), list = planSessionsBetween(d, today, today).filter(psOccupies), nx = planNext(d, now());
  if (!list.length && !nx) return '';
  var done = list.filter(function (p) { return p.state === 'concluida'; }).length;
  var h = '<section class="card" aria-labelledby="pl2-t"><div class="card-head"><h2 id="pl2-t">' + ic('cal') + 'Plano de hoje</h2>' + demoTag() + '</div>';
  h += list.length ? '<p>' + plural(list.length, 'sessão planejada', 'sessões planejadas') + ', ' + done + (done === 1 ? ' concluída' : ' concluídas') + '.</p>' : '<p>Nenhuma sessão planejada para hoje.</p>';
  if (nx) h += '<p class="muted">Próxima: ' + (nx.day === today ? 'hoje' : WD_SHORT[wdIndex(nx.day)] + ' ' + fmtDay(nx.day)) + ' às ' + nx.start + ' · ' + esc(psLabel(nx)) + ' (' + nx.minutes + ' min)</p>';
  return h + '<div class="row-btns">' + (nx && nx.day === today ? btn('Iniciar agora', 'psStart', { v: nx.id, cls: 'primary', id: 'b-home-ps-start' }) : '') + btn('Abrir planejamento', 'nav', { v: 'agenda', id: 'b-home-agenda' }) + '</div></section>';
}

SCREENS.agenda = function () {
  var d = S.data, a = ag(), today = dayKey(), h = '';
  if (!d.prefs.subjects.length) {
    return '<section class="card"><h2>' + ic('book') + 'Cadastre suas matérias primeiro</h2><p>O planejamento distribui as matérias que você informou. Sem elas não há o que organizar.</p>' +
      '<div class="row-btns">' + btn('Cadastrar matérias', 'goPrefs', { cls: 'primary', id: 'b-ag-prefs' }) + '</div></section>';
  }
  if (!d.splan.configured) {
    return '<section class="card"><h2>' + ic('clock') + 'Quando você pode estudar?</h2><p>Para montar o quadro, o Foquinho precisa saber em quais dias e horários você tem tempo livre. Ele nunca marca estudo fora deles.</p>' +
      '<div class="row-btns">' + btn('Informar dias e horários', 'nav', { v: 'avail', cls: 'primary', id: 'b-ag-avail' }) + '</div></section>';
  }
  var r = agRange(a), list = planSessionsBetween(d, r.from, r.to), pg = planProgress(list.filter(psOccupies)), nx = planNext(d, now());
  var todayList = planSessionsBetween(d, today, today).filter(psOccupies);

  h += '<section class="card" aria-labelledby="ag-t"><div class="card-head"><h2 id="ag-t">' + ic('cal') + 'Hoje</h2>' + demoTag() + '</div>' +
    '<p>' + (todayList.length ? plural(todayList.length, 'sessão planejada', 'sessões planejadas') + ' para hoje.' : 'Nenhuma sessão planejada para hoje.') + '</p>' +
    (nx ? '<p class="muted">Próxima sessão: ' + (nx.day === today ? 'hoje' : WD_SHORT[wdIndex(nx.day)] + ' ' + fmtDay(nx.day)) + ' às ' + nx.start + ' · ' + esc(psLabel(nx)) + ' (' + nx.minutes + ' min)</p>' +
      '<div class="row-btns">' + btn('Iniciar no temporizador', 'psStart', { v: nx.id, cls: 'primary small', id: 'b-ag-start' }) + '</div>' : '') +
    (pg.total ? '<p class="wk-l">Neste período: <strong>' + pg.done + ' de ' + pg.total + ' sessões concluídas</strong> (' + fmtMin(pg.doneMin) + ' de ' + fmtMin(pg.plannedMin) + ')</p>' +
      progress(pg.done * 100 / pg.total, pg.done + ' de ' + pg.total + ' sessões concluídas', 'estudo') : '') + '</section>';

  h += comingCard(d);
  if (d.splan.paused) h += '<p class="status near">' + ic('info', 'sm') + '<span>Plano pausado: as sessões continuam aqui, mas não aparecem no Início nem geram avisos.</span></p>';

  var missed = planMissed(d);
  if (missed.length) {
    h += '<section class="card soft" aria-labelledby="ms-t"><h2 id="ms-t">' + ic('clock') + 'Ficou para depois?</h2><p class="muted">' +
      (missed.length === 1 ? 'Uma sessão de dias anteriores ficou sem resultado.' : missed.length + ' sessões de dias anteriores ficaram sem resultado.') + ' Acontece. Escolha o que fazer com cada uma.</p><ul class="list">' +
      missed.slice(0, 5).map(function (p, i) {
        return '<li class="li"><div class="li-main"><p class="li-t">' + esc(psLabel(p)) + '</p><p class="li-d">' + WD_SHORT[wdIndex(p.day)] + ' ' + fmtDay(p.day) + ' às ' + p.start + ' · ' + p.minutes + ' min</p>' +
          '<div class="act-btns">' + btn('Reagendar', 'psMove', { v: p.id, id: 'ms-mv-' + i, cls: 'small' }) + btn('Remover', 'psRemove', { v: p.id, id: 'ms-rm-' + i, cls: 'small ghost' }) +
          btn('Deixar sem reposição', 'psSkip', { v: p.id, id: 'ms-sk-' + i, cls: 'small ghost' }) + '</div></div></li>';
      }).join('') + '</ul></section>';
  }
  if (d.splan.examSig != null && d.splan.examSig !== planExamSig(d) && d.planSessions.length) {
    h += '<section class="card soft"><h2>' + ic('info') + 'Suas provas mudaram</h2><p>Uma prova foi cadastrada ou alterada depois que o plano foi montado. Veja o que muda antes de aplicar.</p>' +
      '<div class="row-btns">' + btn('Ver mudanças no plano', 'agGen', { id: 'b-ag-exam' }) + '</div></section>';
  }
  if (a.left && a.left.length) {
    h += '<section class="card" aria-labelledby="lf-t"><h2 id="lf-t">' + ic('info') + 'Não coube tudo</h2><p class="muted">Com o tempo informado, o plano não conseguiu encaixar o mínimo destas matérias:</p><ul class="bul">' +
      a.left.map(function (l) { return '<li>' + esc(l.subject) + ': ' + l.placed + ' de ' + l.wanted + (l.beforeExam ? ' sessões antes da prova' : (l.wanted === 1 ? ' sessão' : ' sessões')) + '</li>'; }).join('') + '</ul>' +
      '<div class="chips"><p class="chips-label" id="g-agPri">O que priorizar?</p><div class="wrap" role="group" aria-labelledby="g-agPri">' +
      d.prefs.subjects.map(function (m) { return chip(m, 'agPri', m, a.pri.indexOf(m) >= 0); }).join('') + '</div></div>' +
      '<div class="row-btns">' + btn('Gerar de novo com prioridade', 'agGen', { id: 'b-ag-pri', dis: !a.pri.length }) + btn('Aumentar meu tempo livre', 'nav', { v: 'avail', cls: 'ghost', id: 'b-ag-avail2' }) + '</div></section>';
  }

  h += '<div class="seg" role="group" aria-label="Visualização">' + chip('Semana', 'agMode', 'semana', a.mode === 'semana', { cls: 'segb' }) + chip('Mês', 'agMode', 'mes', a.mode === 'mes', { cls: 'segb' }) + '</div>';
  var md = keyToDate(a.start), label = a.mode === 'semana' ? fmtDay(r.from) + ' a ' + fmtDay(r.to) : MONTHS[md.getMonth()] + ' de ' + md.getFullYear();
  h += '<div class="weeknav"><button type="button" class="icon-btn" id="b-ag-prev" data-act="agPrev" aria-label="Período anterior">' + ic('left') + '</button>' +
    '<p class="weeknav-t" id="ag-label">' + (a.mode === 'semana' ? 'Semana' : 'Mês') + '<span>' + esc(label) + '</span></p>' +
    '<button type="button" class="icon-btn" id="b-ag-next" data-act="agNext" aria-label="Próximo período">' + ic('right') + '</button></div>';

  var hasGenerated = list.some(function (p) { return !p.manual; });
  h += '<div class="row-btns">' + btn(hasGenerated ? 'Gerar de novo' : 'Montar plano', 'agGen', { cls: 'primary', id: 'b-ag-gen', dis: r.to < today }) +
    btn('Nova sessão', 'agNew', { icon: 'plus' }) + '</div>';
  if (r.to < today) h += '<p class="muted">Este período já passou. Não dá para montar plano para trás.</p>';

  if (a.mode === 'semana') {
    for (var i = 0; i < 7; i++) {
      var k = addDays(r.from, i);
      h += dayBlock(d, k, list.filter(function (p) { return p.day === k; }));
    }
  } else {
    var cells = '', lead = wdIndex(r.from), n = diffDays(r.to, r.from) + 1;
    for (var b = 0; b < lead; b++) cells += '<span class="mcell blank" aria-hidden="true"></span>';
    for (var j = 0; j < n; j++) {
      var mk = addDays(r.from, j), ml = list.filter(function (p) { return p.day === mk && psOccupies(p); }), md2 = ml.filter(function (p) { return p.state === 'concluida'; }).length;
      var aria = fmtDayLong(mk) + ': ' + (ml.length ? plural(ml.length, 'sessão', 'sessões') + ', ' + md2 + (md2 === 1 ? ' concluída' : ' concluídas') : (planDayAvailable(d.splan, mk) ? 'sem sessões' : 'descanso'));
      cells += '<button type="button" class="mcell' + (mk === a.sel ? ' sel' : '') + (mk === today ? ' today' : '') + (planDayAvailable(d.splan, mk) ? '' : ' off') + '" id="mc-' + mk + '" data-act="agSel" data-v="' + mk + '" aria-label="' + esc(aria) + '" aria-pressed="' + (mk === a.sel ? 'true' : 'false') + '">' +
        '<span class="mnum">' + (+mk.slice(8)) + '</span><span class="mcnt">' + (ml.length ? ml.length + (md2 === ml.length ? '✓' : '') : '') + '</span></button>';
    }
    h += '<div class="mgrid-h" aria-hidden="true">' + WD_SHORT.map(function (w) { return '<span>' + w + '</span>'; }).join('') + '</div><div class="mgrid">' + cells + '</div>' +
      '<p class="legend" aria-hidden="true"><span>número = sessões no dia</span><span>✓ = todas concluídas</span><span>cinza = descanso</span></p>';
    var selK = (a.sel >= r.from && a.sel <= r.to) ? a.sel : r.from;
    h += dayBlock(d, selK, list.filter(function (p) { return p.day === selK; }));
  }

  h += '<h2 class="sec">Opções do plano</h2><div class="stack">' +
    btn('Dias e horários livres', 'nav', { v: 'avail', cls: 'block left', icon: 'clock', id: 'b-ag-avail3' }) +
    btn(d.splan.paused ? 'Retomar o plano' : 'Pausar o plano', 'agPause', { cls: 'block left', icon: d.splan.paused ? 'play' : 'pause' }) +
    btn('Apagar o plano', 'agDelAsk', { cls: 'block left ghost', icon: 'trash', dis: !d.planSessions.length }) + '</div>' +
    notice('O plano fica guardado só neste aparelho, junto com os outros dados, e entra na exportação. O Foquinho organiza o tempo: não cria conteúdo, questões nem assuntos que você não informou.');
  return h;
};

SCREENS.avail = function () {
  var d = S.data, s = d.splan, h = '<p class="lead">Marque os dias e a faixa de horário em que você pode estudar. O plano usa no máximo 80% desse tempo, para sobrar folga.</p>';
  h += '<section class="card" aria-labelledby="av-d"><h2 id="av-d">' + ic('cal') + 'Dias e horários</h2>';
  for (var i = 0; i < 7; i++) {
    var a = s.days[i], nm = WD_LONG[i].charAt(0).toUpperCase() + WD_LONG[i].slice(1);
    h += switchRow('pd' + i, nm, a.on ? '' : 'Descanso', a.on);
    if (a.on) {
      h += '<div class="two">' +
        '<div class="field time"><label for="pd' + i + '-f">Das</label><input class="input" type="time" id="pd' + i + '-f" value="' + a.from + '" data-change="pTime" data-k="' + i + '|from"></div>' +
        '<div class="field time"><label for="pd' + i + '-t">Até</label><input class="input" type="time" id="pd' + i + '-t" value="' + a.to + '" data-change="pTime" data-k="' + i + '|to"></div></div>';
      if (availMinutes(a) < s.sessionMin) h += '<p class="status near">' + ic('info', 'sm') + '<span>Essa faixa é menor que uma sessão de ' + s.sessionMin + ' min. Aumente o horário final.</span></p>';
    }
  }
  h += '</section>';
  h += '<section class="card" aria-labelledby="av-l"><h2 id="av-l">' + ic('target') + 'Limites</h2>' +
    setting('pmax', 'Máximo de estudo por dia', '', stepper('pmax', fmtMin(s.dailyMaxMin), 'máximo de estudo por dia')) +
    chipRow('Duração de cada sessão', [['25', '25 min'], ['40', '40 min'], ['50', '50 min']], 'pSess', String(s.sessionMin)) +
    setting('pgap', 'Intervalo entre sessões', '', stepper('pgap', s.gapMin + ' min', 'intervalo entre sessões')) + '</section>';
  h += '<section class="card" aria-labelledby="av-b"><h2 id="av-b">' + ic('x') + 'Datas sem estudo</h2><p class="muted">Feriado, viagem, compromisso: nessas datas o plano não marca nada.</p>' +
    (s.blocked.length ? '<ul class="list">' + s.blocked.slice().sort().map(function (k, i) {
      return '<li class="li"><div class="li-main"><p class="li-t">' + esc(fmtDayLong(k)) + '/' + k.slice(0, 4) + '</p></div><button type="button" class="icon-btn" id="pb-del-' + i + '" data-act="pUnblock" data-v="' + k + '" aria-label="Liberar ' + esc(fmtDayLong(k)) + '">' + ic('trash') + '</button></li>';
    }).join('') + '</ul>' : '<p class="empty">Nenhuma data bloqueada.</p>') +
    '<form class="addline" data-form="pBlock" novalidate><div class="field grow"><label for="pb-date">Bloquear uma data</label><input class="input" type="date" id="pb-date" name="pb-date" data-keep></div>' +
    btn('Bloquear', '', { submit: true, id: 'b-pb-add' }) + '</form></section>';
  h += s.configured ? '<p class="status">' + ic('check', 'sm') + '<span>Pronto. Já dá para montar o plano.</span></p>' : '<p class="status near">' + ic('info', 'sm') + '<span>Ligue pelo menos um dia com uma faixa de horário que caiba uma sessão.</span></p>';
  h += btn('Abrir o planejamento', 'nav', { v: 'agenda', cls: 'primary block', id: 'b-av-done', dis: !s.configured });
  if (d.planSessions.length) h += notice('Mudar a disponibilidade não mexe nas sessões já marcadas. Para aplicar, use “Gerar de novo” no planejamento.');
  return h;
};

/* ---------- janelas ---------- */
MODALS.planPreview = function (m) {
  var d = S.data, res = S.tmp.agRes, a = ag(), r = agRange(a);
  if (!res) return { title: 'Plano', body: '<p>Nada para mostrar.</p>' };
  var keptIds = {};
  res.kept.forEach(function (p) { keptIds[p.id] = 1; });
  var removed = planSessionsBetween(d, r.from, r.to).filter(function (p) { return !keptIds[p.id]; });
  var body = '<div class="stack">';
  if (!res.slots && !res.sessions.length) {
    body += '<p>Não há horários livres neste período. Confira os dias e horários informados, o limite diário e as datas bloqueadas.</p>' +
      btn('Ajustar dias e horários', 'nav', { v: 'avail', cls: 'primary block', id: 'b-pv-avail' }) + btn('Fechar', 'closeModal', { cls: 'ghost block', id: 'b-cancel' });
    return { title: 'Sem horários livres', body: body + '</div>' };
  }
  body += '<ul class="bul"><li><strong>' + plural(res.sessions.length, 'sessão nova', 'sessões novas') + '</strong> de ' + d.splan.sessionMin + ' min</li>' +
    '<li>' + plural(res.kept.length, 'sessão preservada', 'sessões preservadas') + ' (concluídas, fixadas, manuais ou de dias que já passaram)</li>' +
    '<li>' + plural(removed.length, 'sessão será substituída', 'sessões serão substituídas') + '</li></ul>';
  if (removed.length) {
    body += '<p class="chips-label">Serão substituídas</p><ul class="list">' + removed.slice(0, 6).map(function (p) {
      return '<li class="li"><div class="li-main"><p class="li-t">' + esc(psLabel(p)) + '</p><p class="li-d">' + WD_SHORT[wdIndex(p.day)] + ' ' + fmtDay(p.day) + ' às ' + p.start + '</p></div></li>';
    }).join('') + '</ul>' + (removed.length > 6 ? '<p class="muted">e mais ' + (removed.length - 6) + '.</p>' : '');
  }
  if (res.leftovers.length) body += notice('Não coube o mínimo de: ' + res.leftovers.map(function (l) { return esc(l.subject); }).join(', ') + '. Depois de aplicar, você escolhe o que priorizar.', 'warn');
  body += btn('Aplicar', 'agApply', { cls: 'primary block' }) + btn('Cancelar', 'closeModal', { cls: 'ghost block', id: 'b-cancel' }) + '</div>';
  return { title: 'Prévia do plano', body: body };
};
MODALS.psess = function (m) {
  var d = S.data, p = planById(d, m.id);
  if (!p) return { title: 'Sessão', body: '<p>Esta sessão não existe mais.</p>' };
  var st = p.state, bt = function (label, v, cls, icon) { return btn(label, 'psDo', { v: v, cls: (cls || '') + ' block left', icon: icon, id: 'b-ps-' + v }); };
  var body = '<div class="stack"><p><strong>' + esc(fmtDayLong(p.day)) + ' às ' + p.start + '</strong> · ' + p.minutes + ' min</p>' +
    '<p class="tags">' + tag(PLAN_STATE_LABEL[st], st === 'concluida' ? 'ok' : (st === 'naoRealizada' ? 'off' : '')) + (p.moved ? tag('reagendada') : '') + (p.pinned ? tag('fixada') : '') + (p.manual ? tag('manual') : '') + '</p>';
  if (st !== 'concluida') body += bt('Iniciar no temporizador', 'start', 'primary', 'play') + bt('Marcar como concluída', 'done', '', 'check');
  if (st === 'planejada') body += bt('Fiz só uma parte', 'incomplete', '', 'clock') + bt('Não fiz', 'missed', '', 'x');
  if (st !== 'planejada') body += bt('Voltar para planejada', 'planned', '', 'left');
  if (st !== 'concluida') body += bt('Mover para outro dia ou horário', 'move', '', 'cal');
  body += bt(p.pinned ? 'Desafixar' : 'Fixar (não muda ao gerar de novo)', 'pin', '', 'lock') + bt('Editar', 'edit', '', 'edit') + bt('Excluir', 'del', 'ghost', 'trash') + '</div>';
  return { title: psLabel(p), body: body };
};
MODALS.psDone = function (m) {
  var p = planById(S.data, m.id);
  if (!p) return { title: 'Sessão', body: '<p>Esta sessão não existe mais.</p>' };
  return {
    title: 'Sessão concluída',
    body: '<div class="stack"><p>Quer registrar ' + p.minutes + ' min de estudo de ' + esc(p.subject) + ' no histórico? O registro também conta para a sua sequência de dias.</p>' +
      btn('Registrar ' + p.minutes + ' min', 'psDoneRec', { cls: 'primary block' }) + btn('Só marcar como concluída', 'psDoneOnly', { cls: 'block' }) + btn('Cancelar', 'closeModal', { cls: 'ghost block', id: 'b-cancel' }) + '</div>'
  };
};
MODALS.psMissed = function (m) {
  return {
    title: 'Tudo bem',
    body: '<div class="stack"><p>A sessão ficou como não realizada e o horário foi liberado. Quer repor em outro momento?</p>' +
      btn('Reagendar', 'psMove', { v: m.id, cls: 'primary block', id: 'b-psm-move' }) + btn('Remover do plano', 'psRemove', { v: m.id, cls: 'block', id: 'b-psm-rm' }) +
      btn('Deixar sem reposição', 'closeModal', { cls: 'ghost block', id: 'b-psm-keep' }) + '</div>'
  };
};
MODALS.pedit = function (m) {
  var d = S.data, p = m.id ? planById(d, m.id) : null, mover = m.mode === 'mover';
  if (m.id && !p) return { title: 'Sessão', body: '<p>Esta sessão não existe mais.</p>' };
  var body = '<form data-form="pedit" novalidate class="stack">';
  if (mover) body += '<p><strong>' + esc(psLabel(p)) + '</strong> · ' + p.minutes + ' min. A matéria e o assunto continuam os mesmos.</p>';
  else {
    body += selectField('pe-subj', 'Matéria', d.prefs.subjects.map(function (x) { return [x, x]; }), p ? p.subject : d.prefs.subjects[0]) +
      field('pe-topic', 'Assunto (opcional)', { max: 80, value: p && p.topic ? p.topic : '', ac: 'off' });
  }
  body += field('pe-day', 'Data', { type: 'date', value: p ? p.day : (m.day || dayKey()) }) +
    '<div class="field time"><label for="pe-start">Horário de início</label><input class="input" type="time" id="pe-start" name="pe-start" value="' + (p ? p.start : (m.start || '18:00')) + '" data-keep></div>';
  if (!mover) body += field('pe-min', 'Duração em minutos', { type: 'number', mode: 'numeric', min: 5, maxv: 240, value: p ? p.minutes : d.splan.sessionMin });
  body += errBox(m.err);
  if (m.alts && m.alts.length) {
    body += '<p class="chips-label">Horários livres próximos</p>' + m.alts.map(function (o, i) {
      return btn(WD_SHORT[wdIndex(o.day)] + ' ' + fmtDay(o.day) + ' às ' + hmFromMin(o.startMin), 'pAlt', { v: String(i), cls: 'block left', icon: 'cal', id: 'b-palt-' + i });
    }).join('');
  } else if (m.err && m.alts) body += '<p class="muted">Não encontrei horário livre nas próximas quatro semanas.</p>';
  if (m.canForce) body += btn('Usar o horário que escolhi mesmo assim', 'pForce', { cls: 'ghost block' });
  body += btn(mover ? 'Mover sessão' : (p ? 'Salvar' : 'Criar sessão'), '', { submit: true, cls: 'primary block', id: 'b-pe-save' }) + '</form>';
  return { title: mover ? 'Mover sessão' : (p ? 'Editar sessão' : 'Nova sessão'), body: body };
};

/* ---------- ações ---------- */
A.agMode = function (el) {
  var a = ag(), v = dv(el);
  if (a.mode === v) return;
  a.mode = v;
  a.start = v === 'semana' ? weekStart(a.sel || dayKey()) : monthStart(a.start);
};
A.agPrev = function () {
  var a = ag();
  if (a.mode === 'semana') a.start = addDays(a.start, -7);
  else { var d = keyToDate(monthStart(a.start)); a.start = dayKey(new Date(d.getFullYear(), d.getMonth() - 1, 1, 12)); }
  a.sel = a.start;
};
A.agNext = function () {
  var a = ag();
  if (a.mode === 'semana') a.start = addDays(a.start, 7);
  else { var d = keyToDate(monthStart(a.start)); a.start = dayKey(new Date(d.getFullYear(), d.getMonth() + 1, 1, 12)); }
  a.sel = a.start;
};
A.agSel = function (el) { ag().sel = dv(el); };
A.agPri = function (el) { toggleIn(ag().pri, dv(el)); };
A.agGen = function () {
  var a = ag(), r = agRange(a);
  S.tmp.agRes = generatePlan(S.data, r.from, r.to, new Date(), a.pri);
  openModal({ t: 'planPreview' });
};
A.agApply = function () {
  var d = S.data, a = ag(), r = agRange(a), res = S.tmp.agRes;
  if (!res) { closeModal(); return; }
  applyPlan(d, r.from, r.to, res);
  a.left = res.leftovers;
  a.pri = [];
  S.tmp.agRes = null;
  save();
  closeModal();
  toast(res.sessions.length ? 'Plano montado: ' + plural(res.sessions.length, 'sessão nova', 'sessões novas') + '.' : 'Nenhuma sessão nova coube neste período.');
};
A.agNew = function () { var a = ag(), t = dayKey(); openModal({ t: 'pedit', id: null, mode: 'nova', day: a.sel >= t ? a.sel : t }); };
A.agPause = function () { var s = S.data.splan; s.paused = !s.paused; save(); toast(s.paused ? 'Plano pausado.' : 'Plano retomado.'); };
A.agDelAsk = function () { confirmBox('Apagar o plano?', 'Todas as sessões planejadas serão apagadas. O histórico do que você já registrou continua. Não tem volta.', 'Apagar o plano', 'agDelNow', null, true); };
A.agDelNow = function () { var d = S.data; d.planSessions = []; d.splan.examSig = null; ag().left = null; save(); toast('Plano apagado.'); };
A.alertGoAgenda = function () { closeModal(); go('agenda'); };

A.psOpen = function (el) { openModal({ t: 'psess', id: dv(el) }); };
function psStartTimer(p) {
  if (!p || busyTimer()) return;
  S.tmp.tf = null;
  var f = tform();
  f.kind = 'estudo'; f.subject = p.subject; f.title = 'Estudar ' + psLabel(p);
  f.min = clamp(p.minutes, 1, 180); f.custom = [5, 10, 25, 50].indexOf(f.min) < 0; f.planId = p.id;
  go('timer');
}
A.psStart = function (el) { psStartTimer(planById(S.data, dv(el))); };
A.psDo = function (el) {
  var d = S.data, m = S.modal, p = m ? planById(d, m.id) : null, v = dv(el);
  if (!p) { closeModal(); return; }
  if (v === 'start') { closeModal(); psStartTimer(p); return; }
  if (v === 'done') { openModal({ t: 'psDone', id: p.id }); return; }
  if (v === 'move') { openModal({ t: 'pedit', id: p.id, mode: 'mover' }); return; }
  if (v === 'edit') { openModal({ t: 'pedit', id: p.id, mode: 'editar' }); return; }
  if (v === 'missed') { p.state = 'naoRealizada'; save(); openModal({ t: 'psMissed', id: p.id }); return; }
  if (v === 'incomplete') { p.state = 'incompleta'; toast('Marcada como incompleta. O que foi feito já vale.'); }
  else if (v === 'planned') p.state = 'planejada';
  else if (v === 'pin') { p.pinned = !p.pinned; toast(p.pinned ? 'Sessão fixada.' : 'Sessão desafixada.'); }
  else if (v === 'del') { d.planSessions = d.planSessions.filter(function (x) { return x.id !== p.id; }); toast('Sessão excluída.'); }
  save();
  closeModal();
};
A.psDoneRec = function () {
  var d = S.data, p = S.modal ? planById(d, S.modal.id) : null;
  if (p) {
    p.state = 'concluida';
    d.sessions.push({ id: uid(), kind: 'estudo', title: 'Estudar ' + psLabel(p), subject: p.subject, sport: null, actId: null, plan: p.minutes, min: p.minutes, start: now(), end: now(), day: dayKey(), m0: null, m1: null });
    save();
    toast('Registrado: ' + fmtMin(p.minutes) + ' de estudo.');
  }
  closeModal();
};
A.psDoneOnly = function () { var p = S.modal ? planById(S.data, S.modal.id) : null; if (p) { p.state = 'concluida'; save(); } closeModal(); };
A.psMove = function (el) { openModal({ t: 'pedit', id: dv(el), mode: 'mover' }); };
A.psRemove = function (el) { var id = dv(el), d = S.data; d.planSessions = d.planSessions.filter(function (x) { return x.id !== id; }); save(); if (S.modal) closeModal(); toast('Sessão removida do plano.'); };
A.psSkip = function (el) { var p = planById(S.data, dv(el)); if (p) { p.state = 'naoRealizada'; save(); } };

function pCommit(m, c) {
  var d = S.data, p = m.id ? planById(d, m.id) : null;
  if (p) {
    var changed = p.day !== c.day || psStart(p) !== c.startMin;
    p.day = c.day; p.start = hmFromMin(c.startMin);
    if (m.mode !== 'mover') { p.subject = c.subject; p.topic = c.topic || null; p.minutes = c.minutes; p.manual = true; }
    if (changed) { p.moved = true; if (p.state !== 'concluida') p.state = 'planejada'; }
  } else {
    d.planSessions.push({ id: 'm' + uid(), subject: c.subject, topic: c.topic || null, day: c.day, start: hmFromMin(c.startMin), minutes: c.minutes, state: 'planejada', pinned: false, manual: true, moved: false });
  }
  ag().sel = c.day;
  save();
  closeModal();
  toast(m.mode === 'mover' ? 'Sessão movida para ' + fmtDay(c.day) + ' às ' + hmFromMin(c.startMin) + '.' : 'Sessão salva.');
}
FORMS.pedit = function () {
  var d = S.data, m = S.modal, p = m.id ? planById(d, m.id) : null, mover = m.mode === 'mover';
  var day = val('pe-day'), startMin = hmToMin(val('pe-start')), minutes = mover ? p.minutes : intVal('pe-min');
  var subject = mover ? p.subject : str(val('pe-subj'), 40), topic = mover ? p.topic : str(val('pe-topic'), 80);
  m.alts = null; m.canForce = false; m.err = null;
  if (!isDayKey(day)) { m.err = 'Escolha a data.'; return; }
  if (startMin == null) { m.err = 'Escolha o horário de início.'; return; }
  if (minutes == null || isNaN(minutes) || minutes < 5 || minutes > 240) { m.err = 'A duração vai de 5 a 240 minutos.'; return; }
  if (d.prefs.subjects.indexOf(subject) < 0) { m.err = 'Escolha a matéria.'; return; }
  if (day < dayKey()) { m.err = 'Essa data já passou. Escolha hoje ou um dia à frente.'; return; }
  var c = { subject: subject, topic: topic, day: day, startMin: startMin, minutes: minutes }, chk = planCheckSlot(d, day, startMin, minutes, m.id);
  m.cand = c;
  if (!chk.ok) {
    var why = [];
    if (chk.overlap) why.push('bate com outra sessão');
    if (chk.overLimit) why.push('passa do seu limite de ' + fmtMin(d.splan.dailyMaxMin) + ' por dia');
    if (chk.unavailable) why.push('fica fora dos dias e horários que você marcou como livres');
    m.err = 'Esse horário ' + why.join(' e ') + '.';
    m.alts = planSuggestSlots(d, day, minutes, new Date(), m.id, 4).filter(function (o) { return !(p && o.day === p.day && o.startMin === psStart(p)); }).slice(0, 3);
    m.canForce = !chk.overlap;
    return;
  }
  pCommit(m, c);
};
A.pAlt = function (el) {
  var m = S.modal, o = m && m.alts ? m.alts[parseInt(dv(el), 10)] : null;
  if (!o || !m.cand) return;
  m.cand.day = o.day; m.cand.startMin = o.startMin;
  pCommit(m, m.cand);
};
A.pForce = function () { var m = S.modal; if (m && m.cand) pCommit(m, m.cand); };

/* disponibilidade */
(function () {
  function mk(i) { return function (d) { d.splan.days[i].on = !d.splan.days[i].on; planRefreshConfigured(d); }; }
  for (var i = 0; i < 7; i++) TOG['pd' + i] = mk(i);
  STEPS.pmax = { get: function (d) { return d.splan.dailyMaxMin; }, set: function (d, x) { d.splan.dailyMaxMin = x; }, min: 15, max: 600, step: 15 };
  STEPS.pgap = { get: function (d) { return d.splan.gapMin; }, set: function (d, x) { d.splan.gapMin = x; }, min: 0, max: 60, step: 5 };
})();
CHANGES.pTime = function (el) {
  var d = S.data, k = dk(el).split('|'), t = hm(el.value, null);
  if (!t) return false;
  d.splan.days[+k[0]][k[1]] = t;
  planRefreshConfigured(d);
  save();
};
A.pSess = function (el) { var d = S.data; d.splan.sessionMin = parseInt(dv(el), 10); planRefreshConfigured(d); save(); };
FORMS.pBlock = function () {
  var d = S.data, k = val('pb-date');
  if (!isDayKey(k)) { toast('Escolha uma data.'); return false; }
  if (d.splan.blocked.indexOf(k) < 0) d.splan.blocked.push(k);
  S.drop['pb-date'] = true;
  save();
};
A.pUnblock = function (el) { var d = S.data, k = dv(el); d.splan.blocked = d.splan.blocked.filter(function (x) { return x !== k; }); save(); };
A.alertPsStart = function () { var a = S.modal && S.modal.a, p = a ? planById(S.data, a.planId) : null; closeModal(); psStartTimer(p); };
A.boardAdd = function (el) {
  var d = S.data, id = dv(el), x = boardSuggestions(d).filter(function (y) { return y.exam.id === id; })[0];
  if (!x || !x.slot) return;
  d.planSessions.push({ id: 'm' + uid(), subject: x.exam.subject, topic: x.exam.topic || null, day: x.slot.day, start: hmFromMin(x.slot.startMin), minutes: d.splan.sessionMin, state: 'planejada', pinned: false, manual: true, moved: false });
  save();
  toast('Sessão reservada no mural.');
};
