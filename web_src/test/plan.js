const { chromium } = require('/opt/npm-tools/node_modules/playwright');
const url = 'file:///home/claude/pausa/dist/test.html';
const fails = []; const check = (n, ok, x) => { console.log((ok ? 'OK   ' : 'FAIL ') + n + (x ? '  ' + x : '')); if (!ok) fails.push(n); };
(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport: { width: 360, height: 740 }, isMobile: true, hasTouch: true, locale: 'pt-BR' });
  const page = await ctx.newPage(); const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto(url);
  const has = async s => ((await page.textContent('#root')) || '').includes(s);
  const click = async s => { await page.click(s); await page.waitForTimeout(80); };
  const noH = async l => { const r = await page.evaluate(() => [document.documentElement.scrollWidth, document.documentElement.clientWidth]); check('sem scroll horizontal ' + l, r[0] <= r[1], r.join('/')); };
  await click('#b-goSignup'); await click('#b-guest');
  await click('#c-sport-futebol'); await click('#b-obNext');
  await click('#c-subject-matematica'); await click('#c-subject-historia'); await click('#c-hard-matematica');
  for (let i = 0; i < 6 && !(await page.$('#tab-more')); i++) await click('#b-obNext');
  if (!(await page.$('#tab-more'))) { console.log((await page.textContent('#root')).slice(0, 300)); }
  await click('#tab-more');
  await page.click('text=Mural de estudos'); await page.waitForTimeout(100);
  check('pede disponibilidade', await has('Quando você pode estudar?'));
  await click('#b-ag-avail');
  for (const i of [0, 1, 2, 3, 4]) { await page.click('#sw-pd' + i).catch(async () => { await page.click('[id*="pd' + i + '"]'); }); await page.waitForTimeout(60); }
  check('configurado', await has('Já dá para montar o plano'));
  await noH('disponibilidade'); await page.screenshot({ path: 'test/shot-avail.png', fullPage: true });
  await click('#b-av-done');
  await click('#b-ag-next'); // semana que vem (inteira no futuro)
  await click('#b-ag-gen');
  check('prévia', await has('Prévia do plano'), (await page.textContent('.modal, [role=dialog]').catch(() => '')).slice(0, 120));
  await click('#b-agApply');
  const n = await page.$$eval('.ps', x => x.length);
  check('sessões criadas', n >= 4, 'n=' + n);
  const limit = await page.evaluate(() => { const by = {}; S.data.planSessions.forEach(p => by[p.day] = (by[p.day] || 0) + p.minutes); return Math.max(...Object.values(by)); });
  check('respeita limite diário (90) e 80% da faixa (96)', limit <= 90, 'max=' + limit);
  const wk = await page.evaluate(() => S.data.planSessions.every(p => wdIndex(p.day) < 5 && psStart(p) >= 18 * 60 && psEnd(p) <= 20 * 60));
  check('só dentro da disponibilidade', wk);
  await noH('agenda semana'); await page.screenshot({ path: 'test/shot-agenda.png', fullPage: true });
  await click('.ps'); check('janela da sessão', await has('Iniciar no temporizador'));
  await click('#b-ps-done'); await click('#b-psDoneRec');
  check('concluída e registrada', await page.evaluate(() => S.data.planSessions.filter(p => p.state === 'concluida').length === 1 && S.data.sessions.length === 1));
  // mover com conflito
  await click('.ps:nth-of-type(1)'); 
  await page.evaluate(() => { closeModal(); render && render(); });
  const ids = await page.evaluate(() => S.data.planSessions.filter(p => p.state === 'planejada').slice(0, 2).map(p => [p.id, p.day, p.start]));
  await click('#ps-' + ids[0][0]); await click('#b-ps-move');
  await page.fill('#pe-day', ids[1][1]); await page.fill('#pe-start', ids[1][2]); await click('#b-pe-save');
  check('conflito avisado', await has('bate com outra sessão'));
  check('sugere alternativas', !!(await page.$('#b-palt-0')));
  check('não deixa forçar sobreposição', !(await page.$('#b-pForce')));
  await click('#b-palt-0');
  check('movida', await page.evaluate(id => planById(S.data, id).moved, ids[0][0]));
  await click('#c-agMode-mes'); check('mês', !!(await page.$('.mgrid')));
  await noH('agenda mês'); await page.screenshot({ path: 'test/shot-agenda-mes.png', fullPage: true });
  // temporizador a partir do plano
  await click('#c-agMode-semana');
  const id2 = await page.evaluate(() => S.data.planSessions.filter(p => p.state === 'planejada')[0].id);
  await click('#ps-' + id2); await click('#b-ps-start');
  check('foi para o temporizador com a matéria', await page.evaluate(() => S.tmp.tf && !!S.tmp.tf.planId && !!S.tmp.tf.subject));
  // recarrega: dados persistem
  await page.reload(); await page.waitForTimeout(300);
  check('persistiu', await page.evaluate(() => S.data && S.data.planSessions.length >= 4 && S.data.splan.configured));
  check('sem erros JS', !errors.length, errors.join(' | '));
  console.log(fails.length ? 'FALHAS: ' + fails.length : 'TUDO OK'); await b.close();
})();
(async () => {
  const b = await chromium.launch(); const page = await (await b.newContext({ viewport: { width: 360, height: 740 }, isMobile: true })).newPage();
  const errs = []; page.on('pageerror', e => errs.push(e.message));
  await page.goto(url); const click = async s => { await page.click(s); await page.waitForTimeout(80); };
  await click('#b-goSignup'); await click('#b-guest'); await click('#b-obNext'); await click('#c-subject-matematica');
  for (let i = 0; i < 6 && !(await page.$('#tab-more')); i++) await click('#b-obNext');
  await page.evaluate(() => { const d = S.data; d.splan.days.forEach((a, i) => { a.on = true; a.from = '06:00'; a.to = '22:00'; }); d.splan.configured = true; d.prefs.exams.push({ id: 'x1', subject: 'Matemática', topic: 'Frações', date: addDays(dayKey(), 3) }); save(); go('agenda'); render(); });
  await page.waitForTimeout(100);
  const t = await page.textContent('#root');
  console.log((t.includes('Chegando') && t.includes('em 3 dias') && t.includes('0 de 3') ? 'OK   ' : 'FAIL ') + 'mural mostra prova chegando');
  await click('#b-board-0');
  const n = await page.evaluate(() => S.data.planSessions.filter(p => p.subject === 'Matemática' && p.topic === 'Frações').length);
  console.log((n === 1 && (await page.textContent('#root')).includes('1 de 3') ? 'OK   ' : 'FAIL ') + 'reservar sessão pela sugestão');
  console.log((await page.textContent('#root')).includes('Prova ou trabalho neste dia') ? 'OK   prova aparece no dia' : 'FAIL prova aparece no dia');
  console.log(errs.length ? 'FAIL erros ' + errs.join('|') : 'OK   sem erros JS');
  await page.screenshot({ path: 'test/shot-mural.png' }); await b.close();
})();
