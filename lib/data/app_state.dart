// Estado do aplicativo e persistência local.
// Os dados ficam em um único JSON no armazenamento do app (shared_preferences),
// só neste aparelho. Não há servidor, conta online nem sincronização.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/planner.dart';
import '../logic/reminders.dart';
import '../models/models.dart';
import '../services/cloud.dart';
import '../services/notifier.dart';

const String kStorageKey = 'foquinho.v1';

/// Como o estado foi carregado — a interface mostra isso quando necessário.
enum LoadStatus { carregando, ok, erroLeitura, erroEscrita }

class AppState extends ChangeNotifier {
  AppData data = AppData();
  LoadStatus status = LoadStatus.carregando;
  String? lastError;

  /// Permite injetar outro mecanismo de gravação nos testes.
  final Future<String?> Function() _read;
  final Future<bool> Function(String) _write;
  final Future<bool> Function() _clear;

  /// Serviço de notificações do sistema. Nulo nos testes e onde não há suporte.
  final Notifier? notifier;
  Timer? _resyncTimer;
  String? _lastNoticeSig;

  /// Conta na nuvem. Nulo nos testes e onde a conta não está disponível.
  final CloudApi? cloud;
  final CloudStore? _cloudStore;
  CloudSession? session;
  bool cloudBusy = false;
  String? cloudNote; // última situação da sincronização, em texto simples
  int? lastSyncMs;
  String? _remoteStamp; // carimbo da última versão da nuvem que este aparelho conhece
  bool _dirty = false; // há mudança local ainda não enviada
  int _localChangedMs = 0;
  bool _applyingRemote = false;
  Timer? _pushTimer;
  String? _pkceVerifier; // login com Google em andamento (fica só no aparelho)
  String? _lastAuthCode;
  bool needsDataChoice = false; // entrou com Google e há dados nos dois lados

  AppState({
    Future<String?> Function()? read,
    Future<bool> Function(String)? write,
    Future<bool> Function()? clear,
    this.notifier,
    this.cloud,
    CloudStore? cloudStore,
  })  : _cloudStore = cloudStore ?? (cloud == null ? null : PrefsCloudStore()),
        _read = read ?? _prefsRead,
        _write = write ?? _prefsWrite,
        _clear = clear ?? _prefsClear;

  static Future<String?> _prefsRead() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(kStorageKey);
  }

  static Future<bool> _prefsWrite(String s) async {
    final p = await SharedPreferences.getInstance();
    return p.setString(kStorageKey, s);
  }

  static Future<bool> _prefsClear() async {
    final p = await SharedPreferences.getInstance();
    return p.remove(kStorageKey);
  }

  Future<void> load() async {
    status = LoadStatus.carregando;
    notifyListeners();
    try {
      final raw = await _read();
      if (raw == null || raw.isEmpty) {
        data = AppData();
      } else {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          data = AppData.fromJson(Map<String, dynamic>.from(decoded));
        } else {
          data = AppData();
          lastError = 'Os dados guardados estavam em um formato inesperado.';
        }
      }
      status = LoadStatus.ok;
    } catch (e) {
      data = AppData();
      status = LoadStatus.erroLeitura;
      lastError = 'Não foi possível ler os dados guardados. O app começou do zero.';
    }
    syncSession();
    notifyListeners();
    _scheduleResync();
    await _restoreCloud();
  }

  // ---------- notificações do sistema ----------

  bool get notificationsSupported => notifier != null && notifier!.supported;

  /// Lista do que deve estar agendado agora (vazia se a pessoa não ligou as notificações).
  List<PlannedNotice> plannedNotices([DateTime? now]) {
    final p = data.profile;
    if (p == null || !p.notifyOn) return const [];
    final n = now ?? DateTime.now();
    return [
      if (!_finished) ...planTimerNotices(data.active, n.millisecondsSinceEpoch),
      ...planReminderNotices(data, n),
    ];
  }

  /// Reagenda tudo pouco depois da última alteração (evita reagendar a cada toque).
  void _scheduleResync() {
    if (!notificationsSupported) return;
    _resyncTimer?.cancel();
    _resyncTimer = Timer(const Duration(milliseconds: 700), () {
      // ignore: discarded_futures
      resyncNotifications();
    });
  }

  Future<void> resyncNotifications() async {
    final n = notifier;
    if (n == null || !n.supported) return;
    try {
      final list = plannedNotices();
      // Nada mudou desde o último agendamento: não refaz (são muitos avisos).
      final sig = list.map((x) => '${x.id}|${x.when.millisecondsSinceEpoch}|${x.title}|${x.body}').join('~');
      if (sig == _lastNoticeSig) return;
      await n.replaceAll(list);
      _lastNoticeSig = sig;
    } catch (_) {
      // Notificação é um extra: uma falha aqui nunca deve travar o app.
    }
  }

  /// Pede a permissão ao sistema e liga as notificações. Devolve false se a pessoa negou.
  Future<bool> enableNotifications() async {
    final n = notifier;
    if (n == null || !n.supported) return false;
    final ok = await n.requestPermission();
    final p = data.profile ??= Profile(nickname: 'Estudante');
    p.notifyOn = ok;
    await save();
    return ok;
  }

  /// Para o som e tira da tela os alarmes do temporizador que já tocaram.
  Future<void> stopAlarmSound() async {
    final n = notifier;
    if (n == null || !n.supported) return;
    try {
      await n.dismissAlarms();
    } catch (_) {
      // sem efeito
    }
  }

  Future<void> disableNotifications() async {
    data.profile?.notifyOn = false;
    await save();
  }

  @override
  void dispose() {
    _resyncTimer?.cancel();
    _pushTimer?.cancel();
    super.dispose();
  }

  /// Grava e avisa a interface. Nunca lança exceção: um erro de gravação vira aviso.
  Future<void> save() async {
    notifyListeners();
    _scheduleResync();
    try {
      final ok = await _write(jsonEncode(data.toJson()));
      if (!ok) {
        status = LoadStatus.erroEscrita;
        lastError = 'A última alteração não pôde ser gravada.';
        notifyListeners();
      } else if (status == LoadStatus.erroEscrita) {
        status = LoadStatus.ok;
        lastError = null;
        notifyListeners();
      }
      if (ok) _markChanged();
    } catch (e) {
      status = LoadStatus.erroEscrita;
      lastError = 'A última alteração não pôde ser gravada.';
      notifyListeners();
    }
  }

  // ---------- perfil ----------

  bool get hasProfile => data.profile != null;

  Future<void> saveProfile(Profile p) async {
    data.profile = p;
    await save();
  }

  Future<void> finishOnboarding() async {
    data.onboarded = true;
    data.profile ??= Profile(nickname: 'Estudante');
    await save();
  }

  // ---------- matérias ----------

  Future<Subject> addSubject(String name, {bool hard = false}) async {
    final clean = name.trim();
    for (final s in data.subjects) {
      if (s.name.toLowerCase() == clean.toLowerCase()) {
        if (hard && !s.hard) {
          s.hard = true;
          await save();
        }
        return s;
      }
    }
    final s = Subject(id: newId(), name: clean, hard: hard);
    data.subjects.add(s);
    await save();
    return s;
  }

  Future<void> updateSubject(Subject s) async => save();

  Future<void> removeSubject(String id) async {
    data.subjects.removeWhere((s) => s.id == id);
    data.exams.removeWhere((e) => e.subjectId == id);
    data.tasks.removeWhere((t) => t.subjectId == id);
    data.planSessions.removeWhere((p) => p.subjectId == id);
    await save();
  }

  // ---------- provas e trabalhos ----------

  Future<void> upsertExam(Exam e) async {
    final i = data.exams.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      data.exams[i] = e;
    } else {
      data.exams.add(e);
    }
    await save();
  }

  Future<void> removeExam(String id) async {
    data.exams.removeWhere((e) => e.id == id);
    await save();
  }

  /// Provas e trabalhos futuros (ou sem data), do mais próximo ao mais distante.
  List<Exam> upcomingExams([DateTime? now]) {
    final n = now ?? DateTime.now();
    final list = data.exams.where((e) {
      final d = e.daysUntil(n);
      return d == null || d >= 0;
    }).toList();
    list.sort((a, b) {
      final da = a.daysUntil(n) ?? 9999;
      final db = b.daysUntil(n) ?? 9999;
      return da.compareTo(db);
    });
    return list;
  }

  // ---------- tarefas ----------

  Future<void> upsertTask(StudyTask t) async {
    final i = data.tasks.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      data.tasks[i] = t;
    } else {
      data.tasks.add(t);
    }
    await save();
  }

  Future<void> setTaskStatus(String id, TaskStatus st) async {
    for (final t in data.tasks) {
      if (t.id == id) t.status = st;
    }
    await save();
  }

  Future<void> removeTask(String id) async {
    data.tasks.removeWhere((t) => t.id == id);
    await save();
  }

  // ---------- atividades físicas ----------

  Future<void> upsertActivity(Activity a) async {
    final i = data.activities.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      data.activities[i] = a;
    } else {
      data.activities.add(a);
    }
    await save();
  }

  Future<void> removeActivity(String id) async {
    data.activities.removeWhere((a) => a.id == id);
    await save();
  }

  Future<void> restoreDefaultActivities() async {
    data.activities = defaultActivities();
    await save();
  }

  // ---------- tempo de tela (registro manual) ----------

  Future<void> setScreenMinutes(String day, int? minutes) async {
    if (minutes == null) {
      data.screenLog.remove(day);
    } else {
      data.screenLog[day] = minutes.clamp(0, 1440).toInt();
    }
    await save();
  }

  // ---------- sessões registradas ----------

  Future<void> addSession(Session s) async {
    data.sessions.add(s);
    await save();
  }

  Future<void> removeSession(String id) async {
    data.sessions.removeWhere((s) => s.id == id);
    await save();
  }

  Future<void> clearHistory() async {
    data.sessions.clear();
    data.screenLog.clear();
    await save();
  }

  // ---------- temporizador ----------

  ActiveSession? get active => data.active;

  int nowMs() => DateTime.now().millisecondsSinceEpoch;

  Future<void> startSession({
    required SessionKind kind,
    required String title,
    String? subjectId,
    String? topic,
    String? taskId,
    String? planId,
    required int focusMin,
    int breakMin = 5,
    int cycles = 1,
  }) async {
    final n = nowMs();
    final ms = focusMin * 60000;
    _finished = false;
    data.active = ActiveSession(
      kind: kind,
      title: title,
      subjectId: subjectId,
      topic: topic,
      taskId: taskId,
      planId: planId,
      focusMin: focusMin,
      breakMin: breakMin,
      cycles: cycles,
      phaseEndsAt: n + ms,
      phaseMs: ms,
      startedAt: n,
    );
    if (taskId != null) {
      for (final t in data.tasks) {
        if (t.id == taskId && t.status == TaskStatus.todo) t.status = TaskStatus.doing;
      }
    }
    await save();
  }

  int remainingMs() {
    final a = data.active;
    if (a == null) return 0;
    if (a.paused) return a.remainingMs;
    final r = a.phaseEndsAt - nowMs();
    return r < 0 ? 0 : r;
  }

  /// Foco já realizado até agora, em milissegundos (fases anteriores + fase atual se for foco).
  int focusElapsedMs() {
    final a = data.active;
    if (a == null) return 0;
    var ms = a.focusDoneMs;
    if (a.phase == Phase.foco) {
      final done = a.phaseMs - remainingMs();
      ms += done < 0 ? 0 : done;
    }
    return ms;
  }

  /// Avança as fases que já terminaram. Devolve 'foco', 'intervalo' ou 'fim' quando algo mudou.
  String? syncSession() {
    final a = data.active;
    if (a == null || a.paused || _finished) return null;
    String? ev;
    var guard = 0;
    while (nowMs() >= a.phaseEndsAt && guard < 50) {
      guard++;
      if (a.phase == Phase.foco) {
        a.focusDoneMs += a.phaseMs;
        if (a.cycleIndex >= a.cycles) {
          _finished = true;
          ev = 'fim';
          break;
        }
        a.phase = Phase.intervalo;
        a.phaseMs = a.breakMin * 60000;
        a.phaseEndsAt += a.phaseMs;
        ev = 'intervalo';
      } else {
        a.cycleIndex++;
        a.phase = Phase.foco;
        a.phaseMs = a.focusMin * 60000;
        a.phaseEndsAt += a.phaseMs;
        ev = 'foco';
      }
    }
    if (ev != null) {
      // ignore: discarded_futures
      save();
    }
    return ev;
  }

  bool _finished = false;

  /// A sessão em andamento chegou ao fim (todas as fases concluídas).
  /// Quem avança as fases é [syncSession], chamado ao carregar e a cada segundo.
  bool get finished => data.active != null && _finished;

  Future<void> pauseSession() async {
    final a = data.active;
    if (a == null || a.paused) return;
    a.remainingMs = remainingMs();
    a.paused = true;
    await save();
  }

  Future<void> resumeSession() async {
    final a = data.active;
    if (a == null || !a.paused) return;
    a.phaseEndsAt = nowMs() + a.remainingMs;
    a.paused = false;
    await save();
  }

  /// Cancela sem registrar nada.
  Future<void> cancelSession() async {
    data.active = null;
    _finished = false;
    await stopAlarmSound();
    await save();
  }

  /// Conclui (no fim ou antes da hora) e devolve os minutos de foco feitos, para a tela de registro.
  int concludeMinutes() {
    final a = data.active;
    if (a == null) return 0;
    var ms = a.focusDoneMs;
    if (!finished && a.phase == Phase.foco) {
      ms += a.phaseMs - remainingMs();
    }
    return (ms / 60000).round();
  }

  /// Registra a sessão concluída no histórico e limpa o temporizador.
  Future<Session?> finishAndRecord({required int minutes, String note = '', bool markTaskDone = false}) async {
    final a = data.active;
    if (a == null) return null;
    Session? rec;
    if (minutes >= 1) {
      rec = Session(
        id: newId(),
        kind: a.kind,
        title: a.title,
        subjectId: a.subjectId,
        topic: a.topic,
        minutes: minutes.clamp(1, 1440).toInt(),
        startedAt: a.startedAt,
        note: note.trim(),
      );
      data.sessions.add(rec);
    }
    // Sessão vinda do planejamento: concluída se fez pelo menos 80% do previsto.
    if (a.planId != null && minutes >= 1) {
      for (final p in data.planSessions) {
        if (p.id == a.planId) p.state = minutes >= (p.minutes * 0.8).ceil() ? PlanState.concluida : PlanState.incompleta;
      }
    }
    if (markTaskDone && a.taskId != null) {
      for (final t in data.tasks) {
        if (t.id == a.taskId) t.status = TaskStatus.done;
      }
    }
    data.active = null;
    _finished = false;
    await stopAlarmSound();
    await save();
    return rec;
  }

  // ---------- planejamento de estudos ----------

  Future<void> savePlanSettings(PlanSettings s) async {
    data.plan = s;
    await save();
  }

  /// Aplica um plano gerado: troca as sessões do período pelas preservadas + novas.
  Future<void> applyPlan(PlanResult r, DateTime from, DateTime to) async {
    final fromK = dayKey(from), toK = dayKey(to);
    final keepIds = r.kept.map((p) => p.id).toSet();
    data.planSessions.removeWhere((p) => p.day.compareTo(fromK) >= 0 && p.day.compareTo(toK) <= 0 && !keepIds.contains(p.id));
    data.planSessions.addAll(r.sessions);
    data.plan.examSig = examSignature(data);
    await save();
  }

  Future<void> upsertPlanSession(PlanSession p) async {
    final i = data.planSessions.indexWhere((x) => x.id == p.id);
    if (i >= 0) {
      data.planSessions[i] = p;
    } else {
      data.planSessions.add(p);
    }
    await save();
  }

  Future<void> removePlanSession(String id) async {
    data.planSessions.removeWhere((p) => p.id == id);
    await save();
  }

  /// Muda o estado. Ao concluir à mão, registra os minutos no histórico (conta na sequência).
  Future<void> setPlanState(String id, PlanState st, {bool record = false}) async {
    for (final p in data.planSessions) {
      if (p.id != id) continue;
      p.state = st;
      if (record && st == PlanState.concluida) {
        final when = p.dateTime;
        final n = DateTime.now();
        data.sessions.add(Session(
          id: newId(),
          kind: SessionKind.estudo,
          title: '${data.subjectName(p.subjectId)}${p.topic == null ? '' : ': ${p.topic}'}',
          subjectId: p.subjectId,
          topic: p.topic,
          minutes: p.minutes,
          startedAt: (when.isAfter(n) ? n : when).millisecondsSinceEpoch,
        ));
      }
    }
    await save();
  }

  Future<void> togglePlanPin(String id) async {
    for (final p in data.planSessions) {
      if (p.id == id) p.pinned = !p.pinned;
    }
    await save();
  }

  Future<void> setPlanPaused(bool v) async {
    data.plan.paused = v;
    await save();
  }

  /// Apaga todas as sessões planejadas (a disponibilidade informada continua).
  Future<void> clearPlan() async {
    data.planSessions.clear();
    data.plan.examSig = null;
    data.plan.paused = false;
    await save();
  }

  // ---------- configurações ----------

  Future<void> setTheme(ThemeChoice t) async {
    data.theme = t;
    await save();
  }

  /// Marca o tutorial da Foquinha como visto (ou pede para mostrar de novo).
  Future<void> setTourDone(bool done) async {
    data.tourDone = done;
    notifyListeners();
    await save();
  }

  Future<void> setSound(bool on) async {
    data.soundOn = on;
    await save();
  }

  // ---------- conta e cópia na nuvem ----------

  bool get cloudAvailable => cloud != null;
  bool get signedIn => session != null;

  Future<void> _storeCloud() async {
    final st = _cloudStore;
    if (st == null) return;
    final s = session;
    if (s == null) {
      final v = _pkceVerifier;
      if (v == null) {
        await st.clear();
      } else {
        await st.write({'pkce': v});
      }
      return;
    }
    await st.write({'session': s.toJson(), 'remoteStamp': _remoteStamp, 'dirty': _dirty, 'localChangedMs': _localChangedMs, 'lastSyncMs': lastSyncMs});
  }

  Future<void> _restoreCloud() async {
    final st = _cloudStore;
    if (cloud == null || st == null) return;
    try {
      final m = await st.read();
      final pk = m == null ? null : m['pkce'];
      if (pk is String && pk.length >= 43) _pkceVerifier = pk;
      final raw = m == null ? null : m['session'];
      if (m == null || raw is! Map) return;
      final s = CloudSession.fromJson(Map<String, dynamic>.from(raw));
      if (s == null) return;
      session = s;
      final stamp = m['remoteStamp'];
      _remoteStamp = stamp is String ? stamp : null;
      _dirty = m['dirty'] == true;
      final lc = m['localChangedMs'];
      _localChangedMs = lc is int ? lc : 0;
      final ls = m['lastSyncMs'];
      lastSyncMs = ls is int ? ls : null;
      notifyListeners();
      await cloudSync();
    } catch (_) {
      // conta indisponível agora: o app segue com os dados do aparelho
    }
  }

  void _markChanged() {
    if (session == null || _applyingRemote) return;
    _dirty = true;
    _localChangedMs = DateTime.now().millisecondsSinceEpoch;
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(seconds: 4), () {
      cloudSync();
    });
  }

  Future<CloudSession?> _freshSession() async {
    final c = cloud;
    var s = session;
    if (c == null || s == null) return null;
    if (s.expiresSoon(DateTime.now().millisecondsSinceEpoch)) {
      s = await c.refresh(s);
      session = s;
      await _storeCloud();
    }
    return s;
  }

  Future<void> _adoptRemote(CloudRow row) async {
    _applyingRemote = true;
    try {
      data = AppData.fromJson(row.data);
      _finished = false;
      syncSession();
      await save();
    } finally {
      _applyingRemote = false;
    }
    _remoteStamp = row.updatedAt;
    _dirty = false;
  }

  Future<void> _pushLocal(CloudSession s) async {
    _remoteStamp = await cloud!.push(s, data.toJson());
    _dirty = false;
  }

  /// Compara aparelho e nuvem e deixa os dois iguais. Nunca lança exceção.
  /// Regra: se só um lado mudou, ele vale; se os dois mudaram, vale o mais recente.
  Future<bool> cloudSync() async {
    final c = cloud;
    if (c == null || session == null || cloudBusy) return false;
    _pushTimer?.cancel();
    cloudBusy = true;
    notifyListeners();
    var ok = false;
    try {
      final s = await _freshSession();
      if (s == null) return false;
      final row = await c.pull(s);
      if (row == null) {
        await _pushLocal(s);
      } else if (row.updatedAt == _remoteStamp) {
        if (_dirty) await _pushLocal(s);
      } else if (!_dirty) {
        await _adoptRemote(row);
      } else {
        final remoteMs = DateTime.tryParse(row.updatedAt)?.millisecondsSinceEpoch ?? 0;
        if (remoteMs > _localChangedMs) {
          await _adoptRemote(row);
        } else {
          await _pushLocal(s);
        }
      }
      lastSyncMs = DateTime.now().millisecondsSinceEpoch;
      cloudNote = null;
      ok = true;
    } on CloudError catch (e) {
      cloudNote = e.message;
      if (e.code == 'unauthorized' || e.code == 'session_not_found' || e.code == 'refresh_token_not_found' || e.code == 'refresh_token_already_used') {
        session = null; // os dados continuam no aparelho; só é preciso entrar de novo
        cloudNote = 'Sua sessão venceu. Entre de novo para voltar a sincronizar.';
      }
    } catch (_) {
      cloudNote = 'Não foi possível sincronizar agora.';
    } finally {
      cloudBusy = false;
      await _storeCloud();
      notifyListeners();
    }
    return ok;
  }

  /// Depois de entrar: decide o que fazer com os dados.
  /// Devolve true quando há dados nos dois lados e a pessoa precisa escolher.
  Future<bool> _afterSignIn(CloudSession s) async {
    session = s;
    _remoteStamp = null;
    _dirty = false;
    _localChangedMs = DateTime.now().millisecondsSinceEpoch;
    cloudNote = null;
    final row = await cloud!.pull(s);
    var choose = false;
    if (row == null) {
      if (data.onboarded) await _pushLocal(s);
    } else if (!data.onboarded) {
      await _adoptRemote(row);
    } else {
      _remoteStamp = row.updatedAt;
      choose = true;
    }
    lastSyncMs = DateTime.now().millisecondsSinceEpoch;
    await _storeCloud();
    notifyListeners();
    return choose;
  }

  /// Cria a conta. Devolve true se já entrou; false se falta confirmar o e-mail.
  Future<bool> cloudSignUp(String email, String password) async {
    final s = await cloud!.signUp(email.trim(), password);
    if (s == null) return false;
    await _afterSignIn(s);
    return true;
  }

  /// Entra na conta. Devolve true quando a pessoa precisa escolher quais dados manter.
  Future<bool> cloudSignIn(String email, String password) async {
    return _afterSignIn(await cloud!.signIn(email.trim(), password));
  }

  Future<bool> cloudVerifyCode(String email, String code) async {
    return _afterSignIn(await cloud!.verifyCode(email.trim(), code.trim()));
  }

  Future<void> cloudResend(String email) => cloud!.resendConfirmation(email.trim());

  Future<void> cloudResetPassword(String email) => cloud!.sendPasswordReset(email.trim());

  /// Começa o login com Google: devolve o endereço que deve abrir no navegador.
  Future<Uri> cloudGoogleStart(String redirectTo) async {
    final pk = Pkce.generate();
    _pkceVerifier = pk.verifier;
    cloudNote = null;
    await _storeCloud();
    return cloud!.googleSignInUrl(codeChallenge: pk.challenge, redirectTo: redirectTo);
  }

  /// Volta do navegador (foquinho://login-callback?code=...). Nunca lança exceção.
  Future<void> cloudHandleLink(Uri uri) async {
    final c = cloud;
    if (c == null) return;
    final fromApp = uri.scheme == 'foquinho' && uri.host == 'login-callback';
    // Versão web: o Google volta para a própria página (https://.../web/?code=...).
    final fromWeb = kIsWeb &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        _pkceVerifier != null &&
        (uri.queryParameters.containsKey('code') || uri.queryParameters.containsKey('error'));
    if (!fromApp && !fromWeb) return;
    final params = {...uri.queryParameters, ...(uri.fragment.contains('=') ? Uri.splitQueryString(uri.fragment) : const <String, String>{})};
    final code = params['code'];
    final err = params['error_description'] ?? params['error'];
    if (code == null || code.isEmpty) {
      if (err != null) {
        cloudNote = 'O login com Google não foi concluído. Tente de novo.';
        _pkceVerifier = null;
        await _storeCloud();
        notifyListeners();
      }
      return;
    }
    if (code == _lastAuthCode) return; // o mesmo link pode chegar duas vezes
    _lastAuthCode = code;
    final v = _pkceVerifier;
    if (v == null) {
      cloudNote = 'Esse link de login já foi usado. Toque em "Entrar com Google" de novo.';
      notifyListeners();
      return;
    }
    cloudBusy = true;
    notifyListeners();
    try {
      final s = await c.exchangeCode(code, v);
      _pkceVerifier = null;
      needsDataChoice = await _afterSignIn(s);
    } on CloudError catch (e) {
      cloudNote = e.message;
    } catch (_) {
      cloudNote = 'Não foi possível entrar com Google agora.';
    } finally {
      _pkceVerifier = null;
      cloudBusy = false;
      await _storeCloud();
      notifyListeners();
    }
  }

  /// Resolve a escolha feita ao entrar: ficar com os dados da conta ou com os deste aparelho.
  Future<void> cloudChoose({required bool useCloud}) async {
    final c = cloud;
    final s = session;
    needsDataChoice = false;
    if (c == null || s == null) return;
    if (useCloud) {
      final row = await c.pull(s);
      if (row != null) await _adoptRemote(row);
    } else {
      await _pushLocal(s);
    }
    lastSyncMs = DateTime.now().millisecondsSinceEpoch;
    await _storeCloud();
    notifyListeners();
  }

  /// Sai da conta neste aparelho. Os dados continuam aqui e na nuvem.
  Future<void> cloudSignOut() async {
    final c = cloud;
    final s = session;
    _pushTimer?.cancel();
    needsDataChoice = false;
    if (c != null && s != null) {
      if (_dirty) await cloudSync();
      await c.signOut(s);
    }
    session = null;
    _remoteStamp = null;
    _dirty = false;
    lastSyncMs = null;
    cloudNote = null;
    await _storeCloud();
    notifyListeners();
  }

  /// Apaga a conta e a cópia da nuvem. Os dados deste aparelho continuam.
  Future<void> cloudDeleteAccount() async {
    final c = cloud;
    if (c == null || session == null) return;
    _pushTimer?.cancel();
    final s = await _freshSession();
    if (s == null) return;
    await c.deleteAccount(s);
    session = null;
    _remoteStamp = null;
    _dirty = false;
    lastSyncMs = null;
    cloudNote = null;
    await _storeCloud();
    notifyListeners();
  }

  /// Apaga perfil e todos os dados locais. Se houver conta, sai dela antes,
  /// para a cópia da nuvem não ser apagada junto.
  Future<void> deleteEverything() async {
    if (session != null) {
      _pushTimer?.cancel();
      _dirty = false;
      await cloudSignOut();
    }
    data = AppData();
    _finished = false;
    try {
      await _clear();
    } catch (_) {
      // Se não der para apagar a chave, grava o estado vazio por cima.
    }
    await save();
  }
}

/// Dá acesso ao [AppState] para qualquer widget abaixo na árvore.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope não encontrado na árvore de widgets');
    return scope!.notifier!;
  }
}
