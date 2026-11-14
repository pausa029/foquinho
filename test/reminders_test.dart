import 'package:flutter_test/flutter_test.dart';
import 'package:foquinho/data/app_state.dart';
import 'package:foquinho/logic/reminders.dart';
import 'package:foquinho/models/models.dart';
import 'package:foquinho/services/notifier.dart';

class FakeNotifier implements Notifier {
  bool grant = true;
  List<PlannedNotice> last = const [];
  int calls = 0;
  @override
  bool get supported => true;
  @override
  Future<bool> init() async => true;
  @override
  Future<bool> requestPermission() async => grant;
  @override
  Future<bool> isAllowed() async => grant;
  @override
  Future<void> replaceAll(List<PlannedNotice> notices) async {
    calls++;
    last = notices;
  }

  int dismissed = 0;
  @override
  Future<void> dismissAlarms() async {
    dismissed++;
  }

  @override
  Future<void> showTest() async {}
}

AppData sample() {
  final d = AppData(profile: Profile(nickname: 'Bia', sports: ['Futebol'], notifyOn: true), onboarded: true);
  d.subjects.add(Subject(id: 'mat', name: 'Matemática', hard: true));
  return d;
}

void main() {
  final now = DateTime(2026, 6, 10, 9, 0); // quarta-feira, 9h

  test('sem lembretes ligados não agenda nada', () {
    final d = sample();
    d.profile!.remindersOn = false;
    expect(planReminderNotices(d, now), isEmpty);
  });

  test('agenda estudo todos os dias, sem lembrete de movimento, sempre no futuro', () {
    final d = sample();
    d.profile!.nudgeOn = false;
    final list = planReminderNotices(d, now);
    expect(list.where((n) => n.title == 'Hora de estudar').length, 7);
    expect(list.where((n) => n.title == 'Hora de se mexer'), isEmpty);
    expect(list.every((n) => n.when.isAfter(now)), isTrue);
    expect(list.map((n) => n.id).toSet().length, list.length, reason: 'ids únicos');
    final first = list.firstWhere((n) => n.title == 'Hora de estudar');
    expect(first.when, DateTime(2026, 6, 10, 19, 0));
    expect(first.body, contains('Matemática'));
  });

  test('não lembra de estudar hoje se a meta do dia já foi batida', () {
    final d = sample();
    d.profile!.nudgeOn = false;
    d.sessions.add(Session(id: 's', kind: SessionKind.estudo, title: 'x', minutes: 60, startedAt: DateTime(2026, 6, 10, 8).millisecondsSinceEpoch));
    final list = planReminderNotices(d, now);
    expect(list.where((n) => n.title == 'Hora de estudar').first.when, DateTime(2026, 6, 11, 19, 0));
  });

  test('respeita o período não me incomodar', () {
    final d = sample();
    d.profile!
      ..studyRemindAt = '23:00'
      ..nudgeOn = false;
    final list = planReminderNotices(d, now);
    expect(list.any((n) => n.title == 'Hora de estudar'), isFalse);
  });

  test('avisos de pausa ficam dentro da janela e longe dos outros lembretes', () {
    final d = sample();
    final list = planReminderNotices(d, now).where((n) => n.rotating).toList();
    expect(list, isNotEmpty);
    for (final n in list) {
      final m = n.when.hour * 60 + n.when.minute;
      expect(m, greaterThan(8 * 60));
      expect(m, lessThan(21 * 60));
      expect((m - 19 * 60).abs() >= 30, isTrue, reason: 'longe do lembrete de estudo das 19h');
      expect(n.ttlMin, 30);
    }
    // Um por vez: nunca dois avisos do rodízio a menos de 30 minutos um do outro.
    for (var i = 1; i < list.length; i++) {
      expect(list[i].when.difference(list[i - 1].when).inMinutes >= 30, isTrue);
    }
    // O rodízio alterna os assuntos e usa a matéria cadastrada.
    final titles = list.map((n) => n.title).toSet();
    expect(titles.containsAll(['Beba água', 'Alongue o corpo', 'Que tal estudar um pouco?', 'Hora de revisar']), isTrue);
    expect(list.any((n) => n.title == 'Que tal estudar um pouco?' && n.body.contains('Matemática')), isTrue);
    // Só os próximos 3 dias.
    expect(list.every((n) => n.when.isBefore(DateTime(2026, 6, 13))), isTrue);
  });

  test('rodízio: nunca dois avisos seguidos do mesmo assunto e nenhum texto repetido em sequência', () {
    final d = sample();
    final list = planReminderNotices(d, now).where((n) => n.rotating).toList();
    for (var i = 1; i < list.length; i++) {
      expect(list[i].title == list[i - 1].title, isFalse, reason: 'tema repetido em ${list[i].when}');
    }
    // Em qualquer janela de 4 avisos seguidos (2 horas), os 4 assuntos são diferentes.
    for (var i = 3; i < list.length; i++) {
      final w = list.sublist(i - 3, i + 1).where((n) => n.when.day == list[i].when.day).map((n) => n.title).toList();
      expect(w.toSet().length >= w.length - 1, isTrue, reason: 'assuntos repetidos perto de ${list[i].when}: $w');
    }
    // A ordem muda de uma rodada para a outra.
    expect(themeOrder(0).join(',') == themeOrder(1).join(','), isFalse);
    for (var r = 1; r < 40; r++) {
      expect(themeOrder(r).first == themeOrder(r - 1).last, isFalse);
      expect(themeOrder(r).toSet().length, 5);
    }
  });

  test('compromisso do dia entra no rodízio perguntando se já fez', () {
    final d = sample();
    final hoje = dayKey(now);
    d.tasks.add(StudyTask(id: 't', subjectId: 'mat', topic: 'Lista 3', deadline: hoje));
    d.exams.add(Exam(id: 'e', subjectId: 'mat', title: 'Maquete', date: hoje, kind: ExamKind.trabalho));
    var rot = planReminderNotices(d, now).where((n) => n.rotating && n.when.day == now.day).toList();
    expect(rot.any((n) => n.title == 'Atividade para hoje: já fez?' && n.body.contains('Lista 3')), isTrue);
    expect(rot.any((n) => n.title == 'Trabalho para hoje: já fez?' && n.body.contains('Maquete')), isTrue);
    // Continua alternando com os outros avisos e nunca dois no mesmo horário.
    expect(rot.any((n) => n.title == 'Beba água' || n.title == 'Alongue o corpo'), isTrue);
    expect(rot.map((n) => n.when).toSet().length, rot.length);
    // Tarefa concluída sai dos avisos.
    d.tasks.first.status = TaskStatus.done;
    rot = planReminderNotices(d, now).where((n) => n.rotating).toList();
    expect(rot.any((n) => n.title == 'Atividade para hoje: já fez?'), isFalse);
  });

  test('tarefas com prazo e provas geram avisos', () {
    final d = sample();
    d.profile!.nudgeOn = false;
    d.tasks.add(StudyTask(id: 't', subjectId: 'mat', topic: 'Lista 3', deadline: '2026-06-12'));
    d.exams.add(Exam(id: 'e', subjectId: 'mat', title: 'Frações', date: '2026-06-13'));
    final list = planReminderNotices(d, now);
    expect(list.any((n) => n.title == 'Tarefa para amanhã' && n.when.day == 11), isTrue);
    expect(list.any((n) => n.title == 'Prazo hoje' && n.when.day == 12), isTrue);
    expect(list.any((n) => n.title == 'Prova em 3 dias' && n.when.day == 10), isTrue);
    expect(list.any((n) => n.title == 'Prova amanhã' && n.when.day == 12), isTrue);
    expect(list.any((n) => n.title == 'Prova hoje' && n.when.day == 13), isTrue);
  });

  test('várias tarefas e provas no mesmo dia viram um aviso só', () {
    final d = sample();
    d.profile!.nudgeOn = false;
    for (var i = 0; i < 5; i++) {
      d.tasks.add(StudyTask(id: 't$i', subjectId: 'mat', topic: 'Lista $i', deadline: '2026-06-12'));
    }
    d.exams.add(Exam(id: 'e', subjectId: 'mat', title: 'Frações', date: '2026-06-12'));
    final list = planReminderNotices(d, now);
    final dia12 = list.where((n) => n.when.day == 12 && n.when.hour == 8).toList();
    expect(dia12.length, 1);
    expect(dia12.single.title, 'Tarefas e provas de hoje');
    expect(dia12.single.body, contains('e mais 3'));
    expect(list.where((n) => n.when.day == 11 && n.when.hour == 8).length, 1);
  });

  test('o rodízio cede a vez quando há outro aviso a menos de 30 minutos', () {
    final d = sample();
    d.profile!
      ..nudgeEveryMin = 60
      ..studyRemindAt = '10:30';
    final list = planReminderNotices(d, now);
    final others = list.where((n) => !n.rotating).toList();
    for (final n in list.where((n) => n.rotating)) {
      expect(others.every((o) => o.when.difference(n.when).inMinutes.abs() >= 30), isTrue);
    }
  });

  test('dia com sessão planejada não repete o lembrete de estudar', () {
    final d = sample();
    d.profile!.nudgeOn = false;
    d.planSessions.add(PlanSession(id: 'a', subjectId: 'mat', topic: null, day: '2026-06-11', start: '15:00', minutes: 25));
    final list = planReminderNotices(d, now);
    expect(list.any((n) => n.title == 'Hora de estudar' && n.when.day == 11), isFalse);
    expect(list.any((n) => n.title == 'Hora de estudar' && n.when.day == 12), isTrue);
  });

  test('prova chegando entra no rodízio do dia', () {
    final d = sample();
    d.exams.add(Exam(id: 'e', subjectId: 'mat', title: 'Frações', date: '2026-06-15'));
    final list = planReminderNotices(d, now).where((n) => n.rotating).toList();
    expect(list.any((n) => n.title == 'Prova chegando' && n.body.contains('Matemática: Frações')), isTrue);
  });

  test('alarme do temporizador: sessão simples e com intervalos', () {
    final t0 = now.millisecondsSinceEpoch;
    final simple = ActiveSession(kind: SessionKind.exercicio, title: 'Caminhada', focusMin: 10, breakMin: 5, cycles: 1, phaseEndsAt: t0 + 600000, phaseMs: 600000, startedAt: t0);
    final a = planTimerNotices(simple, t0);
    expect(a.length, 1);
    expect(a.single.title, 'Tempo concluído');
    expect(a.single.alarm, isTrue);
    expect(a.single.when.millisecondsSinceEpoch, t0 + 600000);

    final cyc = ActiveSession(kind: SessionKind.estudo, title: 'Foco', focusMin: 25, breakMin: 5, cycles: 2, phaseEndsAt: t0 + 25 * 60000, phaseMs: 25 * 60000, startedAt: t0);
    final b = planTimerNotices(cyc, t0);
    expect(b.map((n) => n.title).toList(), ['Hora do intervalo', 'De volta ao foco', 'Tempo concluído']);
    expect(b.last.when.millisecondsSinceEpoch, t0 + (25 + 5 + 25) * 60000);
    expect(b.last.loop, isTrue, reason: 'o fim da sessão toca em repetição');
    expect(b.first.loop, isFalse);
    expect(b.map((n) => n.id).toList(), [100, 101, 102]);

    // Depois do primeiro foco, os avisos restantes mantêm os mesmos ids.
    cyc
      ..phase = Phase.intervalo
      ..phaseMs = 5 * 60000
      ..phaseEndsAt = t0 + 30 * 60000;
    expect(planTimerNotices(cyc, t0 + 25 * 60000 + 1).map((n) => n.id).toList(), [101, 102]);
    cyc
      ..phase = Phase.foco
      ..phaseEndsAt = t0 + 25 * 60000;

    cyc.paused = true;
    expect(planTimerNotices(cyc, t0), isEmpty);
    expect(planTimerNotices(null, t0), isEmpty);
  });

  test('AppState: ligar pede permissão; negar mantém desligado; pausar remove o alarme', () async {
    String? stored;
    final fake = FakeNotifier();
    final st = AppState(read: () async => stored, write: (s) async { stored = s; return true; }, clear: () async => true, notifier: fake);
    await st.load();
    await st.saveProfile(Profile(nickname: 'Leo'));
    expect(st.plannedNotices(), isEmpty, reason: 'desligado por padrão');

    fake.grant = false;
    expect(await st.enableNotifications(), isFalse);
    expect(st.data.profile!.notifyOn, isFalse);

    fake.grant = true;
    expect(await st.enableNotifications(), isTrue);
    expect(st.data.profile!.notifyOn, isTrue);

    await st.startSession(kind: SessionKind.estudo, title: 'Ler', focusMin: 25);
    expect(st.plannedNotices().any((n) => n.alarm), isTrue);
    await st.pauseSession();
    expect(st.plannedNotices().any((n) => n.alarm), isFalse);
    await st.resumeSession();
    expect(st.plannedNotices().any((n) => n.alarm), isTrue);
    await st.cancelSession();
    expect(st.plannedNotices().any((n) => n.alarm), isFalse);
    expect(fake.dismissed, greaterThan(0), reason: 'cancelar a sessão para o alarme');

    await st.resyncNotifications();
    expect(fake.calls, greaterThan(0));
    st.dispose();
  });
}
