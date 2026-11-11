/* ---------- eventos e inicialização ---------- */
function runAction(name, el) {
  var fn = A[name];
  if (!fn) return;
  var r = fn(el);
  if (r === false) return;
  render();
}
document.addEventListener('click', function (ev) {
  var el = ev.target && ev.target.closest ? ev.target.closest('[data-act]') : null;
  if (!el || el.disabled) return;
  if (el.closest('[inert]')) return;
  primeAudio();
  runAction(el.getAttribute('data-act'), el);
});
document.addEventListener('submit', function (ev) {
  var form = ev.target && ev.target.closest ? ev.target.closest('form[data-form]') : null;
  if (!form) return;
  ev.preventDefault();
  var fn = FORMS[form.getAttribute('data-form')];
  if (!fn) return;
  var r = fn();
  if (r && r.then) r.then(function (x) { if (x !== false) render(); }, function () { S.tmp.busy = false; if (S.modal) S.modal.busy = false; render(); });
  else if (r !== false) render();
});
document.addEventListener('change', function (ev) {
  var el = ev.target;
  if (!el || !el.getAttribute) return;
  var name = el.getAttribute('data-change');
  if (!name || !CHANGES[name]) return;
  var r = CHANGES[name](el);
  if (r !== false) render();
});
document.addEventListener('keydown', function (ev) {
  if (ev.key === 'Escape' && S.modal && !S.modal.busy) { closeModal(); render(); }
  /* prende o foco na janela aberta */
  if (ev.key === 'Tab' && S.modal) {
    var sheet = document.getElementById('modal');
    if (!sheet) return;
    var f = $all('button:not([disabled]),input:not([disabled]),select:not([disabled]),textarea:not([disabled]),summary,[tabindex]:not([tabindex="-1"])', sheet);
    if (!f.length) return;
    var first = f[0], last = f[f.length - 1];
    if (ev.shiftKey && document.activeElement === first) { ev.preventDefault(); last.focus(); }
    else if (!ev.shiftKey && document.activeElement === last) { ev.preventDefault(); first.focus(); }
  }
});

function tick() {
  if (!S.data) return;
  var t = S.data.timer, ev = timerSync();
  if (ev) {
    chime(); buzz();
    if (ev === 'fim') { announce('Tempo concluído.'); if (document.hidden) sysNotify('Foquinho', 'Tempo concluído: ' + timerTitle(t)); render(); }
    else { announce(ev === 'intervalo' ? 'Intervalo. Descanse um pouco.' : 'Foco. Novo ciclo.'); if (document.hidden) sysNotify('Foquinho', ev === 'intervalo' ? 'Hora do intervalo.' : 'De volta ao foco.'); render(); }
  }
  var changed = remTick(false);
  if (pumpAlerts()) render();
  else if (changed && inApp() && S.route.name === 'home') render();
  var today = dayKey();
  if (S.today !== today) { S.today = today; if (S.demo) S.data = demoData(); if (inApp()) render(); }
  paintTimer(false);
}
document.addEventListener('visibilitychange', function () {
  if (document.hidden) return;
  lastRemTick = 0;
  tick();
  if (S.data && S.data.timer && !S.data.timer.paused && !S.data.timer.finished && S.route.name === 'timer') wakeOn();
});

function boot() {
  S.storageOk = probeStorage();
  S.device = loadDevice();
  S.today = dayKey();
  var route;
  if (S.device.demo) { S.demo = true; S.user = { id: 'demo', name: '' }; S.data = demoData(); route = 'home'; }
  else route = resume();
  if (S.tmp.loadError) setTimeout(function () { toast('Os dados salvos estavam ilegíveis e foram guardados à parte. O app começou do zero.'); }, 400);
  enter(route);
  render();
  if (S.data && S.data.timer && !S.data.timer.paused && !S.data.timer.finished) tick();
  setInterval(tick, 1000);
  if (window.claude && window.claude.use) {
    try { window.claude.use('downloads').then(function (dl) { S.dl = dl || null; }, function () { S.dl = null; }); } catch (e) { S.dl = null; }
  }
}
try { boot(); }
catch (e) {
  var r = document.getElementById('root');
  if (r) r.innerHTML = '<div class="pad col page"><section class="card"><h2>O Foquinho não conseguiu abrir</h2><p>Recarregue a página. Se o problema continuar, este navegador pode ser antigo demais para esta versão.</p><p class="muted">Detalhe técnico: ' + esc(e && e.message) + '</p></section></div>';
}
