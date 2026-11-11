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

  test('agenda estudo e movimento todos os dias, sempre no futuro', () {
    final d = sample();
    d.profile!.nudgeOn = false;
    final list = planReminderNotices(d, now);
    expect(list.where((n) => n.title == 'Hora de estudar').length, 7);
    expect(list.where((n) => n.title == 'Hora de se mexer').length, 7);
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
    final list = planReminderNotices(d, now).where((n) => n.title == 'Pausa de tela').toList();
    expect(list, isNotEmpty);
    for (final n in list) {
      final m = n.when.hour * 60 + n.when.minute;
      expect(m, greaterThan(8 * 60));
      expect(m, lessThan(21 * 60));
      expect((m - 19 * 60).abs() >= 20 && (m - 17 * 60).abs() >= 20, isTrue);
    }
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
