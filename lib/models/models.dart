// Modelos de dados do TelaTchau.
// Tudo aqui é serializado em JSON e guardado localmente no aparelho.

import 'dart:math';

String newId() {
  final r = Random();
  final t = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final s = r.nextInt(1 << 30).toRadixString(36);
  return '$t$s';
}

// ---------- utilidades de leitura segura ----------

String readStr(Map<String, dynamic> m, String k, [String def = '']) {
  final v = m[k];
  return v is String ? v.trim() : def;
}

int readInt(Map<String, dynamic> m, String k, int def, {int? min, int? max}) {
  final v = m[k];
  int n;
  if (v is int) {
    n = v;
  } else if (v is double && v.isFinite) {
    n = v.round();
  } else {
    return def;
  }
  if (min != null && n < min) n = min;
  if (max != null && n > max) n = max;
  return n;
}

int? readIntOrNull(Map<String, dynamic> m, String k, {int? min, int? max}) {
  final v = m[k];
  if (v is! num || !v.isFinite) return null;
  int n = v.round();
  if (min != null && n < min) n = min;
  if (max != null && n > max) n = max;
  return n;
}

bool readBool(Map<String, dynamic> m, String k, bool def) {
  final v = m[k];
  return v is bool ? v : def;
}

List<String> readStrList(Map<String, dynamic> m, String k) {
  final v = m[k];
  if (v is! List) return <String>[];
  return v.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

List<Map<String, dynamic>> readMapList(Map<String, dynamic> m, String k) {
  final v = m[k];
  if (v is! List) return <Map<String, dynamic>>[];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

/// Chave de dia no formato AAAA-MM-DD (hora local do aparelho).
String dayKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

DateTime? parseDayKey(String? k) {
  if (k == null) return null;
  final re = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  final mt = re.firstMatch(k);
  if (mt == null) return null;
  final y = int.parse(mt.group(1)!);
  final mo = int.parse(mt.group(2)!);
  final d = int.parse(mt.group(3)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final dt = DateTime(y, mo, d, 12);
  if (dt.month != mo || dt.day != d) return null;
  return dt;
}

// ---------- perfil ----------

enum SchoolLevel { fundamental, medio, tecnico, superior, outro }

String schoolLevelLabel(SchoolLevel l) {
  switch (l) {
    case SchoolLevel.fundamental:
      return 'Ensino fundamental';
    case SchoolLevel.medio:
      return 'Ensino médio';
    case SchoolLevel.tecnico:
      return 'Curso técnico';
    case SchoolLevel.superior:
      return 'Faculdade';
    case SchoolLevel.outro:
      return 'Outro';
  }
}

class Profile {
  String nickname;
  SchoolLevel? level;
  List<String> sports; // nomes escolhidos pelo estudante
  int studyGoalMin; // meta diária de estudo (min)
  int moveGoalMin; // meta diária de atividade física (min)
  int? screenGoalMin; // meta diária de tempo de tela (min), opcional
  bool remindersOn;
  String remindFrom; // "HH:mm" — janela em que aceita lembretes
  String remindTo;
  String quietFrom; // "HH:mm" — período em que não quer ser incomodado
  String quietTo;

  Profile({
    required this.nickname,
    this.level,
    List<String>? sports,
    this.studyGoalMin = 60,
    this.moveGoalMin = 30,
    this.screenGoalMin,
    this.remindersOn = true,
    this.remindFrom = '08:00',
    this.remindTo = '21:00',
    this.quietFrom = '22:00',
    this.quietTo = '07:00',
  }) : sports = sports ?? <String>[];

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'level': level?.name,
        'sports': sports,
        'studyGoalMin': studyGoalMin,
        'moveGoalMin': moveGoalMin,
        'screenGoalMin': screenGoalMin,
        'remindersOn': remindersOn,
        'remindFrom': remindFrom,
        'remindTo': remindTo,
        'quietFrom': quietFrom,
        'quietTo': quietTo,
      };

  static Profile fromJson(Map<String, dynamic> m) {
    SchoolLevel? lvl;
    final ls = readStr(m, 'level');
    for (final l in SchoolLevel.values) {
      if (l.name == ls) lvl = l;
    }
    final nick = readStr(m, 'nickname');
    return Profile(
      nickname: nick.isEmpty ? 'Estudante' : nick,
      level: lvl,
      sports: readStrList(m, 'sports'),
      studyGoalMin: readInt(m, 'studyGoalMin', 60, min: 5, max: 600),
      moveGoalMin: readInt(m, 'moveGoalMin', 30, min: 5, max: 300),
      screenGoalMin: readIntOrNull(m, 'screenGoalMin', min: 15, max: 1440),
      remindersOn: readBool(m, 'remindersOn', true),
      remindFrom: validHm(readStr(m, 'remindFrom')) ?? '08:00',
      remindTo: validHm(readStr(m, 'remindTo')) ?? '21:00',
      quietFrom: validHm(readStr(m, 'quietFrom')) ?? '22:00',
      quietTo: validHm(readStr(m, 'quietTo')) ?? '07:00',
    );
  }
}

/// Devolve "HH:mm" se o texto for um horário válido; senão null.
String? validHm(String s) {
  final mt = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
  if (mt == null) return null;
  final h = int.parse(mt.group(1)!);
  final m = int.parse(mt.group(2)!);
  if (h > 23 || m > 59) return null;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

int hmToMinutes(String hm) {
  final p = hm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

// ---------- matérias, provas, tarefas ----------

class Subject {
  String id;
  String name;
  bool hard; // marcada como mais difícil
  List<String> topics; // assuntos que caem em provas/trabalhos

  Subject({required this.id, required this.name, this.hard = false, List<String>? topics})
      : topics = topics ?? <String>[];

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'hard': hard, 'topics': topics};

  static Subject? fromJson(Map<String, dynamic> m) {
    final id = readStr(m, 'id');
    final name = readStr(m, 'name');
    if (id.isEmpty || name.isEmpty) return null;
    return Subject(id: id, name: name, hard: readBool(m, 'hard', false), topics: readStrList(m, 'topics'));
  }
}

enum ExamKind { prova, trabalho }

class Exam {
  String id;
  String subjectId;
  String title; // assunto ou nome do trabalho
  ExamKind kind;
  String? date; // AAAA-MM-DD, opcional

  Exam({required this.id, required this.subjectId, required this.title, this.kind = ExamKind.prova, this.date});

  Map<String, dynamic> toJson() => {'id': id, 'subjectId': subjectId, 'title': title, 'kind': kind.name, 'date': date};

  static Exam? fromJson(Map<String, dynamic> m) {
    final id = readStr(m, 'id');
    final sid = readStr(m, 'subjectId');
    if (id.isEmpty || sid.isEmpty) return null;
    final d = readStr(m, 'date');
    return Exam(
      id: id,
      subjectId: sid,
      title: readStr(m, 'title'),
      kind: readStr(m, 'kind') == 'trabalho' ? ExamKind.trabalho : ExamKind.prova,
      date: parseDayKey(d) == null ? null : d,
    );
  }

  /// Dias até a data (0 = hoje). null se não houver data.
  int? daysUntil(DateTime now) {
    final dt = parseDayKey(date);
    if (dt == null) return null;
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(dt.year, dt.month, dt.day);
    return b.difference(a).inDays;
  }
}

enum TaskStatus { todo, doing, done }

class StudyTask {
  String id;
  String subjectId;
  String topic;
  int minutes;
  String? deadline; // AAAA-MM-DD
  TaskStatus status;
  int createdAt; // ms

  StudyTask({
    required this.id,
    required this.subjectId,
    required this.topic,
    this.minutes = 25,
    this.deadline,
    this.status = TaskStatus.todo,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'topic': topic,
        'minutes': minutes,
        'deadline': deadline,
        'status': status.name,
        'createdAt': createdAt,
      };

  static StudyTask? fromJson(Map<String, dynamic> m) {
    final id = readStr(m, 'id');
    final sid = readStr(m, 'subjectId');
    if (id.isEmpty || sid.isEmpty) return null;
    TaskStatus st = TaskStatus.todo;
    for (final s in TaskStatus.values) {
      if (s.name == readStr(m, 'status')) st = s;
    }
    final d = readStr(m, 'deadline');
    return StudyTask(
      id: id,
      subjectId: sid,
      topic: readStr(m, 'topic'),
      minutes: readInt(m, 'minutes', 25, min: 5, max: 480),
      deadline: parseDayKey(d) == null ? null : d,
      status: st,
      createdAt: readInt(m, 'createdAt', 0, min: 0),
    );
  }
}

// ---------- atividades físicas (lista editável) ----------

enum Place { casa, arLivre, qualquer }

String placeLabel(Place p) {
  switch (p) {
    case Place.casa:
      return 'Em casa';
    case Place.arLivre:
      return 'Ao ar livre';
    case Place.qualquer:
      return 'Em qualquer lugar';
  }
}

class Activity {
  String id;
  String name;
  int minutes;
  Place place;
  String sport; // categoria/esporte ligado (ex.: "Caminhada")

  Activity({required this.id, required this.name, required this.minutes, required this.place, required this.sport});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'minutes': minutes, 'place': place.name, 'sport': sport};

  static Activity? fromJson(Map<String, dynamic> m) {
    final id = readStr(m, 'id');
    final name = readStr(m, 'name');
    if (id.isEmpty || name.isEmpty) return null;
    Place p = Place.qualquer;
    for (final x in Place.values) {
      if (x.name == readStr(m, 'place')) p = x;
    }
    return Activity(
      id: id,
      name: name,
      minutes: readInt(m, 'minutes', 10, min: 1, max: 240),
      place: p,
      sport: readStr(m, 'sport', 'Outro'),
    );
  }
}

/// Esportes oferecidos na configuração; o estudante pode acrescentar outros.
const List<String> kSportOptions = [
  'Caminhada',
  'Alongamento',
  'Corrida',
  'Dança',
  'Bicicleta',
  'Futebol',
  'Exercício em casa',
  'Vôlei',
  'Basquete',
  'Natação',
  'Pular corda',
  'Skate',
  'Lutas',
];

/// Atividades iniciais, todas editáveis depois. [nome, minutos, local, esporte]
List<Activity> defaultActivities() {
  const rows = [
    ['Caminhada curta pelo quarteirão', 10, Place.arLivre, 'Caminhada'],
    ['Caminhada em ritmo confortável', 20, Place.arLivre, 'Caminhada'],
    ['Alongar pescoço, ombros e costas', 5, Place.qualquer, 'Alongamento'],
    ['Alongamento do corpo todo', 10, Place.casa, 'Alongamento'],
    ['Trote leve com pausas para caminhar', 15, Place.arLivre, 'Corrida'],
    ['Corrida leve, em ritmo de conversa', 20, Place.arLivre, 'Corrida'],
    ['Dançar três músicas seguidas', 10, Place.casa, 'Dança'],
    ['Pedalada curta em ritmo leve', 20, Place.arLivre, 'Bicicleta'],
    ['Embaixadinhas e domínio de bola', 10, Place.arLivre, 'Futebol'],
    ['Chutes a gol ou passes contra a parede', 20, Place.arLivre, 'Futebol'],
    ['Polichinelos e agachamentos', 5, Place.casa, 'Exercício em casa'],
    ['Circuito: agachamento, flexão e prancha', 10, Place.casa, 'Exercício em casa'],
    ['Toques e manchetes contra a parede', 10, Place.arLivre, 'Vôlei'],
    ['Arremessos de perto da cesta', 15, Place.arLivre, 'Basquete'],
    ['Fortalecer pernas e abdômen fora da água', 10, Place.casa, 'Natação'],
    ['Pular corda em blocos de 1 minuto', 5, Place.qualquer, 'Pular corda'],
    ['Equilíbrio e remadas em lugar seguro', 15, Place.arLivre, 'Skate'],
    ['Base, guarda e movimentos no ar', 10, Place.casa, 'Lutas'],
  ];
  final out = <Activity>[];
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    out.add(Activity(
      id: 'def-$i',
      name: r[0] as String,
      minutes: r[1] as int,
      place: r[2] as Place,
      sport: r[3] as String,
    ));
  }
  return out;
}

// ---------- sessões registradas ----------

enum SessionKind { estudo, exercicio }

class Session {
  String id;
  SessionKind kind;
  String title;
  String? subjectId;
  String? topic;
  int minutes;
  int startedAt; // ms desde a época (hora local do aparelho)
  String note;

  Session({
    required this.id,
    required this.kind,
    required this.title,
    this.subjectId,
    this.topic,
    required this.minutes,
    required this.startedAt,
    this.note = '',
  });

  String get day => dayKey(DateTime.fromMillisecondsSinceEpoch(startedAt));

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'subjectId': subjectId,
        'topic': topic,
        'minutes': minutes,
        'startedAt': startedAt,
        'note': note,
      };

  static Session? fromJson(Map<String, dynamic> m) {
    final id = readStr(m, 'id');
    if (id.isEmpty) return null;
    final start = readIntOrNull(m, 'startedAt', min: 0);
    final min = readIntOrNull(m, 'minutes', min: 1, max: 1440);
    if (start == null || min == null) return null;
    final sid = readStr(m, 'subjectId');
    final topic = readStr(m, 'topic');
    return Session(
      id: id,
      kind: readStr(m, 'kind') == 'exercicio' ? SessionKind.exercicio : SessionKind.estudo,
      title: readStr(m, 'title'),
      subjectId: sid.isEmpty ? null : sid,
      topic: topic.isEmpty ? null : topic,
      minutes: min,
      startedAt: start,
      note: readStr(m, 'note'),
    );
  }
}

// ---------- sessão em andamento (temporizador) ----------

enum Phase { foco, intervalo }

class ActiveSession {
  SessionKind kind;
  String title;
  String? subjectId;
  String? topic;
  String? taskId;
  int focusMin;
  int breakMin;
  int cycles; // 1 = sessão simples, sem intervalos
  int cycleIndex; // começa em 1
  Phase phase;
  int phaseEndsAt; // ms
  int phaseMs; // duração da fase atual
  bool paused;
  int remainingMs; // válido quando pausado
  int focusDoneMs; // foco já concluído em fases anteriores
  int startedAt;

  ActiveSession({
    required this.kind,
    required this.title,
    this.subjectId,
    this.topic,
    this.taskId,
    required this.focusMin,
    required this.breakMin,
    required this.cycles,
    this.cycleIndex = 1,
    this.phase = Phase.foco,
    required this.phaseEndsAt,
    required this.phaseMs,
    this.paused = false,
    this.remainingMs = 0,
    this.focusDoneMs = 0,
    required this.startedAt,
  });

  int get plannedMin => focusMin * cycles;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'title': title,
        'subjectId': subjectId,
        'topic': topic,
        'taskId': taskId,
        'focusMin': focusMin,
        'breakMin': breakMin,
        'cycles': cycles,
        'cycleIndex': cycleIndex,
        'phase': phase.name,
        'phaseEndsAt': phaseEndsAt,
        'phaseMs': phaseMs,
        'paused': paused,
        'remainingMs': remainingMs,
        'focusDoneMs': focusDoneMs,
        'startedAt': startedAt,
      };

  static ActiveSession? fromJson(Map<String, dynamic> m) {
    final ends = readIntOrNull(m, 'phaseEndsAt', min: 0);
    final start = readIntOrNull(m, 'startedAt', min: 0);
    if (ends == null || start == null) return null;
    final sid = readStr(m, 'subjectId');
    final topic = readStr(m, 'topic');
    final tid = readStr(m, 'taskId');
    final focusMin = readInt(m, 'focusMin', 25, min: 1, max: 180);
    return ActiveSession(
      kind: readStr(m, 'kind') == 'exercicio' ? SessionKind.exercicio : SessionKind.estudo,
      title: readStr(m, 'title'),
      subjectId: sid.isEmpty ? null : sid,
      topic: topic.isEmpty ? null : topic,
      taskId: tid.isEmpty ? null : tid,
      focusMin: focusMin,
      breakMin: readInt(m, 'breakMin', 5, min: 1, max: 60),
      cycles: readInt(m, 'cycles', 1, min: 1, max: 12),
      cycleIndex: readInt(m, 'cycleIndex', 1, min: 1, max: 12),
      phase: readStr(m, 'phase') == 'intervalo' ? Phase.intervalo : Phase.foco,
      phaseEndsAt: ends,
      phaseMs: readInt(m, 'phaseMs', focusMin * 60000, min: 1000),
      paused: readBool(m, 'paused', false),
      remainingMs: readInt(m, 'remainingMs', 0, min: 0),
      focusDoneMs: readInt(m, 'focusDoneMs', 0, min: 0),
      startedAt: start,
    );
  }
}

// ---------- configurações e dados completos ----------

enum ThemeChoice { sistema, claro, escuro }

class AppData {
  Profile? profile;
  bool onboarded;
  List<Subject> subjects;
  List<Exam> exams;
  List<StudyTask> tasks;
  List<Activity> activities;
  List<Session> sessions;
  Map<String, int> screenLog; // dia -> minutos informados manualmente
  ActiveSession? active;
  ThemeChoice theme;
  bool soundOn;

  AppData({
    this.profile,
    this.onboarded = false,
    List<Subject>? subjects,
    List<Exam>? exams,
    List<StudyTask>? tasks,
    List<Activity>? activities,
    List<Session>? sessions,
    Map<String, int>? screenLog,
    this.active,
    this.theme = ThemeChoice.sistema,
    this.soundOn = true,
  })  : subjects = subjects ?? <Subject>[],
        exams = exams ?? <Exam>[],
        tasks = tasks ?? <StudyTask>[],
        activities = activities ?? defaultActivities(),
        sessions = sessions ?? <Session>[],
        screenLog = screenLog ?? <String, int>{};

  Map<String, dynamic> toJson() => {
        'v': 1,
        'profile': profile?.toJson(),
        'onboarded': onboarded,
        'subjects': subjects.map((e) => e.toJson()).toList(),
        'exams': exams.map((e) => e.toJson()).toList(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'activities': activities.map((e) => e.toJson()).toList(),
        'sessions': sessions.map((e) => e.toJson()).toList(),
        'screenLog': screenLog,
        'active': active?.toJson(),
        'theme': theme.name,
        'soundOn': soundOn,
      };

  static AppData fromJson(Map<String, dynamic> m) {
    final prof = m['profile'];
    final subjects = readMapList(m, 'subjects').map(Subject.fromJson).whereType<Subject>().toList();
    final subjectIds = subjects.map((s) => s.id).toSet();
    final exams = readMapList(m, 'exams').map(Exam.fromJson).whereType<Exam>().where((e) => subjectIds.contains(e.subjectId)).toList();
    final tasks = readMapList(m, 'tasks').map(StudyTask.fromJson).whereType<StudyTask>().where((t) => subjectIds.contains(t.subjectId)).toList();
    final acts = readMapList(m, 'activities').map(Activity.fromJson).whereType<Activity>().toList();
    final sessions = readMapList(m, 'sessions').map(Session.fromJson).whereType<Session>().toList();
    final log = <String, int>{};
    final rawLog = m['screenLog'];
    if (rawLog is Map) {
      rawLog.forEach((k, v) {
        if (k is String && parseDayKey(k) != null && v is num && v.isFinite) {
          log[k] = v.round().clamp(0, 1440).toInt();
        }
      });
    }
    ThemeChoice theme = ThemeChoice.sistema;
    for (final t in ThemeChoice.values) {
      if (t.name == readStr(m, 'theme')) theme = t;
    }
    final activeRaw = m['active'];
    return AppData(
      profile: prof is Map ? Profile.fromJson(Map<String, dynamic>.from(prof)) : null,
      onboarded: readBool(m, 'onboarded', false),
      subjects: subjects,
      exams: exams,
      tasks: tasks,
      activities: m['activities'] is List ? acts : defaultActivities(),
      sessions: sessions,
      screenLog: log,
      active: activeRaw is Map ? ActiveSession.fromJson(Map<String, dynamic>.from(activeRaw)) : null,
      theme: theme,
      soundOn: readBool(m, 'soundOn', true),
    );
  }

  Subject? subjectById(String? id) {
    if (id == null) return null;
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  String subjectName(String? id) => subjectById(id)?.name ?? 'Matéria removida';
}
