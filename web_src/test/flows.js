const { chromium } = require('/opt/npm-tools/node_modules/playwright');
const path = require('path');
const url = 'file://' + path.resolve('/home/claude/pausa/dist/test.html');
const fails = [];
function check(name, ok, extra) { console.log((ok ? 'OK   ' : 'FAIL ') + name + (extra ? '  ' + extra : '')); if (!ok) fails.push(name); }

(async () => {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 360, height: 740 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true, locale: 'pt-BR' });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto(url);
  const txt = async () => (await page.textContent('#root')) || '';
  const hasText = async (s) => (await txt()).includes(s);
  const click = async (sel) => { await page.click(sel); await page.waitForTimeout(60); };
  const noHScroll = async (label) => {
    const r = await page.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth, vsw: document.getElementById('view') ? document.getElementById('view').scrollWidth : 0, vcw: document.getElementById('view') ? document.getElementById('view').clientWidth : 0 }));
    check('sem scroll horizontal: ' + label, r.sw <= r.cw && r.vsw <= r.vcw + 1, JSON.stringify(r));
  };

  check('tela de boas-vindas', await hasText('Menos tela.'));
  await noHScroll('boas-vindas');
  await page.screenshot({ path: 'test/shot-welcome.png' });

  // sem conta
  await click('#b-goSignup');
  check('tela de começo', await hasText('Como você quer começar?'));
  await click('#b-guest');
  check('onboarding passo 1', await hasText('Passo 1 de 5'));
  await click('#c-sport-futebol'); await click('#c-sport-corrida');
  await click('#b-obNext');
  await click('#c-subject-matematica'); await click('#c-subject-historia');
  check('dificuldade aparece', await hasText('mais dificuldade'));
  await click('#c-hard-matematica');
  await click('#b-obNext');
  await click('#b-addExam');
  await page.selectOption('#ex-subj', 'Matemática');
  await page.fill('#ex-topic', 'Equações');
  const d = new Date(); d.setDate(d.getDate() + 3);
  await page.fill('#ex-date', d.toISOString().slice(0, 10));
  await click('#b-exam-save');
  check('prova adicionada', await hasText('Equações'));
  await click('#b-obNext');
  await click('#c-usual-4a6');
  check('sugestão de meta', await hasText('4h30'));
  await click('[id^="b-setGoalDefault"]');
  check('meta definida', await hasText('4h30'));
  await click('#st-goal-m');
  check('meta diminuiu', await hasText('4h15'));
  await click('#b-obNext');
  await click('#sw-obStudy');
  check('lembrete estudo', await hasText('Horário do estudo'));
  await noHScroll('onboarding passo 5');
  await click('#b-obNext');
  check('painel principal', await hasText('Tempo de tela hoje'));
  check('sugestão personalizada', await hasText('Matemática'));
  await page.screenshot({ path: 'test/shot-home.png', fullPage: false });
  await noHScroll('home');

  // informar tempo de tela
  await click('[id^="b-logUsage"]');
  await page.fill('#us-h', '3'); await page.fill('#us-m', '10');
  await click('#b-usage-save');
  check('tela registrada', await hasText('3h10'));
  check('porcentagem', /\d+% da meta/.test(await txt()));

  // temporizador
  await click('#qa-pause');
  check('timer rodando', await hasText('Pausa longe da tela'));
  await page.waitForTimeout(2300);
  const t1 = await page.textContent('#tk-time');
  check('relógio conta', t1 && t1 !== '05:00', t1);
  await click('#b-tPause'); check('pausado', await hasText('Continuar'));
  await click('#b-tResume');
  // acelera: termina manualmente via encerrar
  await click('#b-tStop'); check('confirmação encerrar', await hasText('Encerrar agora?'));
  await click('#b-confirmYes');
  check('tela de conclusão', await hasText('Sessão encerrada'));
  await click('#st-done-p'); await click('#st-done-p');
  await click('#b-tSave');
  check('voltou ao início com registro', await hasText('Registrado') || await hasText('Hoje fora da tela'));

  // forçar fim do timer via relógio
  await page.evaluate(() => { timerStart({ kind: 'estudo', min: 1, title: 'teste', subject: 'Matemática' }); S.data.timer.endsAt = Date.now() - 10; render(); });
  await page.waitForTimeout(1300);
  check('timer concluído automaticamente', await hasText('Tempo concluído'));
  await page.evaluate(() => { timerSave(1, null); render(); });
  const st = await page.evaluate(() => dayStats(S.data, dayKey()));
  check('estudo contabilizado', st.study >= 1 && st.pause >= 1, JSON.stringify({ study: st.study, pause: st.pause }));

  // lembrete disparado
  await page.evaluate(() => {
    const d = S.data; const n = new Date(); const hm = String(n.getHours()).padStart(2, '0') + ':' + String(n.getMinutes()).padStart(2, '0');
    d.rem.list.push({ id: 'tst', label: 'Teste lembrete', kind: 'estudo', time: hm, days: [0, 1, 2, 3, 4, 5, 6], on: true }); d.rem.quiet.on = false; save(); lastRemTick = 0; tick();
  });
  await page.waitForTimeout(200);
  check('lembrete apareceu como janela', await hasText('Lembrete das'));
  await click('[id="b-alert-1"]'); // adiar
  check('adiado', (await page.textContent('#toast')).includes('adiado'));

  // atividades e filtros
  await click('#tab-acts');
  check('lista de atividades', await hasText('atividades'));
  await click('#c-filter-dur-5');
  const cnt = await page.textContent('.count');
  check('filtro 5 min', /\d+ atividade/.test(cnt), cnt);
  await click('#b-surprise');
  check('surpreenda-me', await hasText('Que tal esta?'));
  await click('#m-close');
  await click('[id^="af-"]');
  const favTxt = await txt();
  check('favoritou', favTxt.includes('Favorita'));
  await click('#b-newAct');
  await page.fill('#na-title', 'Treinar saque'); await click('#c-naKind-exercicio');
  await click('#b-newact-save');
  check('atividade criada', await hasText('Treinar saque'));
  await noHScroll('atividades');
  await page.screenshot({ path: 'test/shot-acts.png' });

  // histórico
  await click('#tab-hist');
  check('histórico', await hasText('Resumo da semana'));
  check('gráfico tela', await page.$('.chart') !== null);
  await noHScroll('histórico');
  await page.screenshot({ path: 'test/shot-hist.png' });

  // metas tela
  await click('#tab-more'); await click('#nav-goals');
  check('metas', await hasText('1. Meta diária'));
  await click('#c-sessMin-90');
  check('sessão 90', await page.evaluate(() => S.data.goals.sessionMin === 90));
  await noHScroll('metas');

  // editar hobbies -> prefs
  await click('#b-back'); await click('#nav-prefs');
  await click('#c-sport-volei');
  check('esporte editado', await page.evaluate(() => S.data.prefs.sports.includes('volei')));
  await page.fill('#sb-new', 'Astronomia'); await click('#b-add-subject');
  check('matéria própria', await page.evaluate(() => S.data.prefs.subjects.includes('Astronomia')));

  // persistência: recarregar
  await page.reload(); await page.waitForTimeout(300);
  check('persistiu após reload', await hasText('Tempo de tela hoje') && await page.evaluate(() => S.data.prefs.subjects.includes('Astronomia')));

  // criar perfil migrando dados
  await click('#tab-more'); await click('#b-make-profile');
  await page.fill('#su-name', 'Luiz'); await page.fill('#su-pass', 'segredo1'); await page.fill('#su-pass2', 'segredo1');
  await click('#b-signup');
  await page.waitForFunction(() => !S.tmp.busy, null, { timeout: 15000 });
  await page.waitForTimeout(100);
  check('perfil criado e dados migrados', await hasText('Oi, Luiz') && await page.evaluate(() => S.data.prefs.subjects.includes('Astronomia')));
  const stored = await page.evaluate(() => localStorage.getItem('pausa+.v1.device'));
  check('senha não em texto puro', !stored.includes('segredo1') && stored.includes('"hash"'));
  check('dados de guest removidos', await page.evaluate(() => localStorage.getItem('pausa+.v1.data.guest') === null));

  // sair e entrar
  await click('#tab-more'); await click('#nav-account'); await click('#b-signOut');
  check('saiu', await hasText('Menos tela.'));
  await click('#b-goLogin');
  await click('#c-pickProfile-luiz');
  await page.fill('#li-pass', 'errada1'); await click('#b-login');
  await page.waitForFunction(() => !S.tmp.busy, null, { timeout: 15000 }); await page.waitForTimeout(100);
  check('senha errada rejeitada', await hasText('incorretos'));
  await page.fill('#li-pass', 'segredo1'); await click('#b-login');
  await page.waitForFunction(() => !S.tmp.busy, null, { timeout: 15000 }); await page.waitForTimeout(100);
  check('login ok', await hasText('Oi, Luiz'));

  // alterar senha
  await click('#tab-more'); await click('#nav-account'); await click('#b-pwdOpen');
  await page.fill('#pw-cur', 'segredo1'); await page.fill('#pw-new', 'novasenha2'); await page.fill('#pw-new2', 'novasenha2');
  await click('#b-pwd-save');
  await page.waitForFunction(() => !S.modal || !S.modal.busy, null, { timeout: 15000 }); await page.waitForTimeout(100);
  check('senha alterada', (await page.textContent('#toast')).includes('alterada'));

  // exportar (sem capacidade -> texto)
  await click('#b-back'); await click('#nav-datap'); await click('#b-exportJson');
  check('exportação em texto', await hasText('Copie o texto'));
  await click('#m-close');

  // modo demo
  await click('#tab-more'); await click('#b-demoOn');
  check('demo', await hasText('Modo demonstração') && await hasText('fictício'));
  await click('#tab-hist'); await noHScroll('histórico demo');
  await page.screenshot({ path: 'test/shot-demo-hist.png' });
  await click('#tab-home');
  await page.screenshot({ path: 'test/shot-demo-home.png' });
  await click('#b-demo-off');
  check('saiu da demo', await hasText('Oi, Luiz'));

  // apagar histórico e tudo
  await click('#tab-hist'); await click('#b-askClearHistory'); await click('#b-confirmYes');
  check('histórico apagado', await page.evaluate(() => S.data.sessions.length === 0 && Object.keys(S.data.usage).length === 0));
  await click('#tab-more'); await click('#nav-account'); await click('#b-delProfileOpen');
  await page.fill('#dp-pass', 'novasenha2'); await click('#b-delprofile-go');
  await page.waitForFunction(() => !S.modal, null, { timeout: 15000 }); await page.waitForTimeout(100);
  check('perfil apagado', await hasText('Menos tela.') && await page.evaluate(() => S.device.profiles.length === 0 && localStorage.length <= 1));

  // dark mode + fonte grande + 320px
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.setViewportSize({ width: 320, height: 640 });
  await click('#b-demoOn');
  await page.evaluate(() => { S.data.ui.font = 2; render(); });
  await noHScroll('home 320px escuro fonte grande');
  await page.screenshot({ path: 'test/shot-dark-320.png' });
  await page.evaluate(() => { S.modal = null; S.alerts = []; render(); });
  await click('#tab-timer'); await noHScroll('timer 320px');
  await click('#tab-hist'); await noHScroll('hist 320px');
  await click('#tab-more'); await click('#nav-goals'); await noHScroll('goals 320px');

  // sem storage
  const ctx2 = await browser.newContext({ viewport: { width: 360, height: 740 } });
  await ctx2.addInitScript(() => { Object.defineProperty(window, 'localStorage', { get() { throw new Error('blocked'); } }); });
  const p2 = await ctx2.newPage(); p2.on('pageerror', e => errors.push('p2 ' + e.message));
  await p2.goto(url); await p2.waitForTimeout(300);
  check('sem storage: banner', (await p2.textContent('#root')).includes('não está guardando dados'));
  await p2.click('#b-goSignup'); await p2.click('#b-guest'); await p2.waitForTimeout(100);
  check('sem storage: funciona', (await p2.textContent('#root')).includes('Passo 1 de 5'));

  check('sem erros de console', errors.length === 0, errors.join(' | '));
  await browser.close();
  console.log(fails.length ? '\nFALHAS: ' + fails.length : '\nTODOS OS TESTES PASSARAM');
  process.exit(fails.length ? 1 : 0);
})().catch(e => { console.error('ERRO', e); process.exit(2); });
