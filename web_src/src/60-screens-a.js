/* ---------- telas: boas-vindas, perfil, configuração inicial e painel ---------- */
function link(label, act, v, id) {
  return '<button type="button" class="link" id="' + (id || ('l-' + act + (v != null ? '-' + slug(String(v)) : ''))) + '" data-act="' + act + '"' + (v != null ? ' data-v="' + esc(v) + '"' : '') + '>' + esc(label) + '</button>';
}
function backLink(act) {
  return '<button type="button" class="link back" id="b-back" data-act="' + (act || 'goWelcome') + '">' + ic('left', 'sm') + '<span>Voltar</span></button>';
}

SCREENS.welcome = function () {
  var hasProfiles = S.device.profiles.length > 0, hasGuest = !!lsGet(keyData('guest'));
  return '<div class="welcome">' +
    '<div class="brand"><span class="logo" aria-hidden="true">' + logoSVG() + '</span><span class="brand-name">Foquinho</span></div>' +
    '<h1 id="title" tabindex="-1">Menos tela.<br>Mais estudo e movimento.</h1>' +
    '<p class="lead">O Foquinho ajuda você a trocar um pouco do tempo de celular por estudo e exercício, no seu ritmo e sem cobrança.</p>' +
    '<div class="hero" aria-hidden="true">' + trackSVG(0.38, 'estudo', '15:30', 'Estudo · Matemática') + '</div>' +
    '<ul class="feat">' +
    '<li><span class="feat-ic estudo">' + ic('book') + '</span><div><strong>Estudo do seu jeito</strong><span>Sugestões para as suas matérias, as provas que estão chegando e os assuntos em que você tem mais dificuldade.</span></div></li>' +
    '<li><span class="feat-ic exercicio">' + ic('ball') + '</span><div><strong>Exercício que você curte</strong><span>Ideias de 5 a 30 minutos com os esportes que você pratica.</span></div></li>' +
    '<li><span class="feat-ic">' + ic('target') + '</span><div><strong>Metas sem culpa</strong><span>Você escolhe a meta de tela, os lembretes e as pausas. Sem ranking e sem punição.</span></div></li>' +
    '</ul>' +
    '<div class="stack">' +
    btn('Começar', 'goSignup', { cls: 'primary block' }) +
    (hasProfiles ? btn('Entrar no meu perfil', 'goLogin', { cls: 'block' }) : '') +
    (hasGuest ? btn('Continuar sem conta', 'guest', { cls: 'block', id: 'b-guest-resume' }) : '') +
    btn('Ver demonstração', 'demoOn', { cls: 'ghost block', icon: 'demo' }) +
    '</div>' +
    '<p class="fine">Seus dados ficam guardados só neste aparelho. O Foquinho não pede e-mail nem telefone.</p>' +
    '</div>';
};

function pwToggle(ids) {
  return '<label class="check"><input type="checkbox" id="pw-show" data-change="showPw" data-ids="' + ids + '"><span>Mostrar senhas</span></label>';
}
SCREENS.signup = function () {
  var migrating = !!(S.user && S.user.id === 'guest'), e = S.tmp.err || {}, busy = !!S.tmp.busy;
  var form = CRYPTO_OK ?
    '<form data-form="signup" novalidate class="stack">' +
    field('su-name', 'Nome de usuário', { max: 20, ac: 'username', nocap: true, hint: 'Pode ser um apelido. De 3 a 20 caracteres.', invalid: e.field === 'su-name', dis: busy }) +
    field('su-pass', 'Senha', { type: 'password', max: 72, ac: 'new-password', hint: 'Pelo menos 6 caracteres.', invalid: e.field === 'su-pass', dis: busy }) +
    field('su-pass2', 'Repita a senha', { type: 'password', max: 72, ac: 'new-password', invalid: e.field === 'su-pass2', dis: busy }) +
    pwToggle('su-pass,su-pass2') +
    notice('Guarde bem a senha. Como o Foquinho não pede e-mail, não existe recuperação de senha.') +
    errBox(e.msg) +
    (busy ? '<p class="loading" role="status">' + ic('lock') + '<span>Protegendo sua senha…</span></p>' : '') +
    btn(migrating ? 'Criar perfil e guardar meus dados' : 'Criar perfil', '', { submit: true, cls: 'primary block', id: 'b-signup', dis: busy }) +
    '</form>' :
    notice('Este navegador não tem o recurso necessário para proteger senhas, então o perfil com senha fica indisponível aqui. O Foquinho funciona normalmente sem conta.', 'warn');
  return backLink(migrating ? 'back' : 'goWelcome') +
    '<h1 id="title" tabindex="-1">' + (migrating ? 'Criar perfil' : 'Como você quer começar?') + '</h1>' +
    '<section class="card"><h2>' + ic('user') + 'Perfil com senha</h2>' +
    '<p class="muted">O perfil fica só neste aparelho e não sincroniza com outros celulares.' + (migrating ? ' O que você já registrou sem conta vai junto.' : '') + '</p>' + form + '</section>' +
    (migrating ? '' : '<section class="card"><h2>' + ic('play') + 'Experimentar sem conta</h2><p class="muted">Tudo funciona do mesmo jeito. Se quiser, você cria o perfil depois e leva os dados junto.</p>' +
      btn('Continuar sem conta', 'guest', { cls: 'block' }) + '</section>');
};

SCREENS.login = function () {
  var e = S.tmp.err || {}, busy = !!S.tmp.busy, profs = S.device.profiles;
  return backLink() + '<h1 id="title" tabindex="-1">Entrar</h1>' +
    '<section class="card">' +
    (profs.length ? '<div class="chips"><p class="chips-label" id="g-prof">Perfis neste aparelho</p><div class="wrap" role="group" aria-labelledby="g-prof">' +
      profs.map(function (p) { return chip(p.name, 'pickProfile', p.name, false, { cls: 'plain' }); }).join('') + '</div></div>' : '<p class="muted">Ainda não há perfis neste aparelho.</p>') +
    '<form data-form="login" novalidate class="stack">' +
    field('li-name', 'Nome de usuário', { max: 20, ac: 'username', nocap: true, dis: busy, value: S.tmp.liName || '' }) +
    field('li-pass', 'Senha', { type: 'password', max: 72, ac: 'current-password', dis: busy, invalid: e.field === 'li-pass' }) +
    pwToggle('li-pass') + errBox(e.msg) +
    (busy ? '<p class="loading" role="status">' + ic('lock') + '<span>Conferindo a senha…</span></p>' : '') +
    btn('Entrar', '', { submit: true, cls: 'primary block', id: 'b-login', dis: busy }) +
    '</form>' +
    '<p>' + link('Esqueci a senha', 'forgot') + '</p></section>' +
    '<div class="stack">' + btn('Criar outro perfil', 'goSignup', { cls: 'block' }) + btn('Continuar sem conta', 'guest', { cls: 'ghost block' }) + '</div>';
};

/* ---------- editores reutilizados na configuração inicial e em Preferências ---------- */
function sportsEditor(d) {
  var sel = d.prefs.sports;
  return '<div class="wrap" role="group" aria-label="Esportes e exercícios">' +
    SPORTS.map(function (s) { return chip(s[1], 'sport', s[0], sel.indexOf(s[0]) >= 0); }).join('') +
    sel.filter(function (id) { return id.indexOf('c:') === 0; }).map(function (id) { return chip(id.slice(2), 'sport', id, true); }).join('') + '</div>' +
    '<form class="addline" data-form="addSport" novalidate><div class="field grow"><label for="sp-new">Outro esporte ou exercício</label>' +
    '<input class="input" id="sp-new" name="sp-new" data-keep maxlength="40" autocomplete="off"></div>' + btn('Adicionar', '', { submit: true, id: 'b-add-sport' }) + '</form>';
}
function subjectsEditor(d) {
  var sel = d.prefs.subjects, extra = sel.filter(function (m) { return SUBJECTS.indexOf(m) < 0; });
  var h = '<div class="wrap" role="group" aria-label="Matérias">' +
    SUBJECTS.map(function (m) { return chip(m, 'subject', m, sel.indexOf(m) >= 0); }).join('') +
    extra.map(function (m) { return chip(m, 'subject', m, true); }).join('') + '</div>' +
    '<form class="addline" data-form="addSubject" novalidate><div class="field grow"><label for="sb-new">Outra matéria</label>' +
    '<input class="input" id="sb-new" name="sb-new" data-keep maxlength="40" autocomplete="off"></div>' + btn('Adicionar', '', { submit: true, id: 'b-add-subject' }) + '</form>';
  if (sel.length) {
    h += '<h2 class="sub">Em quais você tem mais dificuldade?</h2><p class="muted">Elas aparecem primeiro nas sugestões de estudo.</p>' +
      '<div class="wrap" role="group" aria-label="Matérias com mais dificuldade">' + sel.map(function (m) { return chip(m, 'hard', m, d.prefs.hard.indexOf(m) >= 0); }).join('') + '</div>';
  }
  return h;
}
function examRow(e, i) {
  var past = e.date && e.date < dayKey();
  return '<li class="li"><span class="li-ic" aria-hidden="true">' + ic('cal') + '</span><div class="li-main"><p class="li-t">' + esc(e.subject) + (e.topic ? ' · ' + esc(e.topic) : '') + '</p>' +
    '<p class="li-d">' + (e.date ? esc(fmtDayLong(e.date)) + ' · ' + (past ? 'já passou' : esc(relDay(e.date))) : 'Sem data definida') + '</p></div>' +
    '<button type="button" class="icon-btn" id="ex-edit-' + i + '" data-act="editExam" data-v="' + esc(e.id) + '" aria-label="Editar prova de ' + esc(e.subject) + '">' + ic('edit') + '</button>' +
    '<button type="button" class="icon-btn" id="ex-del-' + i + '" data-act="delExam" data-v="' + esc(e.id) + '" aria-label="Excluir prova de ' + esc(e.subject) + '">' + ic('trash') + '</button></li>';
}
function examsEditor(d) {
  var list = d.prefs.exams.slice().sort(function (a, b) { var x = a.date || '9999', y = b.date || '9999'; return x < y ? -1 : (x > y ? 1 : 0); });
  return (list.length ? '<ul class="list">' + list.map(examRow).join('') + '</ul>' : '<p class="empty">Nenhuma prova anotada.</p>') +
    '<div class="row-btns">' + btn('Adicionar prova', 'addExam', { icon: 'plus' }) + (pastExams(d).length ? btn('Limpar provas passadas', 'clearPastExams', { cls: 'ghost' }) : '') + '</div>';
}
var USUAL = [['lt2', 'Menos de 2 h'], ['2a4', 'De 2 a 4 h'], ['4a6', 'De 4 a 6 h'], ['6a8', 'De 6 a 8 h'], ['gt8', 'Mais de 8 h'], ['ns', 'Não sei']];
var USUAL_GOAL = { lt2: 90, '2a4': 165, '4a6': 270, '6a8': 390, gt8: 480 };
function notifBox() {
  var st = notifState(), h;
  if (st === 'unsupported') h = notice('Este navegador não oferece notificações do sistema para o Foquinho. Os lembretes aparecem dentro do app enquanto ele estiver aberto. Para ser avisado com o app fechado, use também o despertador do celular.');
  else if (st === 'granted' && !S.notifBroken) h = notice('Notificações liberadas neste navegador. Mesmo assim, elas só saem enquanto a página do Foquinho estiver aberta em alguma aba.');
  else if (st === 'denied' || S.notifBroken) h = notice('As notificações do sistema não estão liberadas para o Foquinho neste navegador. Os lembretes aparecem dentro do app enquanto ele estiver aberto.');
  else h = notice('Seu navegador pode mostrar notificações do Foquinho enquanto a página estiver aberta. Antes de pedir a permissão, saiba: ela serve só para os lembretes que você criar, e você pode desligar quando quiser.') +
    btn('Pedir permissão de notificações', 'askNotif', { icon: 'bell' });
  return '<div class="stack" id="notif-box">' + h + '</div>';
}
function obRem(d, kind) { for (var i = 0; i < d.rem.list.length; i++) if (d.rem.list[i].id === 'ob-' + kind) return d.rem.list[i]; return null; }
function timeInput(id, label, value, k) {
  return '<div class="field time"><label for="' + id + '">' + esc(label) + '</label><input class="input" type="time" id="' + id + '" name="' + id + '" value="' + esc(value) + '" data-change="time" data-k="' + k + '"></div>';
}

var OB_STEPS = 5;
function obHead(i, title, sub) {
  var dots = '';
  for (var n = 0; n < OB_STEPS; n++) dots += '<i' + (n <= i ? ' class="on"' : '') + '></i>';
  return '<div class="ob-head"><div class="ob-dots" aria-hidden="true">' + dots + '</div><p class="eyebrow">Passo ' + (i + 1) + ' de ' + OB_STEPS + ' · tudo é opcional</p>' +
    '<h1 id="title" tabindex="-1">' + title + '</h1>' + (sub ? '<p class="lead">' + sub + '</p>' : '') + '</div>';
}
function obFoot(i) {
  return '<div class="ob-foot stack">' + btn(i === OB_STEPS - 1 ? 'Concluir' : 'Continuar', 'obNext', { cls: 'primary block' }) +
    '<div class="row-btns spread">' + (i > 0 ? btn('Voltar', 'obBack', { cls: 'ghost' }) : '<span></span>') + btn('Pular tudo', 'obSkipAll', { cls: 'ghost' }) + '</div></div>';
}
SCREENS.onboard = function () {
  var d = S.data, i = S.tmp.ob || 0, body;
  if (i === 0) {
    body = obHead(i, 'Quais esportes ou exercícios você curte?', 'Marque quantos quiser. Dá para mudar depois.') + sportsEditor(d);
  } else if (i === 1) {
    body = obHead(i, 'Quais matérias você está estudando?', 'Elas viram sugestões de estudo feitas para você.') + subjectsEditor(d);
  } else if (i === 2) {
    body = obHead(i, 'Tem prova chegando?', 'Anote a matéria e o assunto. A data é opcional.') + examsEditor(d);
  } else if (i === 3) {
    var g = d.goals.dailyMin, sug = d.prefs.usual ? USUAL_GOAL[d.prefs.usual] : null;
    body = obHead(i, 'Quanto tempo você costuma passar no celular por dia?', 'Pode ser um chute. Serve só para sugerir uma meta.') +
      '<div class="wrap" role="group" aria-label="Tempo de uso por dia">' + USUAL.map(function (u) { return chip(u[1], 'usual', u[0], d.prefs.usual === u[0]); }).join('') + '</div>' +
      '<h2 class="sub">Que meta diária você quer tentar?</h2>' +
      (g == null ?
        '<p class="muted">' + (sug ? 'Sugestão: ' + fmtMin(sug) + ' por dia, um pouco abaixo do que você costuma usar.' : 'Você pode escolher um valor ou deixar sem meta por enquanto.') + '</p>' +
        '<div class="row-btns">' + btn(sug ? 'Usar ' + fmtMin(sug) : 'Definir uma meta', 'setGoalDefault', { cls: '', v: sug || 300 }) + '</div>' :
        '<div class="goal-pick">' + stepper('goal', fmtMin(g), 'meta diária de tempo de tela') + '</div><p class="muted">Ajuste de 15 em 15 minutos. ' + link('Ficar sem meta por enquanto', 'clearGoal') + '</p>') +
      notice('A meta é um objetivo seu, não uma obrigação. Se passar dela, tudo bem: você tenta de novo no dia seguinte.');
  } else {
    var rs = obRem(d, 'estudo'), rm = obRem(d, 'exercicio');
    body = obHead(i, 'Quer lembretes para estudar e se mexer?', 'Você escolhe os horários e pode desligar quando quiser.') +
      '<div class="card">' + switchRow('obStudy', 'Lembrete para estudar', '', !!rs) + (rs ? timeInput('ob-t-estudo', 'Horário do estudo', rs.time, 'ob-estudo') : '') + '</div>' +
      '<div class="card">' + switchRow('obMove', 'Lembrete para se exercitar', '', !!rm) + (rm ? timeInput('ob-t-exercicio', 'Horário do exercício', rm.time, 'ob-exercicio') : '') + '</div>' +
      '<div class="card">' + switchRow('quiet', 'Período sem avisos', 'Nenhum lembrete aparece nesse intervalo.', d.rem.quiet.on) +
      (d.rem.quiet.on ? '<div class="two">' + timeInput('q-from', 'Começa às', d.rem.quiet.from, 'q-from') + timeInput('q-to', 'Termina às', d.rem.quiet.to, 'q-to') + '</div>' : '') + '</div>' +
      notifBox();
  }
  return '<div class="onboard">' + body + obFoot(i) + '</div>';
};

/* ---------- painel principal ---------- */
function actMeta(a) { return KIND_LABEL[a.kind] + ' · ' + a.min + ' min · ' + PLACE_LABEL[a.place] + ' · ' + ENERGY_LABEL[a.energy]; }
function actCard(a, o) {
  o = o || {};
  var d = S.data, fav = d.fav.indexOf(a.id) >= 0, lat = d.later.indexOf(a.id) >= 0, sid = slug(a.id) + (o.sfx || ''), tags = actTags(a);
  return '<article class="act ' + a.kind + '"><span class="act-ic" aria-hidden="true">' + ic(kindIcon(a.kind)) + '</span><div class="act-main"><h3>' + esc(a.title) + '</h3>' +
    '<p class="act-meta">' + esc(actMeta(a)) + '</p>' +
    (tags.length ? '<p class="tags">' + tags.map(function (t) { return tag(t); }).join('') + '</p>' : '') +
    '<div class="act-btns">' + btn('Fazer agora', 'startAct', { v: a.id, id: 'as-' + sid, cls: 'small primary' }) +
    btn(fav ? 'Favorita' : 'Favoritar', 'fav', { v: a.id, id: 'af-' + sid, cls: 'small ghost', icon: 'star', pressed: fav }) +
    btn(lat ? 'Guardada' : 'Depois', 'later', { v: a.id, id: 'al-' + sid, cls: 'small ghost', icon: 'later', pressed: lat }) +
    (a.custom && o.del ? btn('Excluir', 'delCustom', { v: a.customId, id: 'ad-' + sid, cls: 'small ghost', icon: 'trash' }) : '') + '</div></div></article>';
}
function screenCard(d) {
  var today = dayKey(), s = dayStats(d, today), goal = s.goal;
  var h = '<section class="card" aria-labelledby="sc-t"><div class="card-head"><h2 id="sc-t">' + ic('phone') + 'Tempo de tela hoje</h2>' + demoTag() + '</div>';
  if (s.usage == null) {
    h += '<p class="big"><span class="big-empty">Sem dados de hoje</span></p>' +
      notice('O Foquinho não consegue ler o tempo de tela sozinho nesta versão. Você vê o número nas configurações do celular e informa aqui.') +
      '<div class="row-btns">' + btn('Informar tempo de hoje', 'logUsage', { cls: 'primary', v: today }) + btn('Onde encontro?', 'whereUsage', { cls: 'ghost' }) + '</div>' +
      (goal != null ? '<p class="muted">Meta de hoje: ' + fmtMin(goal) + '.</p>' : '<p class="muted">Nenhuma meta definida. ' + link('Definir uma meta', 'goGoals', null, 'l-goal-home') + '</p>');
  } else {
    h += '<p class="big"><span class="num">' + fmtMin(s.usage) + '</span>' + (goal != null ? '<span class="of"> de ' + fmtMin(goal) + '</span>' : '') + '</p>';
    if (goal != null) {
      var pct = Math.round(s.usage * 100 / goal), left = goal - s.usage, txt, cls = '', icn = 'check';
      if (left < 0) { txt = 'Passou ' + fmtMin(-left) + ' da meta. Acontece: amanhã você tenta de novo.'; cls = 'over'; icn = 'info'; }
      else if (pct >= 80) { txt = pct + '% da meta. Às ' + fmtClock(s.at) + ' faltavam ' + fmtMin(left) + '. Que tal uma pausa agora?'; cls = 'near'; icn = 'info'; }
      else txt = pct + '% da meta. Às ' + fmtClock(s.at) + ' faltavam ' + fmtMin(left) + '.';
      h += progress(Math.min(100, pct), txt, cls) + '<p class="status ' + cls + '">' + ic(icn, 'sm') + '<span>' + esc(txt) + '</span></p>';
    } else {
      h += '<p class="muted">Sem meta para comparar. ' + link('Definir uma meta', 'goGoals', null, 'l-goal-home') + '</p>';
    }
    h += notice('Informado por você às ' + fmtClock(s.at) + '.' + (s.partial ? ' É um valor parcial: o dia ainda não terminou.' : '')) +
      '<div class="row-btns">' + btn('Atualizar', 'logUsage', { v: today }) + btn('Onde encontro?', 'whereUsage', { cls: 'ghost' }) + '</div>';
  }
  return h + '</section>';
}
function weekGoalLine(label, done, target, cls) {
  var txt = fmtMin(done) + ' de ' + fmtMin(target) + ' nesta semana';
  return '<div class="wk"><p class="wk-l">' + esc(label) + ': <strong>' + esc(txt) + '</strong>' + (done >= target ? ' ' + tag('meta alcançada', 'ok') : '') + '</p>' + progress(done * 100 / target, label + ': ' + txt, cls) + '</div>';
}
function offScreenCard(d) {
  var s = dayStats(d, dayKey()), w = weekStats(d, weekStart(dayKey())), g = d.goals;
  var h = '<section class="card" aria-labelledby="os-t"><div class="card-head"><h2 id="os-t">' + ic('check') + 'Hoje fora da tela</h2>' + demoTag() + '</div>' +
    '<div class="tiles">' +
    '<div class="tile estudo"><span class="tile-l">' + ic('book', 'sm') + 'Estudo</span><span class="tile-v num">' + fmtMin(s.study) + '</span></div>' +
    '<div class="tile exercicio"><span class="tile-l">' + ic('ball', 'sm') + 'Exercício</span><span class="tile-v num">' + fmtMin(s.move) + '</span></div>' +
    '<div class="tile"><span class="tile-l">' + ic('pause', 'sm') + 'Pausas</span><span class="tile-v num">' + fmtMin(s.pause) + '</span></div></div>';
  if (g.studyWeek) h += weekGoalLine('Estudo', w.studyTotal, g.studyWeek, 'estudo');
  if (g.moveWeek) h += weekGoalLine('Exercício', w.moveTotal, g.moveWeek, 'exercicio');
  if (!s.count) h += '<p class="muted">Os minutos aparecem aqui quando você conclui uma sessão no temporizador.</p>';
  return h + '</section>';
}
function useCard(d) {
  var lim = d.goals.sessionMin, u = d.useSession;
  if (lim == null && !u) return '';
  var h = '<section class="card" aria-labelledby="us-t"><div class="card-head"><h2 id="us-t">' + ic('clock') + 'Aviso de uso contínuo</h2></div>';
  if (u) {
    h += '<p>Contagem iniciada às ' + fmtClock(u.start) + ', <strong id="use-elapsed">há ' + fmtMin((now() - u.start) / 60000) + '</strong>. Aviso aos ' + fmtMin(u.limit) + '.</p>' +
      '<div class="row-btns">' + btn('Encerrar a contagem', 'endUse') + btn('Fazer uma pausa agora', 'quickPause', { cls: 'ghost', id: 'b-use-pause' }) + '</div>';
  } else {
    h += '<p>Vai usar o celular agora? Inicie a contagem e o Foquinho sugere uma pausa depois de ' + fmtMin(lim) + '.</p>' +
      '<div class="row-btns">' + btn('Iniciar contagem', 'startUse', { icon: 'play' }) + '</div>';
  }
  return h + notice('O Foquinho não enxerga o que você faz em outros apps. O aviso aparece quando ele estiver aberto ou quando você voltar para ele.') + '</section>';
}
function streakCard(d) {
  var s = streakInfo(d), lit = s.count > 0;
  var title = s.count === 0 ? 'Sequência: comece hoje' : plural(s.count, 'dia seguido', 'dias seguidos');
  var days = s.week.map(function (w, i) {
    var label = w.st === 'ativo' ? 'feito' : (w.st === 'folga' ? 'folga' : 'sem sessão');
    return '<li class="sk-day ' + w.st + (i === 6 ? ' today' : '') + '"><span class="sk-dot" aria-hidden="true">' + (w.st === 'ativo' ? ic('check', 'sm') : (w.st === 'folga' ? ic('moon', 'sm') : '')) +
      '</span><span class="sk-l">' + WD_SHORT[wdIndex(w.key)] + '</span><span class="sr">: ' + label + '</span></li>';
  }).join('');
  return '<section class="card streak' + (lit ? ' lit' : '') + '" aria-labelledby="sk-t"><div class="sk-top"><span class="sk-fire" aria-hidden="true">' + ic('fire') + '</span>' +
    '<div class="sk-txt"><h2 id="sk-t">' + esc(title) + '</h2><p class="muted">' + esc(streakMessage(s)) + '</p></div>' + demoTag() + '</div>' +
    '<ul class="sk-week" aria-label="Últimos 7 dias">' + days + '</ul>' +
    '<p class="sk-note">Um dia de folga por semana não quebra a sequência.' + (s.best > s.count ? ' Seu recorde: ' + plural(s.best, 'dia', 'dias') + '.' : '') + '</p></section>';
}
SCREENS.home = function () {
  var d = S.data, today = dayKey(), h = '<p class="hello">' + esc(homeMessage(d)) + '</p>';
  h += streakCard(d);
  h += screenCard(d);
  h += '<section aria-labelledby="qa-t"><h2 class="sec" id="qa-t">Começar agora</h2><div class="quick">' +
    '<button type="button" class="qa" id="qa-pause" data-act="quickPause">' + ic('pause') + '<span>Pausa de 5 min</span></button>' +
    '<button type="button" class="qa estudo" id="qa-focus" data-act="quickFocus">' + ic('book') + '<span>Sessão de foco</span></button>' +
    '<button type="button" class="qa exercicio" id="qa-acts" data-act="tab" data-v="acts">' + ic('cards') + '<span>Escolher atividade</span></button></div></section>';

  var gs = gradualSuggestion(d);
  if (gs) {
    h += '<section class="card soft" aria-labelledby="gr-t"><div class="card-head"><h2 id="gr-t">' + ic('target') + 'Sugestão da semana</h2>' + demoTag() + '</div>' +
      '<p>Que tal baixar a meta diária de ' + fmtMin(gs.from) + ' para <strong>' + fmtMin(gs.to) + '</strong>? Você decide.</p>' +
      '<div class="row-btns">' + btn('Aceitar ' + fmtMin(gs.to), 'gradualYes', { cls: 'primary' }) + btn('Manter ' + fmtMin(gs.from), 'gradualNo', { cls: 'ghost' }) + '</div></section>';
  }

  var ranked = rankActs(buildActivities(d), d);
  if (ranked.length) {
    var a = ranked[(S.tmp.sug || 0) % ranked.length];
    h += '<section aria-labelledby="sg-t"><div class="sec-row"><h2 class="sec" id="sg-t">Sugestão para agora</h2>' + link('Outra sugestão', 'nextSug') + '</div>' + actCard(a) +
      ((!d.prefs.subjects.length && !d.prefs.sports.length) ? '<p class="muted">Conte suas matérias e esportes para receber sugestões mais pessoais. ' + link('Abrir preferências', 'goPrefs') + '</p>' : '') + '</section>';
  }

  var exams = upcomingExams(d).slice(0, 3);
  if (exams.length) {
    h += '<section class="card" aria-labelledby="pv-t"><div class="card-head"><h2 id="pv-t">' + ic('cal') + 'Próximas provas</h2>' + demoTag() + '</div><ul class="list">' +
      exams.map(function (e, i) {
        return '<li class="li"><div class="li-main"><p class="li-t">' + esc(e.subject) + (e.topic ? ' · ' + esc(e.topic) : '') + '</p><p class="li-d">' +
          (e.date ? esc(fmtDayLong(e.date)) + ' · ' + esc(relDay(e.date)) : 'Sem data definida') + '</p></div>' +
          btn('Estudar', 'studyExam', { v: e.id, id: 'b-study-exam-' + i, cls: 'small' }) + '</li>';
      }).join('') + '</ul></section>';
  }

  h += planHomeCard(d);
  h += offScreenCard(d);

  h += '<section class="card" aria-labelledby="pl-t"><div class="card-head"><h2 id="pl-t">' + ic('bulb') + 'Quando bater a vontade</h2>' + demoTag() + '</div>';
  if (d.plan) {
    h += '<p>Se eu pegar o celular por hábito, eu vou:</p><p class="plan-txt">' + esc(d.plan.text) + '</p>' +
      '<div class="row-btns">' + btn('Fazer agora, ' + d.plan.min + ' min', 'doPlan', { cls: 'primary' }) + btn('Editar', 'goPlan', { cls: 'ghost' }) + '</div>';
  } else {
    h += '<p>Escolha agora o que fazer quando abrir o celular sem motivo. Com o plano pronto, fica mais fácil trocar.</p><div class="row-btns">' + btn('Criar meu plano', 'goPlan') + '</div>';
  }
  h += '</section>';

  h += useCard(d);

  var yk = addDays(today, -1), yu = d.usage[yk];
  if (!S.demo && d.createdAt < keyToDate(today).getTime() - 12 * 3600000 && (!yu || usagePartial(yu, yk)) && d.flags.yday !== today) {
    h += '<section class="card soft" aria-labelledby="yd-t"><div class="card-head"><h2 id="yd-t">' + ic('clock') + 'E ontem?</h2></div>' +
      '<p>' + (yu ? 'O valor de ontem ficou parcial. ' : 'Ontem ficou sem registro. ') + 'O total de um dia completo deixa o histórico mais fiel.</p>' +
      '<div class="row-btns">' + btn('Informar o total de ontem', 'logUsage', { v: yk, id: 'b-log-yday' }) + btn('Agora não', 'skipYday', { cls: 'ghost' }) + '</div></section>';
  }

  var wk = weekStart(today), chs = d.challenges.filter(function (c) { return c.week === wk; });
  if (chs.length) {
    h += '<section class="card" aria-labelledby="ch-t"><div class="card-head"><h2 id="ch-t">' + ic('flag') + 'Desafios da semana</h2>' + demoTag() + '</div>' +
      chs.map(function (c) {
        var p = challengeProgress(d, c), txt = p.done + (p.unit ? ' ' + p.unit : '') + ' de ' + p.target + (p.unit ? ' ' + p.unit : '');
        return '<div class="wk"><p class="wk-l">' + esc(challengeLabel(c)) + ': <strong>' + esc(txt) + '</strong>' + (p.ok ? ' ' + tag('concluído', 'ok') : '') + '</p>' + progress(p.pct, challengeLabel(c) + ': ' + txt) + '</div>';
      }).join('') + '<p>' + link('Ver desafios', 'goChallenges') + '</p></section>';
  }

  var wd = wdIndex(today), rems = d.rem.list.filter(function (r) { return r.on && r.days.indexOf(wd) >= 0; });
  if (rems.length || !d.rem.on || now() < d.rem.pausedUntil) {
    h += '<section class="card" aria-labelledby="rm-t"><div class="card-head"><h2 id="rm-t">' + ic('bell') + 'Lembretes de hoje</h2>' + demoTag() + '</div>';
    if (!d.rem.on) h += '<p class="status near">' + ic('info', 'sm') + '<span>Os lembretes estão desligados.</span></p>';
    else if (now() < d.rem.pausedUntil) h += '<p class="status near">' + ic('info', 'sm') + '<span>Lembretes em silêncio até ' + fmtClock(d.rem.pausedUntil) + '.</span></p><div class="row-btns">' + btn('Reativar agora', 'unmute', { cls: 'small' }) + '</div>';
    if (rems.length) {
      h += '<ul class="list">' + rems.map(function (r) {
        return '<li class="li"><div class="li-main"><p class="li-t">' + esc(r.label) + '</p><p class="li-d">' + esc(remStatusToday(d, r)) + '</p></div></li>';
      }).join('') + '</ul>';
    }
    h += '<p>' + link('Ajustar lembretes', 'goGoals', null, 'l-goals-rem') + '</p></section>';
  }
  return h;
};
