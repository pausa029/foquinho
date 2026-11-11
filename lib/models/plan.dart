// Modelos do planejamento de estudos: disponibilidade e sessões planejadas.
// Ficam no mesmo JSON local dos outros dados do app.

import 'models.dart';

/// Disponibilidade de um dia da semana.
class DayAvail {
  bool on;
  String from; // "HH:mm"
  String to;

  DayAvail({this.on = false, this.from = '18:00', this.to = '20:00'});

  /// Minutos livres na faixa (0 se a faixa estiver invertida).
  int get minutes {
    final m = hmToMinutes(to) - hmToMinutes(from);
    return m < 0 ? 0 : m;
  }

  Map<String, dynamic> toJson() => {'on': on, 'from': from, 'to': to};

  static DayAvail fromJson(Map<String, dynamic> m) => DayAvail(
        on: readBool(m, 'on', false),
        from: validHm(readStr(m, 'from')) ?? '18:00',
        to: validHm(readStr(m, 'to')) ?? '20:00',
      );
}

class PlanSettings {
  /// Sete posições: 0 = segunda … 6 = domingo.
  List<DayAvail> days;
  int dailyMaxMin; // limite de estudo por dia
  int sessionMin; // duração preferida de cada sessão
  int gapMin; // intervalo entre sessões
  List<String> blocked; // datas (AAAA-MM-DD) em que não quer estudar
  bool configured; // a pessoa já informou a disponibilidade
  bool paused;
  String? examSig; // "assinatura" das provas quando o plano foi gerado

  PlanSettings({
    List<DayAvail>? days,
    this.dailyMaxMin = 90,
    this.sessionMin = 25,
    this.gapMin = 10,
    List<String>? blocked,
    this.configured = false,
    this.paused = false,
    this.examSig,
  })  : days = days ?? List.generate(7, (_) => DayAvail()),
        blocked = blocked ?? <String>[];

  Map<String, dynamic> toJson() => {
        'days': days.map((d) => d.toJson()).toList(),
        'dailyMaxMin': dailyMaxMin,
        'sessionMin': sessionMin,
        'gapMin': gapMin,
        'blocked': blocked,
        'configured': configured,
        'paused': paused,
        'examSig': examSig,
      };

  static PlanSettings fromJson(Map<String, dynamic> m) {
    final raw = readMapList(m, 'days').map(DayAvail.fromJson).toList();
    final days = List.generate(7, (i) => i < raw.length ? raw[i] : DayAvail());
    final sig = readStr(m, 'examSig');
    return PlanSettings(
      days: days,
      dailyMaxMin: readInt(m, 'dailyMaxMin', 90, min: 15, max: 600),
      sessionMin: readInt(m, 'sessionMin', 25, min: 10, max: 120),
      gapMin: readInt(m, 'gapMin', 10, min: 0, max: 60),
      blocked: readStrList(m, 'blocked').where((k) => parseDayKey(k) != null).toList(),
      configured: readBool(m, 'configured', false),
      paused: readBool(m, 'paused', false),
      examSig: sig.isEmpty ? null : sig,
    );
  }
}

enum PlanState { planejada, concluida, incompleta, naoRealizada }

String planStateLabel(PlanState s) {
  switch (s) {
    case PlanState.planejada:
      return 'Planejada';
    case PlanState.concluida:
      return 'Concluída';
    case PlanState.incompleta:
      return 'Incompleta';
    case PlanState.naoRealizada:
      return 'Não realizada';
  }
}

class PlanSession {
  String id;
  String subjectId;
  String? topic;
  String day; // AAAA-MM-DD
  String start; // "HH:mm"
  int minutes;
  PlanState state;
  bool pinned; // fixada: não muda ao gerar o plano de novo
  bool manual; // criada ou editada à mão
  bool moved; // reagendada

  PlanSession({
    required this.id,
    required this.subjectId,
    this.topic,
    required this.day,
    required this.start,
    required this.minutes,
    this.state = PlanState.planejada,
    this.pinned = false,
    this.manual = false,
    this.moved = false,
  });

  int get startMin => hmToMinutes(start);
  int get endMin => startMin + minutes;

  /// Conta para o limite diário e ocupa horário (as não realizadas liberam o espaço).
  bool get occupies => state != PlanState.naoRealizada;

  DateTime get dateTime {
    final d = parseDayKey(day) ?? DateTime.now();
    return DateTime(d.year, d.month, d.day, startMin ~/ 60, startMin % 60);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'topic': topic,
        'day': day,
        'start': start,
        'minutes': minutes,
        'state': state.name,
        'pinned': pinned,
        'manual': manual,
        'moved': moved,
      };

  static PlanSession? fromJson(Map<String, dynamic> m) {
    final id = readStr(m, 'id');
    final sid = readStr(m, 'subjectId');
    final day = readStr(m, 'day');
    final start = validHm(readStr(m, 'start'));
    if (id.isEmpty || sid.isEmpty || parseDayKey(day) == null || start == null) return null;
    var st = PlanState.planejada;
    for (final s in PlanState.values) {
      if (s.name == readStr(m, 'state')) st = s;
    }
    final topic = readStr(m, 'topic');
    return PlanSession(
      id: id,
      subjectId: sid,
      topic: topic.isEmpty ? null : topic,
      day: day,
      start: start,
      minutes: readInt(m, 'minutes', 25, min: 5, max: 240),
      state: st,
      pinned: readBool(m, 'pinned', false),
      manual: readBool(m, 'manual', false),
      moved: readBool(m, 'moved', false),
    );
  }
}
