/* ---------- utilidades ---------- */
var DAY_MS = 86400000;
var APP_VERSION = '1.0';

function $(sel, el) { return (el || document).querySelector(sel); }
function $all(sel, el) { return Array.prototype.slice.call((el || document).querySelectorAll(sel)); }
function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }
function esc(s) {
  return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  });
}
function pad2(n) { return (n < 10 ? '0' : '') + n; }
function uid() { return Date.now().toString(36) + Math.random().toString(36).slice(2, 8); }
function clamp(n, a, b) { return Math.max(a, Math.min(b, n)); }
function now() { return Date.now(); }
function uniq(list) { var seen = {}, out = []; list.forEach(function (x) { if (!has(seen, x)) { seen[x] = 1; out.push(x); } }); return out; }

function slug(s) {
  s = String(s).toLowerCase();
  if (s.normalize) s = s.normalize('NFD').replace(/[̀-ͯ]/g, '');
  return s.replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') || 'x';
}
function hashStr(s) { var h = 5381; for (var i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0; return Math.abs(h); }
function seeded(seed) {
  var a = seed >>> 0;
  return function () {
    a = (a + 0x6D2B79F5) | 0;
    var t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/* datas: sempre no horário local do aparelho */
function dayKey(d) { d = d || new Date(); return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate()); }
function isDayKey(k) { return typeof k === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(k) && !isNaN(keyToDate(k).getTime()); }
function keyToDate(k) { var p = k.split('-'); return new Date(+p[0], +p[1] - 1, +p[2], 12, 0, 0); }
function addDays(k, n) { var d = keyToDate(k); d.setDate(d.getDate() + n); return dayKey(d); }
function diffDays(a, b) { return Math.round((keyToDate(a).getTime() - keyToDate(b).getTime()) / DAY_MS); }
function wdIndex(k) { return (keyToDate(k).getDay() + 6) % 7; } /* 0 = segunda … 6 = domingo */
function weekStart(k) { return addDays(k, -wdIndex(k)); }
var WD_SHORT = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
var WD_LONG = ['segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado', 'domingo'];
function fmtDay(k) { var p = k.split('-'); return p[2] + '/' + p[1]; }
function fmtDayLong(k) { return WD_LONG[wdIndex(k)] + ', ' + fmtDay(k); }
function fmtClock(ts) { var d = new Date(ts); return pad2(d.getHours()) + ':' + pad2(d.getMinutes()); }
function nowHM() { var d = new Date(); return d.getHours() * 60 + d.getMinutes(); }
function hmToMin(s) {
  var m = /^(\d{1,2}):(\d{2})$/.exec(s || '');
  if (!m) return null;
  var h = +m[1], mi = +m[2];
  if (h > 23 || mi > 59) return null;
  return h * 60 + mi;
}
function fmtMin(m) {
  m = Math.max(0, Math.round(m));
  if (m < 60) return m + ' min';
  return Math.floor(m / 60) + 'h' + pad2(m % 60);
}
function spokenMin(m) {
  m = Math.max(0, Math.round(m));
  var h = Math.floor(m / 60), r = m % 60, parts = [];
  if (h) parts.push(h + (h === 1 ? ' hora' : ' horas'));
  if (r || !h) parts.push(r + (r === 1 ? ' minuto' : ' minutos'));
  return parts.join(' e ');
}
function plural(n, one, many) { return n + ' ' + (n === 1 ? one : many); }
function relDay(k) {
  var n = diffDays(k, dayKey());
  if (n === 0) return 'hoje';
  if (n === 1) return 'amanhã';
  if (n === -1) return 'ontem';
  if (n > 1) return 'em ' + n + ' dias';
  return 'há ' + (-n) + ' dias';
}
function niceMax(v) {
  /* teto "redondo" em minutos para o eixo dos gráficos */
  var steps = [30, 60, 120, 180, 240, 300, 360, 480, 600, 720, 900, 1080, 1440];
  for (var i = 0; i < steps.length; i++) if (v <= steps[i]) return steps[i];
  return 1440;
}
