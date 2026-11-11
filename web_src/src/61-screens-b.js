/* ---------- telas: atividades, temporizador e histórico ---------- */
function actFilters() {
  if (!S.tmp.af) S.tmp.af = { tab: 'sug', kind: '', dur: '', place: '', energy: '', more: false, n: 10 };
  return S.tmp.af;
}
function filteredActs(d, f) {
  var all = buildActivities(d), base = all;
  if (f.tab === 'fav') base = all.filter(function (a) { return d.fav.indexOf(a.id) >= 0; });
  else if (f.tab === 'later') base = all.filter(function (a) { return d.later.indexOf(a.id) >= 0; });
  else if (f.tab === 'mine') base = all.filter(function (a) { return a.custom; });
  return rankActs(filterActs(base, { kind: f.kind || null, dur: f.dur ? +f.dur : null, place: f.place || null, energy: f.energy || null }), d);
}
SCREENS.acts = function () {
  var d = S.data, f = actFilters(), list = filteredActs(d, f);
  var nAct = (f.kind ? 1 : 0) + (f.dur ? 1 : 0) + (f.place ? 1 : 0) + (f.energy ? 1 : 0);
  var h = btn('Surpreenda-me', 'surprise', { cls: 'primary block', icon: 'dice' }) +
    '<div class="seg" role="group" aria-label="Listas de atividades">' +
    [['sug', 'Sugestões'], ['fav', 'Favoritas'], ['later', 'Depois'], ['mine', 'Minhas']].map(function (t) { return chip(t[1], 'actTab', t[0], f.tab === t[0], { cls: 'segb' }); }).join('') + '</div>' +
    '<section class="filters" aria-label="Filtros">' +
    chipRow('Tipo', [['', 'Tudo'], ['estudo', 'Estudo'], ['exercicio', 'Exercício']], 'filter', f.kind, 'kind') +
    chipRow('Tempo disponível', [['', 'Qualquer'], ['5', '5 min'], ['10', '10 min'], ['20', '20 min'], ['30', '30 min']], 'filter', f.dur, 'dur') +
    (f.more ?
      chipRow('Local', [['', 'Todos'], ['c', 'Em casa'], ['f', 'Ao ar livre'], ['q', 'Em qualquer lugar']], 'filter', f.place, 'place') +
      chipRow('Energia', [['', 'Todas'], ['t', 'Tranquilo'], ['m', 'Moderado'], ['a', 'Ativo']], 'filter', f.energy, 'energy') : '') +
    '<div class="row-btns">' + btn(f.more ? 'Menos filtros' : 'Mais filtros: local e energia', 'moreFilters', { cls: 'small ghost', icon: 'gear', pressed: f.more }) +
    (nAct ? btn('Limpar filtros', 'clearFilters', { cls: 'small ghost', icon: 'x' }) : '') + '</div></section>';

  h += '<p class="count">' + plural(list.length, 'atividade', 'atividades') + (nAct ? ' com ' + plural(nAct, 'filtro', 'filtros') : '') + '</p>';
  if (!list.length) {
    var msg = 'Nenhuma atividade com esses filtros.';
    if (!nAct && f.tab === 'fav') msg = 'Nenhuma favorita ainda. Toque em Favoritar em qualquer atividade.';
    if (!nAct && f.tab === 'later') msg = 'A lista “quero fazer depois” está vazia. Toque em Depois para guardar uma atividade.';
    if (!nAct && f.tab === 'mine') msg = 'Você ainda não criou atividades próprias.';
    h += '<p class="empty">' + msg + '</p>';
  } else {
    h += '<div class="acts">' + list.slice(0, f.n).map(function (a) { return actCard(a, { del: true }); }).join('') + '</div>';
    if (list.length > f.n) h += btn('Mostrar mais', 'moreActs', { cls: 'block' });
  }
  h += '<div class="row-btns">' + btn('Criar atividade', 'newAct', { icon: 'plus' }) + '</div>';
  if (!d.prefs.subjects.length && !d.prefs.sports.length) h += notice('As sugestões ficam mais pessoais quando você informa suas matérias e esportes. ' + link('Abrir preferências', 'goPrefs'));
  return h;
};

/* ---------- temporizador ---------- */
var MOODS = [[1, 'Muito mal'], [2, 'Mal'], [3, 'Mais ou menos'], [4, 'Bem'], [5, 'Muito bem']];
function moodLabel(n) { for (var i = 0; i < MOODS.length; i++) if (MOODS[i][0] === n) return MOODS[i][1]; return ''; }
function tform() {
  if (!S.tmp.tf) S.tmp.tf = { kind: 'estudo', min: 25, custom: false, subject: '', sport: '', idea: '', actId: null, title: '', cyc: false, cf: 25, cr: 5, cn: 4 };
  return S.tmp.tf;
}
function timerTitle(t) {
  if (t.title) return t.title;
  if (t.kind === 'estudo') return t.subject ? 'Estudar ' + t.subject : 'Sessão de foco';
  if (t.kind === 'exercicio') return t.sport ? sportName(t.sport) : 'Exercício';
  return 'Pausa longe da tela';
}
function timerSetup(d) {
  var f = tform(), h = '<div class="seg" role="group" aria-label="Tipo de sessão">' +
    [['estudo', 'Estudo'], ['exercicio', 'Exercício'], ['pausa', 'Pausa rápida']].map(function (k) { return chip(k[1], 'tKind', k[0], f.kind === k[0], { cls: 'segb ' + k[0] }); }).join('') + '</div>';

  if (f.actId || f.title) {
    h += '<div class="chosen ' + f.kind + '"><p class="eyebrow">Atividade escolhida</p><p class="chosen-t">' + esc(f.title) + '</p><div class="row-btns">' +
      btn('Trocar', 'pickAct', { cls: 'small' }) + btn('Remover', 'clearAct', { cls: 'small ghost' }) + '</div></div>';
  } else if (f.kind !== 'pausa') {
    h += '<div class="row-btns">' + btn('Escolher uma atividade', 'pickAct', { icon: 'cards' }) + '</div><p class="muted">Opcional. Você também pode só marcar o tempo.</p>';
  }
  if (f.kind === 'estudo') {
    h += d.prefs.subjects.length ?
      chipRow('Matéria', [['', 'Nenhuma']].concat(d.prefs.subjects.map(function (m) { return [m, m]; })), 'tSubject', f.subject) :
      '<p class="muted">Cadastre suas matérias para escolher aqui. ' + link('Abrir preferências', 'goPrefs') + '</p>';
  } else if (f.kind === 'exercicio') {
    h += d.prefs.sports.length ?
      chipRow('Esporte ou exercício', [['', 'Nenhum']].concat(d.prefs.sports.map(function (id) { return [id, sportName(id)]; })), 'tSport', f.sport) :
      '<p class="muted">Cadastre seus esportes para escolher aqui. ' + link('Abrir preferências', 'goPrefs') + '</p>';
  } else if (!f.actId) {
    h += chipRow('Ideia para a pausa', [['', 'Livre']].concat(PAUSE_IDEAS.map(function (p) { return [p, p]; })), 'tIdea', f.idea);
  }

  var cyc = f.kind === 'estudo' && f.cyc;
  if (!cyc) {
    h += chipRow('Duração', [['5', '5 min'], ['10', '10 min'], ['25', '25 min'], ['50', '50 min'], ['x', 'Outro']], 'tMin', f.custom ? 'x' : String(f.min));
    if (f.custom) h += '<div class="field narrow"><label for="tf-min">Minutos (de 1 a 180)</label><input class="input" id="tf-min" name="tf-min" type="number" inputmode="numeric" min="1" max="180" value="' + f.min + '" data-change="tMinInput" data-keep></div>';
  }
  if (f.kind === 'estudo') {
    h += '<div class="card">' + switchRow('tCyc', 'Estudar com intervalos', 'Blocos de foco com um descanso entre eles.', f.cyc);
    if (f.cyc) {
      var total = f.cn * f.cf + (f.cn - 1) * f.cr;
      h += setting('cf', 'Foco', '', stepper('cf', f.cf + ' min', 'minutos de foco por ciclo')) +
        setting('cr', 'Intervalo', '', stepper('cr', f.cr + ' min', 'minutos de intervalo')) +
        setting('cn', 'Ciclos', '', stepper('cn', String(f.cn), 'número de ciclos')) +
        '<p class="muted">' + f.cn + ' ciclos de ' + f.cf + ' min, com ' + f.cr + ' min de intervalo: ' + fmtMin(total) + ' no total, ' + fmtMin(f.cn * f.cf) + ' de estudo.</p>';
    }
    h += '</div>';
  }
  h += btn('Iniciar ' + (cyc ? f.cn + ' ciclos' : fmtMin(f.min)), 'tStart', { cls: 'primary block big ' + f.kind, icon: 'play' });
  if (f.kind === 'exercicio') h += '<p class="muted">Respeite seus limites. Se sentir dor ou mal-estar, pare.</p>';
  h += notice('O tempo conta pelo relógio do aparelho, então continua certo se você sair desta tela. <span id="wake-state">' + esc(wakeText()) + '</span>');
  return h;
}
function timerRun(t) {
  var rem = timerRemain(t), frac = 1 - rem / t.phaseMs, who = t.subject || (t.sport ? sportName(t.sport) : '');
  var phase = t.paused ? 'Pausado' : (t.cyc ? (t.cyc.phase === 'foco' ? 'Foco' : 'Intervalo') + ' · ciclo ' + t.cyc.n + ' de ' + t.cyc.total : KIND_LABEL[t.kind]);
  var runKind = (t.cyc && t.cyc.phase === 'intervalo') ? 'pausa' : t.kind;
  return '<div class="run ' + t.kind + '"><p class="eyebrow">' + esc(KIND_LABEL[t.kind] + (who ? ' · ' + who : '')) + '</p><h2 class="run-t">' + esc(timerTitle(t)) + '</h2>' +
    '<div class="track-wrap">' + trackSVG(frac, runKind, clockText(rem), phase) + '</div>' +
    '<p class="sr" id="timer-sr" role="timer">Faltam ' + spokenMin(Math.ceil(rem / 60000)) + '.</p>' +
    '<div class="row-btns center">' +
    (t.paused ? btn('Continuar', 'tResume', { cls: 'primary', icon: 'play' }) : btn('Pausar', 'tPause', { icon: 'pause' })) +
    btn('Encerrar', 'tStop', { cls: 'ghost', icon: 'stop' }) + '</div>' +
    '<p class="muted center-t">Pode deixar o celular de lado. O tempo continua contando mesmo fora desta tela.</p>' +
    notice('<span id="wake-state">' + esc(wakeText()) + '</span>') + '</div>';
}
function timerDone(d, t) {
  var fn = t.finished, who = t.subject || (t.sport ? sportName(t.sport) : '');
  var h = '<div class="done ' + t.kind + '"><span class="done-ic" aria-hidden="true">' + ic('check') + '</span>' +
    '<h2>' + (fn.early ? 'Sessão encerrada' : 'Tempo concluído') + '</h2><p class="done-t">' + esc(timerTitle(t)) + '</p>' +
    '<p class="muted">' + esc(KIND_LABEL[t.kind] + (who ? ' · ' + who : '')) + ' · planejado: ' + fmtMin(t.planMin) + '</p>';
  if (!fn.early && now() - fn.at > 120000) h += '<p class="muted">O tempo terminou às ' + fmtClock(fn.at) + '.</p>';
  h += '<div class="card">' + setting('done', 'Quanto tempo você fez?', 'Ajuste se parou antes ou continuou depois.', stepper('done', fmtMin(fn.doneMin), 'minutos feitos')) + '</div>';
  if (d.ui.mood) {
    h += '<div class="card">' + chipRow('Como você está agora? (opcional)', MOODS.map(function (m) { return [String(m[0]), m[1]]; }), 'mood1', S.tmp.mood1 || '') +
      '<p class="muted">É só um registro seu. Não é avaliação de saúde.</p></div>';
  }
  h += '<div class="stack">' + (fn.doneMin >= 1 ? btn('Salvar no histórico', 'tSave', { cls: 'primary block' }) : '<p class="muted">Menos de 1 minuto: não há o que registrar.</p>') +
    btn('Descartar', 'tDiscard', { cls: 'ghost block' }) + '</div></div>';
  return h;
}
SCREENS.timer = function () {
  var d = S.data, t = d.timer;
  if (!t) return timerSetup(d);
  return t.finished ? timerDone(d, t) : timerRun(t);
};

/* ---------- histórico ---------- */
function usageChart(w) {
  var top = 0;
  w.days.forEach(function (s) { if (s.usage != null) top = Math.max(top, s.usage); if (s.goal != null && s.usage != null) top = Math.max(top, s.goal); });
  top = niceMax(Math.max(top, 60));
  var cols = w.days.map(function (s, i) {
    var inner = '';
    if (s.usage != null && s.goal != null) inner += '<i class="goal-tick" style="bottom:' + (s.goal * 100 / top).toFixed(1) + '%"></i>';
    if (s.usage != null) {
      var hgt = Math.max(1.5, s.usage * 100 / top);
      inner += '<i class="colbar' + (s.partial ? ' partial' : '') + '" style="height:' + hgt.toFixed(1) + '%"></i><span class="colval" style="bottom:' + hgt.toFixed(1) + '%">' + fmtMin(s.usage).replace(' min', 'm') + '</span>';
    } else inner += '<span class="colnone">–</span>';
    var mark = s.within === true ? ic('check', 'xs') : (s.within === false ? '<b class="up">↑</b>' : '');
    return '<div class="colw"><div class="plot">' + inner + '</div><span class="colmark">' + mark + '</span><span class="collab">' + WD_SHORT[i] + '</span></div>';
  }).join('');
  return '<div class="chart" aria-hidden="true"><div class="yax"><span>' + fmtMin(top) + '</span><span>' + fmtMin(top / 2) + '</span><span>0</span></div><div class="cols">' + cols + '</div></div>' +
    '<p class="legend" aria-hidden="true"><span><i class="lg solid"></i>tempo informado</span><span><i class="lg stripe"></i>valor parcial</span><span><i class="lg tick"></i>meta do dia</span><span>' + ic('check', 'xs') + 'dentro da meta</span><span><b class="up">↑</b>acima da meta</span><span>– sem dados</span></p>';
}
function activityChart(w) {
  var top = 0;
  w.days.forEach(function (s) { top = Math.max(top, s.study, s.move); });
  top = niceMax(Math.max(top, 30));
  var cols = w.days.map(function (s, i) {
    function bar(v, cls) {
      if (!v) return '<div class="pair-b"></div>';
      var hgt = Math.max(2, v * 100 / top);
      return '<div class="pair-b"><i class="colbar ' + cls + '" style="height:' + hgt.toFixed(1) + '%"></i><span class="colval" style="bottom:' + hgt.toFixed(1) + '%">' + v + '</span></div>';
    }
    return '<div class="colw"><div class="plot pair">' + bar(s.study, 'estudo') + bar(s.move, 'exercicio') + '</div><span class="collab">' + WD_SHORT[i] + '</span></div>';
  }).join('');
  return '<div class="chart" aria-hidden="true"><div class="yax"><span>' + top + ' min</span><span>' + (top / 2) + '</span><span>0</span></div><div class="cols">' + cols + '</div></div>' +
    '<p class="legend" aria-hidden="true"><span><i class="lg estudo"></i>estudo</span><span><i class="lg exercicio"></i>exercício</span><span>valores em minutos</span></p>';
}
function dayRow(d, s, i) {
  var today = dayKey(), future = s.key > today, line;
  if (future) line = 'Ainda não chegou.';
  else if (s.usage == null) line = 'Tela: sem dados.';
  else {
    line = 'Tela: ' + fmtMin(s.usage) + (s.partial ? ' (parcial, informado às ' + fmtClock(s.at) + ')' : '') +
      (s.goal != null ? (s.within ? ' · dentro da meta de ' : ' · acima da meta de ') + fmtMin(s.goal) : ' · sem meta');
  }
  var line2 = future ? '' : 'Estudo ' + fmtMin(s.study) + ' · Exercício ' + fmtMin(s.move) + ' · Pausas ' + fmtMin(s.pause);
  return '<li class="li day"><div class="li-main"><p class="li-t">' + WD_SHORT[i] + ' ' + fmtDay(s.key) + (s.key === today ? ' · hoje' : '') + '</p><p class="li-d">' + esc(line) + '</p>' +
    (line2 ? '<p class="li-d">' + esc(line2) + '</p>' : '') + '</div>' +
    (future ? '' : '<button type="button" class="icon-btn" id="day-edit-' + i + '" data-act="logUsage" data-v="' + s.key + '" aria-label="Informar ou corrigir o tempo de tela de ' + esc(fmtDayLong(s.key)) + '">' + ic('edit') + '</button>') + '</li>';
}
SCREENS.hist = function () {
  var d = S.data, cur = weekStart(dayKey()), wk = S.tmp.hw || cur, sum = weekSummary(d, wk), w = sum.w, prev = sum.prev, isCur = wk === cur;
  var h = '<div class="weeknav"><button type="button" class="icon-btn" id="b-week-prev" data-act="weekPrev" aria-label="Semana anterior">' + ic('left') + '</button>' +
    '<p class="weeknav-t" id="week-label">' + (isCur ? 'Esta semana' : 'Semana') + '<span>' + fmtDay(wk) + ' a ' + fmtDay(addDays(wk, 6)) + '</span></p>' +
    '<button type="button" class="icon-btn" id="b-week-next" data-act="weekNext" aria-label="Próxima semana"' + (isCur ? ' disabled' : '') + '>' + ic('right') + '</button></div>';

  h += '<section class="card soft" aria-labelledby="sm-t"><div class="card-head"><h2 id="sm-t">' + ic('star') + 'Resumo da semana</h2>' + demoTag() + '</div>' +
    '<p class="sum"><span class="sum-k">Ponto positivo</span>' + esc(sum.good) + '</p><p class="sum"><span class="sum-k">Sugestão prática</span>' + esc(sum.tip) + '</p></section>';

  h += '<section class="card" aria-labelledby="hu-t"><div class="card-head"><h2 id="hu-t">' + ic('phone') + 'Tempo de tela</h2>' + demoTag() + '</div>';
  if (!w.usageDays) {
    h += '<p class="empty">Nenhum dia desta semana tem tempo de tela informado.</p>' + notice('O Foquinho só mostra o que você informar. Use o lápis ao lado de cada dia, logo abaixo.');
  } else {
    var missing = w.days.filter(function (s) { return s.usage == null && s.key <= dayKey(); }).map(function (s) { return WD_SHORT[wdIndex(s.key)]; });
    var txt = 'Média nos dias informados: ' + fmtMin(w.usageAvg) + ' (' + plural(w.usageDays, 'dia', 'dias') + ').';
    if (w.withinDays + w.overDays > 0) txt += ' Dentro da meta em ' + plural(w.withinDays, 'dia', 'dias') + '.';
    if (missing.length) txt += ' Sem dados: ' + missing.join(', ') + '.';
    h += usageChart(w) + '<p class="chart-sum">' + esc(txt) + '</p>';
    if (prev.usageDays) {
      var diff = Math.round(w.usageAvg - prev.usageAvg);
      h += '<p class="muted">Semana anterior: média de ' + fmtMin(prev.usageAvg) + ' em ' + plural(prev.usageDays, 'dia informado', 'dias informados') + '. ' +
        (Math.abs(diff) < 5 ? 'Praticamente igual.' : (diff < 0 ? 'Tendência: ' + fmtMin(-diff) + ' a menos por dia.' : 'Tendência: ' + fmtMin(diff) + ' a mais por dia.')) + '</p>';
    }
    if (w.days.some(function (s) { return s.partial; })) h += notice('Dias marcados como parciais foram informados antes de o dia terminar, então o total real pode ser maior.');
  }
  h += '</section>';

  h += '<section class="card" aria-labelledby="ha-t"><div class="card-head"><h2 id="ha-t">' + ic('check') + 'Estudo e exercício</h2>' + demoTag() + '</div>';
  if (!w.studyTotal && !w.moveTotal) h += '<p class="empty">Nenhuma sessão de estudo ou exercício nesta semana.</p>';
  else {
    h += activityChart(w) + '<p class="chart-sum">Estudo: ' + fmtMin(w.studyTotal) + ' em ' + plural(w.studyDays, 'dia', 'dias') + '. Exercício: ' + fmtMin(w.moveTotal) + ' em ' + plural(w.moveDays, 'dia', 'dias') + '.</p>';
    var subs = Object.keys(w.subjects).sort(function (a, b) { return w.subjects[b] - w.subjects[a]; });
    if (subs.length) h += '<p class="muted">Por matéria: ' + subs.map(function (m) { return esc(m) + ' ' + fmtMin(w.subjects[m]); }).join(' · ') + '.</p>';
  }
  h += '</section>';

  h += '<section aria-labelledby="hd-t"><h2 class="sec" id="hd-t">Dia a dia</h2><ul class="list card flush">' + w.days.map(function (s, i) { return dayRow(d, s, i); }).join('') + '</ul></section>';

  var end = addDays(wk, 6), sess = d.sessions.filter(function (s) { return s.day >= wk && s.day <= end; }).sort(function (a, b) { return b.start - a.start; });
  h += '<section aria-labelledby="hs-t"><h2 class="sec" id="hs-t">Sessões da semana</h2>';
  if (!sess.length) h += '<p class="empty">Nenhuma sessão registrada nesta semana.</p>';
  else {
    h += '<ul class="list card flush">' + sess.map(function (s, i) {
      var mood = (s.m0 || s.m1) ? ' · ' + (s.m0 ? 'antes: ' + moodLabel(s.m0).toLowerCase() : '') + (s.m0 && s.m1 ? ', ' : '') + (s.m1 ? 'depois: ' + moodLabel(s.m1).toLowerCase() : '') : '';
      return '<li class="li"><span class="li-ic ' + s.kind + '" aria-hidden="true">' + ic(kindIcon(s.kind)) + '</span><div class="li-main"><p class="li-t">' + esc(s.title || KIND_LABEL[s.kind]) + '</p>' +
        '<p class="li-d">' + WD_SHORT[wdIndex(s.day)] + ' ' + fmtDay(s.day) + ' às ' + fmtClock(s.start) + ' · ' + KIND_LABEL[s.kind] + ' · ' + fmtMin(s.min) + esc(mood) + '</p></div>' +
        '<button type="button" class="icon-btn" id="sess-del-' + i + '" data-act="delSession" data-v="' + esc(s.id) + '" aria-label="Excluir sessão: ' + esc(s.title || KIND_LABEL[s.kind]) + '">' + ic('trash') + '</button></li>';
    }).join('') + '</ul>';
  }
  h += '</section>';
  h += '<div class="row-btns">' + btn('Exportar dados', 'goData', { icon: 'down' }) + btn('Apagar histórico', 'askClearHistory', { cls: 'ghost', icon: 'trash' }) + '</div>';
  return h;
};
