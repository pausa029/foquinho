/* ---------- perfil local com senha protegida (PBKDF2-SHA-256 com sal aleatório) ---------- */
var CRYPTO_OK = !!(window.crypto && window.crypto.subtle && window.crypto.getRandomValues && typeof TextEncoder !== 'undefined');

function b64(buf) {
  var b = new Uint8Array(buf), s = '';
  for (var i = 0; i < b.length; i++) s += String.fromCharCode(b[i]);
  return btoa(s);
}
function unb64(s) {
  var bin = atob(s), u = new Uint8Array(bin.length);
  for (var i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
  return u;
}
function normName(s) {
  s = String(s || '').replace(/\s+/g, ' ').trim();
  if (s.normalize) s = s.normalize('NFC');
  return s;
}
function normPass(s) { s = String(s || ''); return s.normalize ? s.normalize('NFC') : s; }
function validName(s) { return s.length >= 3 && s.length <= 20 && /^[A-Za-zÀ-ÿ0-9 ._-]+$/.test(s); }
function findProfile(name) {
  var n = normName(name).toLowerCase(), list = S.device.profiles;
  for (var i = 0; i < list.length; i++) if (list[i].name.toLowerCase() === n) return list[i];
  return null;
}

async function pbkdf2(password, saltBytes, iter) {
  var key = await window.crypto.subtle.importKey('raw', new TextEncoder().encode(password), { name: 'PBKDF2' }, false, ['deriveBits']);
  var bits = await window.crypto.subtle.deriveBits({ name: 'PBKDF2', salt: saltBytes, iterations: iter, hash: 'SHA-256' }, key, 256);
  return b64(bits);
}
/* mede o aparelho e escolhe quantas rodadas cabem em cerca de meio segundo */
async function calibrateIter() {
  var salt = window.crypto.getRandomValues(new Uint8Array(16));
  var t0 = (window.performance && performance.now) ? performance.now() : Date.now();
  await pbkdf2('calibrar', salt, 20000);
  var t1 = (window.performance && performance.now) ? performance.now() : Date.now();
  var dt = Math.max(1, t1 - t0);
  return clamp(Math.round((20000 * 450 / dt) / 10000) * 10000, 120000, 600000);
}

function lockWait() { return Math.max(0, Math.ceil((S.device.lock.until - now()) / 1000)); }

async function createProfile(name, pass, pass2) {
  if (!CRYPTO_OK) return { ok: false, err: 'Este navegador não tem o recurso necessário para proteger senhas. Você pode usar o Foquinho sem conta.' };
  name = normName(name); pass = normPass(pass); pass2 = normPass(pass2);
  if (!validName(name)) return { ok: false, field: 'su-name', err: 'Use de 3 a 20 caracteres: letras, números, espaço, ponto, hífen ou sublinhado.' };
  if (findProfile(name)) return { ok: false, field: 'su-name', err: 'Já existe um perfil com esse nome neste aparelho.' };
  if (pass.length < 6) return { ok: false, field: 'su-pass', err: 'A senha precisa ter pelo menos 6 caracteres.' };
  if (pass.toLowerCase() === name.toLowerCase()) return { ok: false, field: 'su-pass', err: 'A senha não pode ser igual ao nome de usuário.' };
  if (pass !== pass2) return { ok: false, field: 'su-pass2', err: 'As duas senhas não são iguais.' };
  try {
    var iter = await calibrateIter();
    var salt = window.crypto.getRandomValues(new Uint8Array(16));
    var hash = await pbkdf2(pass, salt, iter);
    var prof = { id: 'p' + uid(), name: name, salt: b64(salt), hash: hash, iter: iter, createdAt: now() };
    /* quem estava usando sem conta leva os dados para o perfil novo; fora disso o perfil começa vazio */
    var fromGuest = !!(S.user && S.user.id === 'guest' && !S.demo && S.data);
    var data = fromGuest ? S.data : newData();
    S.device.profiles.push(prof);
    S.device.session = prof.id;
    S.device.demo = false;
    S.demo = false;
    S.user = { id: prof.id, name: prof.name };
    S.data = data;
    saveDevice();
    save();
    if (fromGuest) lsDel(keyData('guest'));
    return { ok: true, migrated: fromGuest };
  } catch (e) {
    return { ok: false, err: 'Não foi possível proteger a senha neste navegador. Você pode usar o Foquinho sem conta.' };
  }
}

async function checkPassword(prof, pass) {
  var hash = await pbkdf2(normPass(pass), unb64(prof.salt), prof.iter);
  return hash === prof.hash;
}

async function login(name, pass) {
  if (!CRYPTO_OK) return { ok: false, err: 'Este navegador não consegue conferir senhas com segurança.' };
  var wait = lockWait();
  if (wait > 0) return { ok: false, err: 'Muitas tentativas seguidas. Aguarde ' + wait + ' segundos e tente de novo.' };
  var prof = findProfile(name);
  var okPass = false;
  try { if (prof) okPass = await checkPassword(prof, pass); } catch (e) { return { ok: false, err: 'Não foi possível conferir a senha neste navegador.' }; }
  if (!prof || !okPass) {
    S.device.lock.fails++;
    if (S.device.lock.fails >= 5) { S.device.lock = { fails: 0, until: now() + 30000 }; }
    saveDevice();
    return { ok: false, field: 'li-pass', err: 'Nome de usuário ou senha incorretos.' };
  }
  S.device.lock = { fails: 0, until: 0 };
  S.device.session = prof.id;
  S.device.demo = false;
  S.demo = false;
  S.user = { id: prof.id, name: prof.name };
  S.data = loadData(prof.id) || newData();
  saveDevice();
  return { ok: true };
}

async function changePassword(cur, nw, nw2) {
  var prof = currentProfile();
  if (!prof) return { ok: false, err: 'Nenhum perfil com senha em uso.' };
  nw = normPass(nw); nw2 = normPass(nw2);
  try {
    if (!(await checkPassword(prof, cur))) return { ok: false, field: 'pw-cur', err: 'A senha atual não confere.' };
    if (nw.length < 6) return { ok: false, field: 'pw-new', err: 'A nova senha precisa ter pelo menos 6 caracteres.' };
    if (nw.toLowerCase() === prof.name.toLowerCase()) return { ok: false, field: 'pw-new', err: 'A senha não pode ser igual ao nome de usuário.' };
    if (nw !== nw2) return { ok: false, field: 'pw-new2', err: 'As duas senhas novas não são iguais.' };
    var iter = await calibrateIter();
    var salt = window.crypto.getRandomValues(new Uint8Array(16));
    prof.hash = await pbkdf2(nw, salt, iter);
    prof.salt = b64(salt);
    prof.iter = iter;
    saveDevice();
    return { ok: true };
  } catch (e) {
    return { ok: false, err: 'Não foi possível trocar a senha neste navegador.' };
  }
}

function currentProfile() {
  if (!S.user || S.user.id === 'guest') return null;
  var list = S.device.profiles;
  for (var i = 0; i < list.length; i++) if (list[i].id === S.user.id) return list[i];
  return null;
}
function removeProfile(id) {
  S.device.profiles = S.device.profiles.filter(function (p) { return p.id !== id; });
  lsDel(keyData(id));
  lsDel(keyData(id) + '.ilegivel');
  if (S.device.session === id) S.device.session = null;
  saveDevice();
}
function startGuest() {
  S.demo = false;
  S.device.demo = false;
  S.device.session = 'guest';
  S.user = { id: 'guest' };
  S.data = loadData('guest') || newData();
  saveDevice();
  save();
}
function signOut() {
  S.device.session = null;
  S.device.demo = false;
  S.demo = false;
  S.user = null;
  S.data = null;
  saveDevice();
}
