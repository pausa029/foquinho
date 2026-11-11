/* ---------- telas: mais, preferências, metas, privacidade e configurações ---------- */
function navRow(icon, title, desc, route) {
  return '<li><button type="button" class="nav-row" id="nav-' + route + '" data-act="nav" data-v="' + route + '"><span class="li-ic" aria-hidden="true">' + ic(icon) + '</span>' +
    '<span class="li-main"><span class="li-t">' + esc(title) + '</span><span class="li-d">' + esc(desc) + '</span></span>' + ic('right', 'sm') + '</button></li>';
}
SCREENS.more = function () {
  var guest = S.user.id === 'guest', who;
  if (S.demo) who = '<p class="who-t">Modo demonstração</p><p class="muted">Dados fictícios, que não são salvos.</p><div class="row-btns">' + btn('Sair da demonstração', 'demoOff', { id: 'b-demo-off-2' }) + '</div>';
  else if (guest) who = '<p class="who-t">Você está usando sem conta</p><p class="muted">Seus dados ficam neste aparelho. Crie um perfil para proteger a entrada com senha.</p><div class="row-btns">' + btn('Criar perfil', 'goSignup', { cls: 'primary', id: 'b-make-profile' }) + '</div>';
  else who = '<p class="who-t">' + esc(S.user.name) + '</p><p class="muted">Perfil local, guardado só neste aparelho.</p>';
  return '<section class="card who">' + who + '</section>' +
    '<h2 class="sec">Sua rotina</h2><ul class="nav card flush">' +
    navRow('book', 'Esportes, matérias e provas', 'O que personaliza as sugestões', 'prefs') +
    navRow('target', 'Metas e horários', 'Meta de tela, lembretes e período sem avisos', 'goals') +
    navRow('cal', 'Mural de estudos', 'Quadro da semana e do mês, com provas chegando', 'agenda') +
    navRow('bulb', 'Plano para a vontade', 'O que fazer ao pegar o celular por hábito', 'plan') +
    navRow('flag', 'Desafios pessoais', 'Privados, opcionais e sem ranking', 'challenges') + '</ul>' +
    '<h2 class="sec">Aplicativo</h2><ul class="nav card flush">' +
    navRow('sun', 'Aparência e avisos', 'Tema, tamanho do texto, som e vibração', 'look') +
    navRow('gear', 'Permissões e recursos', 'O que este aparelho permite e o que não permite', 'perms') +
    navRow('phone', 'Controles do aparelho', 'Limites e modo foco do Android e do iPhone', 'native') + '</ul>' +
    '<h2 class="sec">Dados e privacidade</h2><ul class="nav card flush">' +
    navRow('shield', 'Privacidade', 'O que fica guardado e onde', 'privacy') +
    navRow('down', 'Seus dados', 'Exportar, importar e apagar', 'datap') +
    navRow('user', 'Perfil', guest ? 'Criar perfil ou sair' : 'Senha, sair e apagar perfil', 'account') +
    navRow('info', 'Sobre e limitações', 'O que funciona em cada aparelho', 'about') + '</ul>' +
    '<section class="card" aria-labelledby="apk-t"><h2 id="apk-t">' + ic('down') + 'Tem Android?</h2><p class="muted">O Foquinho também existe como aplicativo para instalar. No iPhone, use esta versão pelo Safari: Compartilhar → Adicionar à Tela de Início.</p>' +
    '<a class="btn block" id="l-apk" href="https://github.com/pausa029/foquinho/releases/latest/download/Foquinho.apk" target="_blank" rel="noopener">' + ic('down') + '<span>Baixar o app para Android (APK)</span></a></section>' +
    (S.demo ? '' : '<div class="row-btns">' + btn('Ver demonstração', 'demoOn', { cls: 'ghost', icon: 'demo' }) + '</div>');
};

SCREENS.prefs = function () {
  var d = S.data;
  return '<p class="lead">Tudo aqui é opcional e pode ser mudado a qualquer momento.</p>' +
    '<section class="card" aria-labelledby="pf-s"><h2 id="pf-s">' + ic('ball') + 'Esportes e exercícios</h2>' + sportsEditor(d) + '</section>' +
    '<section class="card" aria-labelledby="pf-m"><h2 id="pf-m">' + ic('book') + 'Matérias</h2>' + subjectsEditor(d) + '</section>' +
    '<section class="card" aria-labelledby="pf-p"><h2 id="pf-p">' + ic('cal') + 'Provas</h2>' + examsEditor(d) + '</section>' +
    '<div class="row-btns">' + btn('Apagar todas as preferências', 'askClearPrefs', { cls: 'ghost', icon: 'trash' }) + '</div>';
};

function daysText(days) {
  if (days.length === 7) return 'todos os dias';
  if (days.length === 5 && days.indexOf(5) < 0 && days.indexOf(6) < 0) return 'de segunda a sexta';
  if (days.length === 2 && days.indexOf(5) >= 0 && days.indexOf(6) >= 0) return 'sábado e domingo';
  if (!days.length) return 'nenhum dia';
  return days.slice().sort().map(function (n) { return WD_SHORT[n]; }).join(', ');
}
function remindersBlock(d) {
  var h = '<section class="card" aria-labelledby="gl-r"><h2 id="gl-r">' + ic('bell') + 'Lembretes</h2>' + switchRow('remOn', 'Lembretes ativados', '', d.rem.on);
  if (d.rem.on) {
    h += now() < d.rem.pausedUntil ?
      '<p class="status near">' + ic('info', 'sm') + '<span>Em silêncio até ' + fmtClock(d.rem.pausedUntil) + (dayKey(new Date(d.rem.pausedUntil)) !== dayKey() ? ' de amanhã' : '') + '.</span></p><div class="row-btns">' + btn('Reativar agora', 'unmute', { cls: 'small' }) + '</div>' :
      '<div class="row-btns">' + btn('Silenciar por 1 hora', 'mute', { v: '60', cls: 'small ghost' }) + btn('Silenciar até amanhã', 'mute', { v: 'amanha', cls: 'small ghost' }) + '</div>';
  }
  h += d.rem.list.length ? '<ul class="list">' + d.rem.list.map(function (r, i) {
    return '<li class="li"><div class="li-main"><p class="li-t" id="lb-rem-' + i + '">' + esc(r.label) + '</p><p class="li-d">' + r.time + ' · ' + esc(daysText(r.days)) + ' · ' + esc(remStatusToday(d, r)) + '</p></div>' +
      '<button type="button" class="switch sm' + (r.on ? ' on' : '') + '" role="switch" aria-checked="' + (r.on ? 'true' : 'false') + '" id="rem-sw-' + i + '" data-act="remToggle" data-v="' + esc(r.id) + '" aria-labelledby="lb-rem-' + i + '"><span class="knob" aria-hidden="true"></span></button>' +
      '<button type="button" class="icon-btn" id="rem-ed-' + i + '" data-act="editRem" data-v="' + esc(r.id) + '" aria-label="Editar lembrete: ' + esc(r.label) + '">' + ic('edit') + '</button></li>';
  }).join('') + '</ul>' : '<p class="empty">Nenhum lembrete criado.</p>';
  h += '<p class="chips-label">Adicionar lembrete</p><div class="wrap">' +
    [['estudo', 'Estudo'], ['exercicio', 'Exercício'], ['refeicao', 'Refeição sem celular'], ['dormir', 'Hora de dormir'], ['outro', 'Outro']].map(function (k) {
      return '<button type="button" class="chip plain" id="c-addrem-' + k[0] + '" data-act="addRem" data-v="' + k[0] + '">' + ic('plus', 'sm') + '<span>' + k[1] + '</span></button>';
    }).join('') + '</div>';
  h += switchRow('quiet', 'Período sem avisos', 'Nenhum lembrete aparece nesse intervalo.', d.rem.quiet.on) +
    (d.rem.quiet.on ? '<div class="two">' + timeInput('q-from', 'Começa às', d.rem.quiet.from, 'q-from') + timeInput('q-to', 'Termina às', d.rem.quiet.to, 'q-to') + '</div>' : '');
  h += notice('Os lembretes aparecem com o Foquinho aberto. Cada um toca uma vez por dia e pode ser adiado ou silenciado.') + notifBox();
  return h + '</section>';
}
SCREENS.goals = function () {
  var d = S.data, g = d.goals, h = '';
  h += '<section class="card" aria-labelledby="gl-d"><h2 id="gl-d">' + ic('target') + '1. Meta diária de tempo de tela</h2>' +
    '<p class="muted">Quanto tempo de celular, no total, você quer tentar por dia.</p>';
  if (g.dailyMin == null) h += '<div class="row-btns">' + btn('Definir uma meta', 'setGoalDefault', { v: 300, cls: 'primary' }) + '</div>';
  else {
    h += '<div class="goal-pick">' + stepper('goal', fmtMin(g.dailyMin), 'meta diária de tempo de tela') + '</div><p class="muted">Ajuste de 15 em 15 minutos. ' + link('Remover a meta', 'clearGoal') + '</p>' +
      switchRow('byDay', 'Metas diferentes por dia', 'Por exemplo, mais tempo no fim de semana.', g.byDay.on);
    if (g.byDay.on) {
      h += WD_LONG.map(function (nm, i) {
        var v = g.byDay.min[i] != null ? g.byDay.min[i] : g.dailyMin;
        return setting('gd' + i, nm.charAt(0).toUpperCase() + nm.slice(1), '', stepper('gd' + i, fmtMin(v), 'meta de ' + nm));
      }).join('');
    }
    h += switchRow('gradual', 'Redução gradual', 'Toda semana o Foquinho sugere uma meta um pouco menor. Você aceita ou mantém.', g.gradual.on);
    if (g.gradual.on) {
      h += setting('gstep', 'Passo por semana', '', stepper('gstep', g.gradual.step + ' min', 'minutos a menos por semana')) +
        setting('gfloor', 'Nunca sugerir menos que', '', stepper('gfloor', fmtMin(g.gradual.floor), 'limite mínimo da meta'));
    }
  }
  h += notice('A meta é um objetivo, não uma obrigação. O Foquinho nunca bloqueia nada e não repreende quando ela é ultrapassada.') + '</section>';

  var sm = g.sessionMin, isCustom = sm != null && [60, 90, 120].indexOf(sm) < 0;
  h += '<section class="card" aria-labelledby="gl-s"><h2 id="gl-s">' + ic('clock') + '2. Lembrete após uso contínuo</h2>' +
    '<p class="muted">Diferente da meta do dia: é um aviso para parar um pouco depois de muito tempo seguido.</p>' +
    chipRow('Avisar depois de', [['off', 'Desligado'], ['60', '60 min'], ['90', '90 min'], ['120', '120 min'], ['x', 'Outro']], 'sessMin', sm == null ? 'off' : (isCustom || S.tmp.sessCustom ? 'x' : String(sm))) +
    ((isCustom || S.tmp.sessCustom) && sm != null ? '<div class="field narrow"><label for="sess-min">Minutos (de 5 a 480)</label><input class="input" id="sess-min" name="sess-min" type="number" inputmode="numeric" min="5" max="480" value="' + sm + '" data-change="sessInput" data-keep></div>' : '') +
    notice('Um navegador não consegue acompanhar seu uso em outros apps. Por isso a contagem começa quando você toca em “Iniciar contagem” no Início.') +
    notice('Escolher apps ou categorias para reduzir também não é possível aqui, porque o navegador não identifica os apps do aparelho. ' + link('Ver como fazer isso no próprio celular', 'nav', 'native', 'l-native-goals')) + '</section>';

  h += '<section class="card" aria-labelledby="gl-w"><h2 id="gl-w">' + ic('check') + 'Metas semanais de estudo e exercício</h2>' +
    switchRow('studyWeek', 'Meta de estudo por semana', '', g.studyWeek != null) +
    (g.studyWeek != null ? '<div class="goal-pick">' + stepper('studyWeek', fmtMin(g.studyWeek), 'minutos de estudo por semana') + '</div>' : '') +
    switchRow('moveWeek', 'Meta de exercício por semana', '', g.moveWeek != null) +
    (g.moveWeek != null ? '<div class="goal-pick">' + stepper('moveWeek', fmtMin(g.moveWeek), 'minutos de exercício por semana') + '</div>' : '') + '</section>';

  return h + remindersBlock(d);
};

var PLAN_IDEAS = ['Beber água e alongar o corpo', 'Fazer 10 polichinelos', 'Rever 5 cartões de estudo', 'Dar uma volta rápida', 'Respirar fundo dez vezes'];
SCREENS.plan = function () {
  var d = S.data, p = S.tmp.pl || (S.tmp.pl = { min: d.plan ? d.plan.min : 5, kind: d.plan ? d.plan.kind : 'pausa' });
  return '<p class="lead">Muitas vezes a gente pega o celular sem motivo. Deixar uma alternativa escolhida ajuda a trocar na hora.</p>' +
    '<section class="card"><form data-form="plan" novalidate class="stack">' +
    field('pl-text', 'Se eu pegar o celular por hábito, eu vou…', { max: 160, value: d.plan ? d.plan.text : '', ac: 'off' }) +
    '<div class="chips"><p class="chips-label">Ideias</p><div class="wrap">' + PLAN_IDEAS.map(function (t, i) {
      return '<button type="button" class="chip plain" id="c-planidea-' + i + '" data-act="planIdea" data-v="' + esc(t) + '"><span>' + esc(t) + '</span></button>';
    }).join('') + '</div></div>' +
    chipRow('Conta como', [['pausa', 'Pausa'], ['estudo', 'Estudo'], ['exercicio', 'Exercício']], 'planKind', p.kind) +
    chipRow('Duração', [['5', '5 min'], ['10', '10 min'], ['20', '20 min']], 'planMin', String(p.min)) +
    errBox(S.tmp.err && S.tmp.err.msg) +
    btn('Salvar plano', '', { submit: true, cls: 'primary block', id: 'b-plan-save' }) + '</form>' +
    (d.plan ? btn('Apagar plano', 'delPlan', { cls: 'ghost block' }) : '') + '</section>';
};

SCREENS.challenges = function () {
  var d = S.data, wk = weekStart(dayKey()), cur = d.challenges.filter(function (c) { return c.week === wk; });
  var past = d.challenges.filter(function (c) { return c.week < wk; }).sort(function (a, b) { return a.week < b.week ? 1 : -1; }).slice(0, 6);
  var h = '<p class="lead">Desafios são só seus. Ninguém vê, não existe ranking e você pode apagar quando quiser.</p>' +
    '<section class="card" aria-labelledby="dc-a"><h2 id="dc-a">' + ic('flag') + 'Nesta semana</h2>';
  if (!cur.length) h += '<p class="empty">Nenhum desafio ativo.</p>';
  else h += '<ul class="list">' + cur.map(function (c, i) {
    var p = challengeProgress(d, c), txt = p.done + (p.unit ? ' ' + p.unit : '') + ' de ' + p.target + (p.unit ? ' ' + p.unit : '');
    return '<li class="li"><div class="li-main"><p class="li-t">' + esc(challengeLabel(c)) + (p.ok ? ' ' + tag('concluído', 'ok') : '') + '</p><p class="li-d">' + esc(txt) + '</p>' + progress(p.pct, challengeLabel(c) + ': ' + txt) + '</div>' +
      '<button type="button" class="icon-btn" id="ch-del-' + i + '" data-act="delChallenge" data-v="' + esc(c.id) + '" aria-label="Excluir desafio: ' + esc(challengeLabel(c)) + '">' + ic('trash') + '</button></li>';
  }).join('') + '</ul>';
  h += '</section>';

  var presets = CHALLENGE_PRESETS.map(function (p) { return { type: p[0], target: p[1], param: null }; });
  d.prefs.hard.slice(0, 3).forEach(function (m) { presets.push({ type: 'hardMin', target: 60, param: m }); });
  presets = presets.filter(function (p) { return !cur.some(function (c) { return c.type === p.type && c.target === p.target && (c.param || null) === p.param; }); });
  h += '<section class="card" aria-labelledby="dc-n"><h2 id="dc-n">' + ic('plus') + 'Começar um desafio</h2>';
  if (cur.length >= 4) h += '<p class="muted">Quatro desafios por semana já é bastante. Apague um para trocar.</p>';
  else h += '<div class="stack">' + presets.map(function (p, i) {
    return '<button type="button" class="btn block left" id="ch-add-' + i + '" data-act="addChallenge" data-v="' + esc(p.type + '|' + p.target + '|' + (p.param || '')) + '">' + ic('plus') + '<span>' + esc(challengeLabel(p)) + '</span></button>';
  }).join('') + '</div>';
  if (!d.goals.dailyMin) h += '<p class="muted">O desafio de ficar dentro da meta só avança nos dias em que você informar o tempo de tela e tiver uma meta definida.</p>';
  h += '</section>';

  if (past.length) {
    h += '<section class="card" aria-labelledby="dc-p"><h2 id="dc-p">' + ic('clock') + 'Semanas anteriores</h2><ul class="list">' + past.map(function (c) {
      var p = challengeProgress(d, c);
      return '<li class="li"><div class="li-main"><p class="li-t">' + esc(challengeLabel(c)) + '</p><p class="li-d">Semana de ' + fmtDay(c.week) + ' · ' +
        (p.ok ? 'concluído' : 'chegou a ' + p.done + ' de ' + p.target + '. Tudo bem: dá para tentar de novo.') + '</p></div></li>';
    }).join('') + '</ul><div class="row-btns">' + btn('Apagar desafios antigos', 'clearPastChallenges', { cls: 'ghost small' }) + '</div></section>';
  }
  return h;
};

SCREENS.look = function () {
  var ui = S.data.ui;
  return '<section class="card" aria-labelledby="lk-a"><h2 id="lk-a">' + ic('sun') + 'Aparência</h2>' +
    chipRow('Tema', [['auto', 'Automático'], ['light', 'Claro'], ['dark', 'Escuro']], 'theme', ui.theme) +
    chipRow('Tamanho do texto', [['0', 'Padrão'], ['1', 'Grande'], ['2', 'Muito grande']], 'font', String(ui.font)) +
    '<p class="muted">O tema automático acompanha o aparelho. O Foquinho também respeita o ajuste do sistema para reduzir animações.</p></section>' +
    '<section class="card" aria-labelledby="lk-b"><h2 id="lk-b">' + ic('bell') + 'Avisos</h2>' +
    (soundSupported() ? switchRow('sound', 'Som de aviso', 'Toca no fim do temporizador e nos lembretes.', ui.sound) + '<div class="row-btns">' + btn('Testar o som', 'testSound', { cls: 'small ghost' }) + '</div>' : notice('Este navegador não toca sons de aviso.')) +
    (vibrateSupported() ? switchRow('vibrate', 'Vibração', 'Quando o aparelho permitir.', ui.vibrate) : notice('Vibração não está disponível neste aparelho ou navegador. Os avisos aparecem na tela e com som.')) +
    (wakeSupported() ? switchRow('awake', 'Manter a tela ligada no temporizador', 'Assim o aviso sonoro consegue tocar no fim.', ui.awake) : notice('Este navegador não mantém a tela ligada. Se ela apagar durante o temporizador, o aviso sonoro não toca.')) + '</section>' +
    '<section class="card" aria-labelledby="lk-c"><h2 id="lk-c">' + ic('edit') + 'Registro pessoal</h2>' +
    switchRow('mood', 'Anotar como me sinto antes e depois', 'Opcional. É só uma anotação sua, sem diagnóstico de saúde.', ui.mood) + '</section>';
};

function capRow(ok, title, state, desc) {
  return '<li class="li cap"><span class="li-ic ' + (ok ? 'ok' : 'no') + '" aria-hidden="true">' + ic(ok ? 'check' : 'x') + '</span><div class="li-main"><p class="li-t">' + esc(title) + ' ' + tag(state, ok ? 'ok' : 'off') + '</p><p class="li-d">' + desc + '</p></div></li>';
}
SCREENS.perms = function () {
  var ns = notifState(), nOk = ns === 'granted' && !S.notifBroken;
  var nState = ns === 'unsupported' ? 'indisponível' : (nOk ? 'liberada' : (ns === 'denied' || S.notifBroken ? 'não liberada' : 'não solicitada'));
  return '<p class="lead">O Foquinho confere cada recurso neste aparelho antes de usar. O que não existe aqui aparece como indisponível, com a alternativa.</p>' +
    '<section class="card" aria-labelledby="pm-a"><h2 id="pm-a">' + ic('gear') + 'Neste aparelho</h2><ul class="list">' +
    capRow(S.storageOk, 'Guardar dados no navegador', S.storageOk ? 'disponível' : 'indisponível', S.storageOk ? 'Seus dados ficam salvos neste navegador.' : 'Este navegador bloqueou o armazenamento. O app funciona, mas nada fica salvo ao fechar a página.') +
    capRow(CRYPTO_OK, 'Proteção de senha', CRYPTO_OK ? 'disponível' : 'indisponível', CRYPTO_OK ? 'A senha é embaralhada antes de ser guardada e nunca fica em texto puro.' : 'Sem esse recurso, o perfil com senha fica desativado. Use sem conta.') +
    capRow(nOk, 'Notificações do sistema', nState, nOk ? 'Funcionam enquanto a página do Foquinho estiver aberta em alguma aba.' : 'Os lembretes aparecem dentro do app enquanto ele estiver aberto. Para avisos com o app fechado, use o despertador do celular.') +
    capRow(soundSupported(), 'Som de aviso', soundSupported() ? 'disponível' : 'indisponível', 'Toca depois que você interage com a página, por regra dos navegadores.') +
    capRow(vibrateSupported(), 'Vibração', vibrateSupported() ? 'disponível' : 'indisponível', vibrateSupported() ? 'Usada junto com o som.' : 'Em iPhones e em alguns navegadores as páginas não podem vibrar o aparelho.') +
    capRow(wakeSupported(), 'Manter a tela ligada', wakeSupported() ? 'disponível' : 'indisponível', wakeSupported() ? 'Usada só durante o temporizador, se você deixar ativada.' : 'Se a tela apagar, o tempo continua certo, mas o aviso sonoro não toca.') +
    capRow(!!S.dl, 'Salvar arquivo de exportação', S.dl ? 'disponível' : 'indisponível', S.dl ? 'O arquivo é oferecido para você salvar, com confirmação.' : 'Alternativa: o Foquinho mostra os dados em texto para copiar.') +
    '</ul>' + (ns === 'default' && !S.notifBroken ? notifBox() : '') + '</section>' +
    '<section class="card" aria-labelledby="pm-b"><h2 id="pm-b">' + ic('info') + 'Não disponível nesta versão</h2><ul class="list">' +
    capRow(false, 'Ler o tempo de tela automaticamente', 'indisponível', 'Navegadores não têm acesso a esse dado. Alternativa: você informa o número que o aparelho mostra.') +
    capRow(false, 'Detectar uso contínuo em segundo plano', 'indisponível', 'Alternativa: a contagem que você inicia no Início e os temporizadores.') +
    capRow(false, 'Bloquear ou limitar outros apps', 'indisponível', 'O Foquinho nunca bloqueia nada. Alternativa: os limites do próprio aparelho. ' + link('Ver o passo a passo', 'nav', 'native', 'l-native-perms')) +
    capRow(false, 'Escolher apps para reduzir', 'indisponível', 'O navegador não identifica os apps instalados.') +
    '</ul></section>' +
    notice('A única permissão que o Foquinho pode pedir é a de notificações, e só quando você tocar no botão.');
};

SCREENS.privacy = function () {
  return '<p class="lead">Em poucas palavras: o que você registra no Foquinho fica neste aparelho e não é enviado a ninguém.</p>' +
    '<section class="card"><h2>' + ic('down') + 'O que fica guardado</h2><ul class="bul">' +
    '<li>Seus esportes, matérias, provas, metas e lembretes.</li><li>O tempo de tela que você informar e as sessões que concluir.</li>' +
    '<li>Se criar um perfil: o nome de usuário e uma versão embaralhada da senha. A senha em si nunca é guardada.</li></ul></section>' +
    '<section class="card"><h2>' + ic('phone') + 'Onde fica</h2><ul class="bul">' +
    '<li>Só neste navegador, neste aparelho.</li><li>O Foquinho não tem servidor próprio, então não existe sincronização entre aparelhos.</li>' +
    '<li>Se você limpar os dados do navegador, os registros somem. Para guardar uma cópia, use a exportação.</li></ul></section>' +
    '<section class="card"><h2>' + ic('shield') + 'O que o Foquinho não faz</h2><ul class="bul">' +
    '<li>Não vende nem compartilha dados de uso, preferências ou perfil.</li><li>Não tem anúncios nem rastreadores no seu código.</li>' +
    '<li>Não pede e-mail, telefone, idade, localização nem nome completo.</li><li>Não lê nem controla seus outros apps.</li></ul></section>' +
    '<section class="card"><h2>' + ic('lock') + 'Sobre a senha</h2><p>A senha impede que outra pessoa abra seu perfil dentro do Foquinho. Ela não criptografa os registros guardados no navegador: alguém com o aparelho desbloqueado e conhecimento técnico conseguiria lê-los.</p></section>' +
    '<section class="card"><h2>' + ic('user') + 'Se você tem menos de 18 anos</h2><p>O Foquinho não coleta dados de ninguém, porque nada sai do aparelho. Mesmo assim, vale combinar o uso com seus responsáveis.</p></section>' +
    '<section class="card"><h2>' + ic('info') + 'Sobre a página</h2><p>Esta página é carregada pela internet a partir do claude.ai. Como em qualquer site, o servidor pode registrar que a página foi aberta, mas não recebe o que você preenche aqui.</p></section>' +
    '<div class="row-btns">' + btn('Exportar ou apagar meus dados', 'goData', { icon: 'down' }) + '</div>';
};

SCREENS.native = function () {
  return '<p class="lead">Para medir o tempo de tela e limitar apps de verdade, use os controles do próprio celular. Os nomes mudam um pouco conforme a marca e a versão.</p>' +
    '<section class="card"><h2>' + ic('phone') + 'Android</h2><ul class="bul">' +
    '<li><strong>Ver o tempo de tela:</strong> Configurações, depois Bem-estar digital e controles parentais.</li>' +
    '<li><strong>Limitar um app:</strong> no painel do Bem-estar digital, toque no app e defina um timer.</li>' +
    '<li><strong>Modo Foco:</strong> pausa os apps que você escolher enquanto estuda.</li>' +
    '<li><strong>Modo Hora de dormir:</strong> silencia o aparelho e deixa a tela em tons de cinza no horário marcado.</li></ul>' +
    '<p class="muted">Em aparelhos com Android 8 ou anterior esse menu pode não existir. O Modo Foco aparece a partir do Android 10.</p></section>' +
    '<section class="card"><h2>' + ic('phone') + 'iPhone</h2><ul class="bul">' +
    '<li><strong>Ver o tempo de tela:</strong> Ajustes, depois Tempo de Uso.</li>' +
    '<li><strong>Limitar apps:</strong> em Tempo de Uso, toque em Limites de Apps.</li>' +
    '<li><strong>Repouso:</strong> em Tempo de Uso, define horários longe da tela.</li>' +
    '<li><strong>Foco:</strong> em Ajustes, toque em Foco para silenciar avisos enquanto estuda.</li></ul>' +
    '<p class="muted">O Tempo de Uso existe a partir do iOS 12 e o Foco a partir do iOS 15. Antes disso, use o Não Perturbe.</p></section>' +
    notice('O Foquinho não ativa nenhum desses controles por você e não sabe se eles estão ligados.');
};

SCREENS.datap = function () {
  var d = S.data, nUse = Object.keys(d.usage).length;
  return '<section class="card"><h2>' + ic('info') + 'O que existe neste perfil</h2><ul class="bul">' +
    '<li>' + plural(d.sessions.length, 'sessão registrada', 'sessões registradas') + '</li><li>' + plural(nUse, 'dia com tempo de tela', 'dias com tempo de tela') + '</li>' +
    '<li>' + plural(d.prefs.exams.length, 'prova', 'provas') + ', ' + plural(d.prefs.subjects.length, 'matéria', 'matérias') + ' e ' + plural(d.prefs.sports.length, 'esporte', 'esportes') + '</li>' +
    '<li>' + plural(d.rem.list.length, 'lembrete', 'lembretes') + '</li></ul>' + (S.demo ? notice('No modo demonstração estes números são fictícios e nada é salvo.') : '') + '</section>' +
    '<section class="card"><h2>' + ic('down') + 'Exportar</h2><p class="muted">A exportação não inclui a senha. ' + (S.dl ? 'O arquivo é oferecido para você salvar.' : 'Neste navegador o Foquinho mostra os dados em texto para você copiar.') + '</p>' +
    '<div class="row-btns">' + btn('Cópia completa (JSON)', 'exportJson') + btn('Histórico em planilha (CSV)', 'exportCsv') + '</div></section>' +
    '<section class="card"><h2>' + ic('plus') + 'Importar</h2><p class="muted">Traga de volta uma cópia completa exportada pelo Foquinho. Ela substitui os dados atuais deste perfil.</p>' +
    '<div class="row-btns">' + btn('Importar uma cópia', 'importOpen', { dis: S.demo }) + '</div></section>' +
    '<section class="card"><h2>' + ic('trash') + 'Apagar</h2><div class="stack">' +
    btn('Apagar histórico', 'askClearHistory', { cls: 'block left', id: 'b-clear-hist-2', icon: 'trash', dis: S.demo }) +
    btn('Apagar todos os dados deste perfil', 'askClearAll', { cls: 'block left', icon: 'trash', dis: S.demo }) + '</div>' +
    '<p class="muted">Apagar não tem volta. O histórico inclui as sessões e os tempos de tela informados.</p></section>';
};

SCREENS.account = function () {
  var guest = S.user.id === 'guest', prof = currentProfile();
  if (S.demo) return '<section class="card"><p>Você está no modo demonstração. Saia dele para criar ou abrir um perfil.</p><div class="row-btns">' + btn('Sair da demonstração', 'demoOff', { id: 'b-demo-off-3' }) + '</div></section>';
  if (guest) {
    return '<section class="card"><h2>' + ic('user') + 'Sem conta</h2><p>Você está usando o Foquinho sem conta. Os dados ficam neste aparelho, sem senha.</p>' +
      '<div class="stack">' + btn('Criar perfil e guardar meus dados', 'goSignup', { cls: 'primary block', id: 'b-make-profile-2' }) +
      btn('Voltar à tela inicial', 'signOut', { cls: 'block' }) + btn('Apagar meus dados deste aparelho', 'askClearAll', { cls: 'ghost block', id: 'b-clear-all-2' }) + '</div>' +
      '<p class="muted">Voltar à tela inicial não apaga nada: é só tocar em “Continuar sem conta” para retomar.</p></section>';
  }
  var dt = prof ? new Date(prof.createdAt) : new Date();
  return '<section class="card"><h2>' + ic('user') + esc(S.user.name) + '</h2><p class="muted">Perfil local criado em ' + pad2(dt.getDate()) + '/' + pad2(dt.getMonth() + 1) + '/' + dt.getFullYear() + '. Ele existe só neste aparelho e não sincroniza com outros.</p>' +
    '<div class="stack">' + btn('Alterar senha', 'pwdOpen', { cls: 'block', icon: 'lock' }) + btn('Sair', 'signOut', { cls: 'block' }) +
    btn('Apagar perfil e dados', 'delProfileOpen', { cls: 'ghost block', icon: 'trash' }) + '</div>' +
    notice('Não existe recuperação de senha, porque o Foquinho não pede e-mail. Se esquecer, a saída é apagar o perfil na tela de entrada.') + '</section>';
};

SCREENS.about = function () {
  return '<section class="card"><h2>' + ic('info') + 'Foquinho ' + APP_VERSION + ', versão web</h2><p>Um app para trocar parte do tempo de celular por estudo e exercício. Esta versão roda no navegador, no Android e no iPhone, sem instalar nada.</p></section>' +
    '<section class="card"><h2>' + ic('check') + 'Funciona em qualquer aparelho</h2><ul class="bul">' +
    '<li>Perfil local com senha protegida ou uso sem conta.</li><li>Sugestões de estudo e exercício feitas com suas matérias, provas e esportes.</li>' +
    '<li>Temporizadores de pausa, foco e estudo com intervalos.</li><li>Metas manuais, histórico, resumo semanal e desafios.</li>' +
    '<li>Lembretes com o app aberto.</li></ul></section>' +
    '<section class="card"><h2>' + ic('gear') + 'Depende do aparelho</h2><ul class="bul">' +
    '<li>Vibração: comum no Android, indisponível para páginas no iPhone.</li><li>Manter a tela ligada: navegadores recentes.</li>' +
    '<li>Notificações do sistema: só onde o navegador libera para páginas, e apenas com a página aberta.</li></ul>' +
    '<p>' + link('Ver o que este aparelho permite', 'nav', 'perms', 'l-perms-about') + '</p></section>' +
    '<section class="card"><h2>' + ic('x') + 'Fora desta versão</h2><ul class="bul">' +
    '<li><strong>Tempo de tela automático.</strong> No Android exige um app instalado com o “Acesso a dados de uso”, liberado pela pessoa nas configurações. No iPhone depende das APIs de Tempo de Uso da Apple, que exigem autorização especial e aprovação da Apple.</li>' +
    '<li><strong>Bloqueio de apps.</strong> Só com os mesmos recursos nativos. O Foquinho indica os controles do próprio aparelho.</li>' +
    '<li><strong>Lembretes com o app fechado.</strong> Precisam de um app instalado.</li>' +
    '<li><strong>Arquivos de instalação.</strong> APK e AAB são formatos do Android e não foram gerados nesta versão. No iPhone a distribuição é feita pela App Store ou pelo TestFlight.</li></ul></section>' +
    '<section class="card"><h2>' + ic('phone') + 'Onde foi testado</h2><p>Chrome 153 em modo de celular, em telas de 320, 360 e 412 px de largura, nos temas claro e escuro e com texto ampliado. Não foi testado em aparelhos físicos, nem no Safari do iPhone.</p></section>';
};

/* ---------- janelas (folhas que sobem da base da tela) ---------- */
MODALS.usage = function (m) {
  var d = S.data, u = d.usage[m.day], isToday = m.day === dayKey();
  return {
    title: isToday ? 'Tempo de tela de hoje' : 'Tela: ' + fmtDayLong(m.day),
    body: '<form data-form="usage" novalidate class="stack"><p class="muted">Copie o número que o seu celular mostra.</p>' +
      '<details class="det"><summary>Onde encontro esse número?</summary><p><strong>Android:</strong> Configurações, depois Bem-estar digital e controles parentais.</p><p><strong>iPhone:</strong> Ajustes, depois Tempo de Uso.</p></details>' +
      '<div class="two">' + field('us-h', 'Horas', { type: 'number', mode: 'numeric', min: 0, maxv: 24, value: u ? Math.floor(u.min / 60) : '' }) +
      field('us-m', 'Minutos', { type: 'number', mode: 'numeric', min: 0, maxv: 59, value: u ? u.min % 60 : '' }) + '</div>' +
      (isToday ? notice('O dia ainda não terminou, então o valor fica marcado como parcial. Você pode atualizar depois.') : '') + errBox(m.err) +
      btn('Salvar', '', { submit: true, cls: 'primary block', id: 'b-usage-save' }) + (u ? btn('Apagar o registro deste dia', 'delUsage', { v: m.day, cls: 'ghost block' }) : '') + '</form>'
  };
};
MODALS.whereUsage = function () {
  return {
    title: 'Onde ver o tempo de tela',
    body: '<div class="stack"><p><strong>Android:</strong> abra Configurações e toque em Bem-estar digital e controles parentais. O total do dia aparece no topo.</p>' +
      '<p><strong>iPhone:</strong> abra Ajustes e toque em Tempo de Uso. A média e o total do dia aparecem no topo.</p>' +
      '<p class="muted">Os nomes mudam um pouco conforme a marca e a versão. Em aparelhos Android antigos esse menu pode não existir.</p>' +
      btn('Ver todos os controles do aparelho', 'nav', { v: 'native', cls: 'block', id: 'b-native-where' }) + '</div>'
  };
};
MODALS.confirm = function (m) {
  return { title: m.title, body: '<div class="stack"><p>' + esc(m.text) + '</p>' + btn(m.yes, 'confirmYes', { cls: (m.danger ? 'danger' : 'primary') + ' block' }) + btn('Cancelar', 'closeModal', { cls: 'ghost block', id: 'b-cancel' }) + '</div>' };
};
MODALS.alert = function (m) {
  return {
    title: m.a.title,
    body: '<div class="stack"><p>' + esc(m.a.text) + '</p>' + m.a.actions.map(function (x, i) {
      return btn(x[0], x[1], { cls: (i === 0 ? 'primary ' : (x[1] === 'closeModal' ? 'ghost ' : '')) + 'block', id: 'b-alert-' + i });
    }).join('') + '</div>'
  };
};
MODALS.surprise = function (m) {
  var a = actById(S.data, m.id);
  return { title: 'Que tal esta?', body: '<div class="stack">' + (a ? actCard(a, { sfx: '-m' }) : '<p class="empty">Essa atividade não está mais disponível.</p>') + btn('Outra surpresa', 'surprise', { cls: 'block', icon: 'dice', id: 'b-surprise-again' }) + '</div>' };
};
MODALS.pickAct = function (m) {
  var d = S.data, list = rankActs(filterActs(buildActivities(d), { kind: m.kind }), d).slice(0, 16);
  return {
    title: m.kind === 'estudo' ? 'Atividades de estudo' : 'Atividades de exercício',
    body: '<ul class="list pick">' + list.map(function (a, i) {
      return '<li><button type="button" class="nav-row" id="pick-' + i + '" data-act="choosePick" data-v="' + esc(a.id) + '"><span class="li-main"><span class="li-t">' + esc(a.title) + '</span><span class="li-d">' + esc(a.min + ' min · ' + PLACE_LABEL[a.place] + ' · ' + ENERGY_LABEL[a.energy]) + '</span></span>' + ic('right', 'sm') + '</button></li>';
    }).join('') + '</ul>'
  };
};
MODALS.mood0 = function () {
  return {
    title: 'Como você está agora?',
    body: '<div class="stack"><p class="muted">Opcional. É só um registro seu, não é avaliação de saúde.</p>' +
      MOODS.map(function (x) { return btn(x[1], 'mood0', { v: String(x[0]), cls: 'block' }); }).join('') + btn('Pular', 'mood0', { v: '0', cls: 'ghost block', id: 'b-mood-skip' }) + '</div>'
  };
};
MODALS.exam = function (m) {
  var d = S.data, e = null;
  if (m.id) for (var i = 0; i < d.prefs.exams.length; i++) if (d.prefs.exams[i].id === m.id) e = d.prefs.exams[i];
  var mine = d.prefs.subjects.slice(), others = SUBJECTS.filter(function (s) { return mine.indexOf(s) < 0; });
  if (e && mine.indexOf(e.subject) < 0 && others.indexOf(e.subject) < 0) mine.push(e.subject);
  var opts = mine.concat(others).map(function (s) { return [s, s]; });
  return {
    title: e ? 'Editar prova' : 'Nova prova',
    body: '<form data-form="exam" novalidate class="stack">' + selectField('ex-subj', 'Matéria', opts, e ? e.subject : (mine[0] || others[0])) +
      field('ex-topic', 'Assunto da prova (opcional)', { max: 80, value: e ? e.topic : '', ph: 'Ex.: equações do 2º grau', ac: 'off' }) +
      field('ex-date', 'Data (opcional)', { type: 'date', value: e && e.date ? e.date : '' }) + errBox(m.err) +
      btn(e ? 'Salvar' : 'Adicionar prova', '', { submit: true, cls: 'primary block', id: 'b-exam-save' }) + '</form>'
  };
};
var REM_PRESET = {
  estudo: ['Hora de estudar', '19:00', [0, 1, 2, 3, 4]], exercicio: ['Hora de se mexer', '17:00', [0, 1, 2, 3, 4, 5, 6]],
  refeicao: ['Refeição sem celular', '12:00', [0, 1, 2, 3, 4, 5, 6]], dormir: ['Celular longe na hora de dormir', '22:00', [0, 1, 2, 3, 4, 5, 6]], outro: ['', '18:00', [0, 1, 2, 3, 4, 5, 6]]
};
MODALS.rem = function (m) {
  return {
    title: m.id ? 'Editar lembrete' : 'Novo lembrete',
    body: '<form data-form="rem" novalidate class="stack">' + field('rm-label', 'Nome do lembrete', { max: 60, value: m.label, ac: 'off' }) +
      '<div class="field time"><label for="rm-time">Horário</label><input class="input" type="time" id="rm-time" name="rm-time" value="' + esc(m.time) + '" data-keep></div>' +
      '<div class="chips"><p class="chips-label" id="g-remday">Dias da semana</p><div class="wrap" role="group" aria-labelledby="g-remday">' +
      WD_SHORT.map(function (w, i) { return chip(w, 'remDay', i, m.days.indexOf(i) >= 0); }).join('') + '</div></div>' + errBox(m.err) +
      btn('Salvar lembrete', '', { submit: true, cls: 'primary block', id: 'b-rem-save' }) + (m.id ? btn('Excluir lembrete', 'delRem', { v: m.id, cls: 'ghost block', icon: 'trash' }) : '') + '</form>'
  };
};
MODALS.newAct = function (m) {
  return {
    title: 'Criar atividade',
    body: '<form data-form="newAct" novalidate class="stack">' + field('na-title', 'O que você vai fazer?', { max: 80, ac: 'off', ph: 'Ex.: treinar saque de vôlei' }) +
      chipRow('Tipo', [['estudo', 'Estudo'], ['exercicio', 'Exercício']], 'naKind', m.kind) +
      field('na-min', 'Duração em minutos', { type: 'number', mode: 'numeric', min: 1, maxv: 240, value: 10 }) +
      selectField('na-place', 'Local', [['q', 'Em qualquer lugar'], ['c', 'Em casa'], ['f', 'Ao ar livre'], ['l', 'No seu local de treino']], 'q') +
      selectField('na-energy', 'Energia', [['t', 'Tranquilo'], ['m', 'Moderado'], ['a', 'Ativo']], 't') + errBox(m.err) +
      btn('Criar atividade', '', { submit: true, cls: 'primary block', id: 'b-newact-save' }) + '</form>'
  };
};
MODALS.exportText = function (m) {
  return {
    title: m.name,
    body: '<div class="stack"><p class="muted">Este navegador não deixa a página salvar arquivos. Copie o texto abaixo e guarde onde preferir.</p>' +
      '<label class="sr" for="ex-text">Dados exportados</label><textarea class="input area" id="ex-text" readonly rows="8">' + esc(m.text) + '</textarea>' +
      btn('Copiar', 'copyExport', { cls: 'primary block' }) + '</div>'
  };
};
MODALS.importData = function (m) {
  return {
    title: 'Importar uma cópia',
    body: '<form data-form="importData" novalidate class="stack"><p class="muted">Escolha o arquivo JSON exportado pelo Foquinho ou cole o conteúdo dele.</p>' +
      '<div class="field"><label for="im-file">Arquivo JSON</label><input class="input" type="file" id="im-file" accept=".json,application/json,text/plain" data-change="importFile"></div>' +
      '<div class="field"><label for="im-text">Ou cole o conteúdo aqui</label><textarea class="input area" id="im-text" name="im-text" rows="6" data-keep></textarea></div>' +
      notice('Importar substitui todos os dados atuais deste perfil.', 'warn') + errBox(m.err) +
      btn('Importar e substituir', '', { submit: true, cls: 'primary block', id: 'b-import-go' }) + '</form>'
  };
};
MODALS.pwd = function (m) {
  var busy = !!m.busy;
  return {
    title: 'Alterar senha',
    body: '<form data-form="pwd" novalidate class="stack">' + field('pw-cur', 'Senha atual', { type: 'password', max: 72, ac: 'current-password', dis: busy }) +
      field('pw-new', 'Nova senha', { type: 'password', max: 72, ac: 'new-password', hint: 'Pelo menos 6 caracteres.', dis: busy }) +
      field('pw-new2', 'Repita a nova senha', { type: 'password', max: 72, ac: 'new-password', dis: busy }) + pwToggle('pw-cur,pw-new,pw-new2') + errBox(m.err) +
      (busy ? '<p class="loading" role="status">' + ic('lock') + '<span>Protegendo a nova senha…</span></p>' : '') +
      btn('Salvar nova senha', '', { submit: true, cls: 'primary block', id: 'b-pwd-save', dis: busy }) + '</form>'
  };
};
MODALS.delProfile = function (m) {
  var busy = !!m.busy;
  return {
    title: 'Apagar perfil e dados',
    body: '<form data-form="delProfile" novalidate class="stack"><p>Isso apaga o perfil <strong>' + esc(S.user.name) + '</strong> e tudo o que está guardado nele neste aparelho. Não tem volta.</p>' +
      field('dp-pass', 'Digite sua senha para confirmar', { type: 'password', max: 72, ac: 'current-password', dis: busy }) + errBox(m.err) +
      (busy ? '<p class="loading" role="status">' + ic('lock') + '<span>Conferindo a senha…</span></p>' : '') +
      btn('Apagar perfil e dados', '', { submit: true, cls: 'danger block', id: 'b-delprofile-go', dis: busy }) + btn('Cancelar', 'closeModal', { cls: 'ghost block', id: 'b-cancel' }) + '</form>'
  };
};
MODALS.forgot = function (m) {
  var profs = S.device.profiles;
  if (!profs.length) return { title: 'Esqueci a senha', body: '<p>Não há perfis neste aparelho.</p>' };
  return {
    title: 'Esqueci a senha',
    body: '<form data-form="forgot" novalidate class="stack"><p>O Foquinho não pede e-mail, então não há como recuperar a senha. O que dá para fazer é apagar o perfil e os dados dele deste aparelho, e começar de novo.</p>' +
      selectField('fg-prof', 'Perfil', profs.map(function (p) { return [p.id, p.name]; }), profs[0].id) +
      field('fg-name', 'Para confirmar, digite o nome do perfil', { max: 20, nocap: true, ac: 'off' }) + errBox(m.err) +
      btn('Apagar este perfil', '', { submit: true, cls: 'danger block', id: 'b-forgot-go' }) + btn('Cancelar', 'closeModal', { cls: 'ghost block', id: 'b-cancel' }) + '</form>'
  };
};
