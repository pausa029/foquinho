/* ---------- interface: ícones, componentes, navegação e desenho da tela ---------- */
var ICONS = {
  home: '<path d="M3.5 11.5 12 4l8.5 7.5"/><path d="M6 10v9.5h12V10"/>',
  cards: '<rect x="3.5" y="4" width="7" height="7" rx="1.5"/><rect x="13.5" y="4" width="7" height="7" rx="1.5"/><rect x="3.5" y="13" width="7" height="7" rx="1.5"/><rect x="13.5" y="13" width="7" height="7" rx="1.5"/>',
  timer: '<circle cx="12" cy="13.5" r="7"/><path d="M12 13.5V9.5M9.5 3h5M12 3v3.5"/>',
  chart: '<path d="M5.5 20v-7M12 20V5M18.5 20v-4.5M3 20h18"/>',
  more: '<circle cx="5" cy="12" r="1.6" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.6" fill="currentColor" stroke="none"/><circle cx="19" cy="12" r="1.6" fill="currentColor" stroke="none"/>',
  book: '<path d="M12 6.5C10 5 7 4.5 3.5 5v13c3.5-.5 6.5 0 8.5 1.5 2-1.5 5-2 8.5-1.5V5c-3.5-.5-6.5 0-8.5 1.5z"/><path d="M12 6.5v13"/>',
  ball: '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5v17M6 6c2.2 2.4 2.2 9.6 0 12M18 6c-2.2 2.4-2.2 9.6 0 12"/>',
  pause: '<path d="M9 5v14M15 5v14"/>',
  play: '<path d="M8 5l11 7-11 7z"/>',
  stop: '<rect x="6" y="6" width="12" height="12" rx="1.5"/>',
  phone: '<rect x="7" y="2.5" width="10" height="19" rx="2.5"/><path d="M11 18.5h2"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  minus: '<path d="M5 12h14"/>',
  check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
  star: '<path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8-5.2-2.8-5.2 2.8 1-5.8L3.5 9.7l5.9-.9z"/>',
  later: '<path d="M6.5 4h11v16.5L12 16.5l-5.5 4z"/>',
  bell: '<path d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>',
  lock: '<rect x="5" y="10.5" width="14" height="10" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
  trash: '<path d="M4.5 7h15M9.5 7V4.5h5V7M6.5 7l1 13h9l1-13"/>',
  edit: '<path d="M4 20l1-4.5L16 4.5l3.5 3.5L8.5 19z"/><path d="M14 6.5l3.5 3.5"/>',
  right: '<path d="M9 5l7 7-7 7"/>',
  left: '<path d="M15 5l-7 7 7 7"/>',
  dice: '<rect x="4" y="4" width="16" height="16" rx="3"/><circle cx="8.5" cy="8.5" r="1.2" fill="currentColor" stroke="none"/><circle cx="15.5" cy="8.5" r="1.2" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.2" fill="currentColor" stroke="none"/><circle cx="8.5" cy="15.5" r="1.2" fill="currentColor" stroke="none"/><circle cx="15.5" cy="15.5" r="1.2" fill="currentColor" stroke="none"/>',
  info: '<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5.5M12 7.5v.5"/>',
  x: '<path d="M6 6l12 12M18 6L6 18"/>',
  user: '<circle cx="12" cy="8.5" r="3.5"/><path d="M5 20c.8-3.5 3.5-5.5 7-5.5s6.2 2 7 5.5"/>',
  target: '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="4.5"/><circle cx="12" cy="12" r="1.2" fill="currentColor" stroke="none"/>',
  flag: '<path d="M6 21V4M6 5h11l-2 4 2 4H6"/>',
  shield: '<path d="M12 3l7.5 3v5.5c0 4.5-3 8-7.5 9.5-4.5-1.5-7.5-5-7.5-9.5V6z"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2.5V5M12 19v2.5M2.5 12H5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M18.7 5.3l-1.8 1.8M7.1 16.9l-1.8 1.8"/>',
  down: '<path d="M12 4v11M7.5 11l4.5 4.5 4.5-4.5M5 19.5h14"/>',
  cal: '<rect x="4" y="5.5" width="16" height="15" rx="2"/><path d="M4 10h16M8.5 3.5v4M15.5 3.5v4"/>',
  fire: '<path d="M12 2.5c.6 3.2-1.2 4.8-2.7 6.6C8 10.7 7 12.3 7 14.4a5 5 0 0 0 10 0c0-1.6-.6-2.9-1.4-4-.4 1-1 1.7-1.9 2 .5-3.6-.3-7.5-1.7-9.9z"/><path d="M12 19.4a2.3 2.3 0 0 1-2.3-2.3c0-1.3 1-2.1 2.3-3.6 1.3 1.5 2.3 2.3 2.3 3.6a2.3 2.3 0 0 1-2.3 2.3z"/>',
  moon: '<path d="M19.5 14.5A8 8 0 0 1 9.5 4.5a8 8 0 1 0 10 10z"/>',
  bulb: '<path d="M9.5 17.5h5M10.5 20.5h3M12 3.5a6 6 0 0 0-3.6 10.8c.7.6 1.1 1.4 1.1 2.2h5c0-.8.4-1.6 1.1-2.2A6 6 0 0 0 12 3.5z"/>',
  demo: '<rect x="3.5" y="4.5" width="17" height="11.5" rx="1.5"/><path d="M12 16v4M8.5 20.5h7"/>',
  clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
  gear: '<path d="M4 7h9M17 7h3M4 12h3M11 12h9M4 17h11M19 17h1"/><circle cx="15" cy="7" r="2"/><circle cx="9" cy="12" r="2"/><circle cx="17" cy="17" r="2"/>'
};
function ic(name, cls) {
  return '<svg class="ic' + (cls ? ' ' + cls : '') + '" viewBox="0 0 24 24" width="24" height="24" aria-hidden="true" focusable="false">' + ICONS[name] + '</svg>';
}
function kindIcon(kind) { return kind === 'estudo' ? 'book' : (kind === 'exercicio' ? 'ball' : 'pause'); }

function btn(label, act, o) {
  o = o || {};
  var id = o.id || ('b-' + act + (o.v != null ? '-' + slug(String(o.v)) : ''));
  return '<button type="' + (o.submit ? 'submit' : 'button') + '" class="btn' + (o.cls ? ' ' + o.cls : '') + '" id="' + id + '"' +
    (o.submit ? '' : ' data-act="' + act + '"') + (o.v != null ? ' data-v="' + esc(o.v) + '"' : '') + (o.k != null ? ' data-k="' + esc(o.k) + '"' : '') +
    (o.dis ? ' disabled' : '') + (o.pressed != null ? ' aria-pressed="' + (o.pressed ? 'true' : 'false') + '"' : '') +
    (o.aria ? ' aria-label="' + esc(o.aria) + '"' : '') + '>' + (o.icon ? ic(o.icon) : '') + '<span>' + esc(label) + '</span></button>';
}
function chip(label, act, v, on, o) {
  o = o || {};
  var id = o.id || ('c-' + act + (o.k != null ? '-' + slug(String(o.k)) : '') + '-' + slug(String(v)));
  return '<button type="button" class="chip' + (on ? ' on' : '') + (o.cls ? ' ' + o.cls : '') + '" id="' + id + '" data-act="' + act + '" data-v="' + esc(v) + '"' +
    (o.k != null ? ' data-k="' + esc(o.k) + '"' : '') + ' aria-pressed="' + (on ? 'true' : 'false') + '">' + (on ? ic('check', 'sm') : '') + '<span>' + esc(label) + '</span></button>';
}
function chipRow(label, items, act, cur, k) {
  /* items: [[valor, rótulo], …]; valor '' = sem filtro */
  var gid = 'g-' + act + (k ? '-' + k : '');
  return '<div class="chips" role="group" aria-labelledby="' + gid + '"><p class="chips-label" id="' + gid + '">' + esc(label) + '</p><div class="wrap">' +
    items.map(function (it) { return chip(it[1], act, it[0], String(cur == null ? '' : cur) === String(it[0]), { k: k }); }).join('') + '</div></div>';
}
function stepper(key, text, label) {
  return '<div class="stepper" role="group" aria-label="' + esc(label) + '">' +
    '<button type="button" class="step" id="st-' + key + '-m" data-act="step" data-k="' + key + '" data-v="-1" aria-label="Diminuir: ' + esc(label) + '">' + ic('minus') + '</button>' +
    '<output class="step-val num" id="st-' + key + '-v">' + esc(text) + '</output>' +
    '<button type="button" class="step" id="st-' + key + '-p" data-act="step" data-k="' + key + '" data-v="1" aria-label="Aumentar: ' + esc(label) + '">' + ic('plus') + '</button></div>';
}
function sw(key, on, labelId) {
  return '<button type="button" class="switch' + (on ? ' on' : '') + '" role="switch" aria-checked="' + (on ? 'true' : 'false') + '" id="sw-' + key + '" data-act="toggle" data-k="' + key + '" aria-labelledby="' + labelId + '">' +
    '<span class="knob" aria-hidden="true"></span><span class="sw-txt" aria-hidden="true">' + (on ? 'Ligado' : 'Desligado') + '</span></button>';
}
function setting(key, title, desc, control) {
  return '<div class="setting"><div class="setting-txt"><p class="setting-t" id="lb-' + key + '">' + esc(title) + '</p>' + (desc ? '<p class="setting-d">' + desc + '</p>' : '') + '</div><div class="setting-c">' + control + '</div></div>';
}
function switchRow(key, title, desc, on) { return setting(key, title, desc, sw(key, on, 'lb-' + key)); }
function progress(pct, text, cls) {
  var p = clamp(Math.round(pct), 0, 100);
  return '<div class="bar' + (cls ? ' ' + cls : '') + '" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="' + p + '" aria-valuetext="' + esc(text) + '"><i style="width:' + p + '%"></i></div>';
}
function notice(html, cls) { return '<p class="notice' + (cls ? ' ' + cls : '') + '">' + ic('info') + '<span>' + html + '</span></p>'; }
function tag(text, cls) { return '<span class="tag' + (cls ? ' ' + cls : '') + '">' + esc(text) + '</span>'; }
function demoTag() { return S.demo ? tag('fictício', 'demo') : ''; }
function field(id, label, o) {
  o = o || {};
  var attrs = ' id="' + id + '" name="' + id + '" data-keep';
  if (o.type) attrs += ' type="' + o.type + '"';
  if (o.value != null) attrs += ' value="' + esc(o.value) + '"';
  if (o.max) attrs += ' maxlength="' + o.max + '"';
  if (o.ac) attrs += ' autocomplete="' + o.ac + '"';
  if (o.mode) attrs += ' inputmode="' + o.mode + '"';
  if (o.min != null) attrs += ' min="' + o.min + '"';
  if (o.maxv != null) attrs += ' max="' + o.maxv + '"';
  if (o.ph) attrs += ' placeholder="' + esc(o.ph) + '"';
  if (o.nocap) attrs += ' autocapitalize="none" autocorrect="off" spellcheck="false"';
  if (o.dis) attrs += ' disabled';
  if (o.hint) attrs += ' aria-describedby="' + id + '-h"';
  if (o.invalid) attrs += ' aria-invalid="true"';
  return '<div class="field"><label for="' + id + '">' + esc(label) + '</label><input class="input"' + attrs + '>' + (o.hint ? '<p class="hint" id="' + id + '-h">' + o.hint + '</p>' : '') + '</div>';
}
function selectField(id, label, options, cur) {
  return '<div class="field"><label for="' + id + '">' + esc(label) + '</label><select class="input" id="' + id + '" name="' + id + '" data-keep>' +
    options.map(function (op) { return '<option value="' + esc(op[0]) + '"' + (String(op[0]) === String(cur) ? ' selected' : '') + '>' + esc(op[1]) + '</option>'; }).join('') + '</select></div>';
}
function errBox(msg) { return msg ? '<p class="err" role="alert">' + ic('info') + '<span>' + esc(msg) + '</span></p>' : ''; }
function val(id) { var el = document.getElementById(id); return el ? el.value : ''; }

/* ---------- a pista: assinatura visual do temporizador ---------- */
var TRACK_P = 220 + 2 * Math.PI * 60;
function trackPoint(f) {
  var r = 60, L1 = 55, A = Math.PI * r, L2 = 110, s = clamp(f, 0, 1) * TRACK_P;
  if (s <= L1) return [150 + s, 35];
  s -= L1;
  if (s <= A) return [205 + r * Math.cos(-Math.PI / 2 + s / r), 95 + r * Math.sin(-Math.PI / 2 + s / r)];
  s -= A;
  if (s <= L2) return [205 - s, 155];
  s -= L2;
  if (s <= A) return [95 + r * Math.cos(Math.PI / 2 + s / r), 95 + r * Math.sin(Math.PI / 2 + s / r)];
  s -= A;
  return [95 + s, 35];
}
/* dígitos em posições fixas: a fonte de título não tem algarismos tabulares */
function clockTspans(txt) {
  var w = 0, i, ch, out = '', x;
  for (i = 0; i < txt.length; i++) w += txt.charAt(i) === ':' ? 13 : 26;
  x = 150 - w / 2;
  for (i = 0; i < txt.length; i++) {
    ch = txt.charAt(i);
    var cw = ch === ':' ? 13 : 26;
    out += '<tspan x="' + (x + cw / 2).toFixed(1) + '">' + ch + '</tspan>';
    x += cw;
  }
  return out;
}
function trackSVG(frac, kind, clock, label) {
  var pt = trackPoint(frac), path = 'M150,35 H205 A60,60 0 0 1 205,155 H95 A60,60 0 0 1 95,35 Z';
  return '<svg class="track ' + kind + '" viewBox="0 0 300 190" aria-hidden="true" focusable="false">' +
    '<path class="tk-bed" d="' + path + '"/>' +
    '<path class="tk-lane" d="M95,25 H205 A70,70 0 0 1 205,165 H95 A70,70 0 0 1 95,25 Z"/>' +
    '<path class="tk-lane" d="M95,45 H205 A50,50 0 0 1 205,145 H95 A50,50 0 0 1 95,45 Z"/>' +
    '<path class="tk-run" id="tk-run" d="' + path + '" stroke-dasharray="' + TRACK_P.toFixed(2) + '" stroke-dashoffset="' + (TRACK_P * (1 - clamp(frac, 0, 1))).toFixed(2) + '"/>' +
    '<path class="tk-start" d="M150,21 V49"/>' +
    '<circle class="tk-dot" id="tk-dot" r="7.5" cx="' + pt[0].toFixed(1) + '" cy="' + pt[1].toFixed(1) + '"/>' +
    '<text class="tk-time" id="tk-time" y="106" text-anchor="middle">' + clockTspans(clock) + '</text>' +
    (label ? '<text class="tk-label" id="tk-label" x="150" y="128" text-anchor="middle">' + esc(label) + '</text>' : '') +
    '</svg>';
}
function logoSVG() {
  return '<img src="data:image/png;base64,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" width="48" height="48" alt="" style="border-radius:13px;display:block">';
}
function clockText(ms) {
  var s = Math.ceil(ms / 1000), m = Math.floor(s / 60);
  return pad2(m) + ':' + pad2(s % 60);
}

/* ---------- navegação ---------- */
var ROUTES = {
  welcome: { pre: true }, login: { pre: true }, signup: { pre: true }, onboard: { pre: true },
  home: { tab: 'home', title: 'Início' },
  acts: { tab: 'acts', title: 'Atividades' },
  timer: { tab: 'timer', title: 'Foco' },
  hist: { tab: 'hist', title: 'Histórico' },
  more: { tab: 'more', title: 'Mais' },
  prefs: { tab: 'more', title: 'Esportes, matérias e provas', sub: true },
  goals: { tab: 'more', title: 'Metas e horários', sub: true },
  plan: { tab: 'more', title: 'Plano para a vontade', sub: true },
  challenges: { tab: 'more', title: 'Desafios pessoais', sub: true },
  look: { tab: 'more', title: 'Aparência e avisos', sub: true },
  perms: { tab: 'more', title: 'Permissões e recursos', sub: true },
  privacy: { tab: 'more', title: 'Privacidade', sub: true },
  native: { tab: 'more', title: 'Controles do aparelho', sub: true },
  datap: { tab: 'more', title: 'Seus dados', sub: true },
  account: { tab: 'more', title: 'Perfil', sub: true },
  about: { tab: 'more', title: 'Sobre e limitações', sub: true }
};
var TABS = [['home', 'Início', 'home'], ['acts', 'Atividades', 'cards'], ['timer', 'Foco', 'timer'], ['hist', 'Histórico', 'chart'], ['more', 'Mais', 'more']];
var SCREENS = {}, MODALS = {}, A = {}, FORMS = {}, CHANGES = {};

function inApp() { return !!S.data && !!S.user && !ROUTES[S.route.name].pre; }
function go(name, p) {
  var cur = ROUTES[S.route.name];
  if (ROUTES[name].sub && !cur.pre) S.stack.push(S.route); else S.stack = [];
  if (S.stack.length > 12) S.stack.shift();
  S.route = { name: name, p: p || {} };
  S.modal = null;
  S.tmp.err = null;
}
function back() {
  S.route = S.stack.pop() || { name: 'more', p: {} };
  S.modal = null;
  S.tmp.err = null;
}
function openModal(m) {
  var act = document.activeElement;
  if (!S.modal) S.returnFocus = act && act.id ? act.id : null;
  m.fresh = true;
  S.modal = m;
}
function closeModal() { S.modal = null; S.focusAfter = S.returnFocus; S.returnFocus = null; }

var toastTimer = null;
function toast(msg) {
  var el = document.getElementById('toast');
  if (!el) return;
  el.textContent = msg;
  el.hidden = false;
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(function () { el.hidden = true; el.textContent = ''; }, 4200);
}
function announce(msg) {
  var el = document.getElementById('live');
  if (!el) return;
  el.textContent = '';
  setTimeout(function () { el.textContent = msg; }, 60);
}

function applyLook() {
  var root = document.documentElement, ui = S.data ? S.data.ui : null;
  var theme = ui ? ui.theme : 'auto', font = ui ? ui.font : 0;
  if (theme === 'auto') root.removeAttribute('data-app-theme'); else root.setAttribute('data-app-theme', theme);
  root.setAttribute('data-font', String(font));
}

function bannersHTML() {
  var out = '';
  if (S.demo) {
    out += '<div class="banner demo" role="note"><div class="pad col banner-in">' + ic('demo') + '<p><strong>Modo demonstração.</strong> Todos os dados que aparecem são fictícios.</p>' +
      '<button type="button" class="btn small" id="b-demo-off" data-act="demoOff"><span>Sair</span></button></div></div>';
  }
  if (!S.storageOk) {
    out += '<div class="banner warn" role="note"><div class="pad col banner-in">' + ic('info') + '<p><strong>Este navegador não está guardando dados.</strong> O que você fizer vale só até fechar esta página.</p></div></div>';
  } else if (S.saveFailed) {
    out += '<div class="banner warn" role="note"><div class="pad col banner-in">' + ic('info') + '<p><strong>A última alteração não foi salva.</strong> O armazenamento do navegador pode estar cheio ou bloqueado.</p></div></div>';
  }
  return out;
}
function headerHTML(r) {
  var title = r.title;
  if (S.route.name === 'home') {
    var nm = S.demo ? 'estudante' : (S.user && S.user.name ? S.user.name : '');
    title = nm ? 'Oi, ' + nm : 'Olá';
  }
  return '<header class="top"><div class="pad col top-in">' +
    (r.sub ? '<button type="button" class="icon-btn" id="b-back" data-act="back" aria-label="Voltar">' + ic('left') + '</button>' : '<span class="logo sm" aria-hidden="true">' + logoSVG() + '</span>') +
    '<h1 id="title" tabindex="-1">' + esc(title) + '</h1></div></header>';
}
function tabsHTML(cur) {
  return '<nav class="tabs" aria-label="Navegação principal"><div class="tabs-in">' + TABS.map(function (t) {
    return '<button type="button" class="tab' + (t[0] === cur ? ' on' : '') + '" id="tab-' + t[0] + '" data-act="tab" data-v="' + t[0] + '"' + (t[0] === cur ? ' aria-current="page"' : '') + '>' + ic(t[2]) + '<span>' + t[1] + '</span></button>';
  }).join('') + '</div></nav>';
}
function miniTimerHTML() {
  var t = S.data && S.data.timer;
  if (!t || S.route.name === 'timer') return '';
  var label = t.finished ? 'Tempo concluído. Toque para registrar.' : (KIND_LABEL[t.kind] + (t.cyc && t.cyc.phase === 'intervalo' ? ' · intervalo' : '') + (t.paused ? ' · pausado' : ''));
  return '<button type="button" class="mini ' + t.kind + '" id="mini-timer" data-act="tab" data-v="timer">' + ic(kindIcon(t.kind)) + '<span class="mini-l" id="mini-label">' + esc(label) + '</span>' +
    (t.finished ? '' : '<span class="mini-t num" id="mini-time">' + clockText(timerRemain(t)) + '</span>') + ic('right', 'sm') + '</button>';
}
function modalHTML() {
  if (!S.modal) return '';
  var m = MODALS[S.modal.t](S.modal);
  return '<div class="scrim" id="scrim" data-act="scrim"></div><div class="sheet" role="dialog" aria-modal="true" aria-labelledby="m-title" id="modal"><div class="sheet-in">' +
    '<div class="sheet-head"><h2 id="m-title" tabindex="-1">' + esc(m.title) + '</h2>' +
    '<button type="button" class="icon-btn" id="m-close" data-act="closeModal" aria-label="Fechar">' + ic('x') + '</button></div>' + m.body + '</div></div>';
}
function appHTML() {
  var r = ROUTES[S.route.name], body = SCREENS[S.route.name](), hide = S.modal ? ' aria-hidden="true" inert' : '';
  if (r.pre) {
    return '<div class="app pre' + (S.modal ? ' has-modal' : '') + '"><div class="layer"' + hide + '>' + bannersHTML() +
      '<main id="view" class="view" tabindex="-1"><div class="pad col page">' + body + '</div></main></div>' + modalHTML() + '</div>';
  }
  return '<div class="app' + (S.modal ? ' has-modal' : '') + '"><div class="layer"' + hide + '>' + bannersHTML() + headerHTML(r) +
    '<main id="view" class="view" tabindex="-1"><div class="pad col page">' + body + '</div></main>' + miniTimerHTML() + tabsHTML(r.tab) + '</div>' + modalHTML() + '</div>';
}
function routeKey() { return S.route.name + '|' + (S.route.name === 'onboard' ? (S.tmp.ob || 0) : ''); }

var lastKey = null, rendering = false;
function render() {
  if (rendering) return;
  rendering = true;
  try {
    var root = document.getElementById('root'), keep = {}, act = document.activeElement;
    var focusId = act && act.id ? act.id : null, selS = null, selE = null;
    var key = routeKey(), same = key === lastKey, view = document.getElementById('view');
    var top = (view && same) ? view.scrollTop : 0;
    var sheet = document.getElementById('modal'), sheetTop = sheet ? sheet.scrollTop : 0;
    var freshModal = !!(S.modal && S.modal.fresh);
    if (same && !freshModal) {
      $all('[data-keep]', root).forEach(function (el) { if (el.id) keep[el.id] = el.type === 'checkbox' ? el.checked : el.value; });
      try { if (act && typeof act.selectionStart === 'number') { selS = act.selectionStart; selE = act.selectionEnd; } } catch (e) { /* tipos sem seleção */ }
    }
    var drop = S.drop || {};
    S.drop = {};
    applyLook();
    root.innerHTML = appHTML();
    lastKey = key;
    $all('[data-keep]', root).forEach(function (el) {
      if (!el.id || !has(keep, el.id) || drop[el.id]) return;
      if (el.type === 'checkbox') el.checked = keep[el.id]; else if (el.type !== 'file') el.value = keep[el.id];
    });
    view = document.getElementById('view');
    if (view) view.scrollTop = top;
    sheet = document.getElementById('modal');
    if (sheet && !freshModal) sheet.scrollTop = sheetTop;

    var target = null;
    if (S.modal) {
      if (freshModal) { S.modal.fresh = false; target = $('[data-autofocus]', sheet) || document.getElementById('m-title'); }
      else target = focusId ? document.getElementById(focusId) : null;
      if (target && !sheet.contains(target)) target = document.getElementById('m-title');
    } else if (S.focusAfter) {
      target = document.getElementById(S.focusAfter);
      S.focusAfter = null;
    } else if (!same) {
      target = document.getElementById('title');
    } else if (focusId) {
      target = document.getElementById(focusId);
    }
    if (S.focusField) { target = document.getElementById(S.focusField) || target; S.focusField = null; }
    if (target && target.focus) {
      try { target.focus({ preventScroll: same && !freshModal }); } catch (e) { target.focus(); }
      if (selS != null && target.id === focusId) { try { target.setSelectionRange(selS, selE); } catch (e2) { /* ignorado */ } }
    }
    paintTimer(true);
  } finally { rendering = false; }
}

/* atualiza só os números do temporizador, sem redesenhar a tela */
var lastClock = '';
function paintTimer(force) {
  var t = S.data && S.data.timer;
  var u = S.data && S.data.useSession, ue = document.getElementById('use-elapsed');
  if (u && ue) {
    var txt = 'há ' + fmtMin((now() - u.start) / 60000);
    if (ue.textContent !== txt) ue.textContent = txt;
  }
  if (!t || t.finished) return;
  var rem = timerRemain(t), txt2 = clockText(rem);
  if (!force && txt2 === lastClock) return;
  lastClock = txt2;
  var mt = document.getElementById('mini-time');
  if (mt) mt.textContent = txt2;
  var tt = document.getElementById('tk-time');
  if (tt) {
    tt.innerHTML = clockTspans(txt2);
    var frac = 1 - rem / t.phaseMs, pt = trackPoint(frac);
    var run = document.getElementById('tk-run'), dot = document.getElementById('tk-dot'), sr = document.getElementById('timer-sr');
    if (run) run.setAttribute('stroke-dashoffset', (TRACK_P * (1 - clamp(frac, 0, 1))).toFixed(2));
    if (dot) { dot.setAttribute('cx', pt[0].toFixed(1)); dot.setAttribute('cy', pt[1].toFixed(1)); }
    if (sr) sr.textContent = 'Faltam ' + spokenMin(Math.ceil(rem / 60000)) + '.';
  }
}
function paintWake() {
  var el = document.getElementById('wake-state');
  if (el) el.textContent = wakeText();
}
function wakeText() {
  if (!wakeSupported()) return 'Este navegador não mantém a tela ligada. Se a tela apagar, o aviso sonoro não toca; ao voltar, o Foquinho mostra que o tempo terminou.';
  if (!S.data.ui.awake) return 'Manter a tela ligada está desativado. Se a tela apagar, o aviso sonoro não toca.';
  if (S.wakeActive) return 'A tela fica ligada enquanto o temporizador estiver aberto, para o aviso tocar no fim.';
  return 'O navegador não manteve a tela ligada agora. Se ela apagar, o aviso sonoro não toca.';
}
