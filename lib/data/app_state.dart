// Estado do aplicativo e persistência local.
// Os dados ficam em um único JSON no armazenamento do app (shared_preferences),
// só neste aparelho. Não há servidor, conta online nem sincronização.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

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

  AppState({
    Future<String?> Function()? read,
    Future<bool> Function(String)? write,
    Future<bool> Function()? clear,
  })  : _read = read ?? _prefsRead,
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
  }

  /// Grava e avisa a interface. Nunca lança exceção: um erro de gravação vira aviso.
  Future<void> save() async {
    notifyListeners();
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
    if (markTaskDone && a.taskId != null) {
      for (final t in data.tasks) {
        if (t.id == a.taskId) t.status = TaskStatus.done;
      }
    }
    data.active = null;
    _finished = false;
    await save();
    return rec;
  }

  // ---------- configurações ----------

  Future<void> setTheme(ThemeChoice t) async {
    data.theme = t;
    await save();
  }

  Future<void> setSound(bool on) async {
    data.soundOn = on;
    await save();
  }

  /// Apaga perfil e todos os dados locais.
  Future<void> deleteEverything() async {
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
