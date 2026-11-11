import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foquinho/data/app_state.dart';
import 'package:foquinho/logic/planner.dart';
import 'package:foquinho/logic/reminders.dart';
import 'package:foquinho/models/models.dart';

/// Segunda a sexta, das 18h às 20h, até 90 min por dia, sessões de 25 min com 10 de intervalo.
PlanSettings settings({int dailyMax = 90}) {
  final s = PlanSettings(dailyMaxMin: dailyMax, sessionMin: 25, gapMin: 10, configured: true);
  for (var i = 0; i < 5; i++) {
    s.days[i] = DayAvail(on: true, from: '18:00', to: '20:00');
  }
  return s;
}

AppData sample({PlanSettings? plan}) {
  final d = AppData(profile: Profile(nickname: 'Bia'), onboarded: true, plan: plan ?? settings());
  d.subjects.addAll([
    Subject(id: 'mat', name: 'Matemática', hard: true, topics: ['Equações', 'Funções']),
    Subject(id: 'his', name: 'História'),
    Subject(id: 'ing', name: 'Inglês'),
  ]);
  return d;
}

int countOf(List<PlanSession> l, String id) => l.where((p) => p.subjectId == id).length;

void checkRules(AppData d, List<PlanSession> all) {
  final byDay = <String, List<PlanSession>>{};
  for (final p in all) {
    byDay.putIfAbsent(p.day, () => []).add(p);
  }
  byDay.forEach((day, list) {
    list.sort((a, b) => a.startMin.compareTo(b.startMin));
    final dt = parseDayKey(day)!;
    expect(dayAvailable(d.plan, dt), isTrue, reason: 'dia $day indisponível');
    final a = d.plan.days[dt.weekday - 1];
    final total = list.fold<int>(0, (x, p) => x + p.minutes);
    expect(total, lessThanOrEqualTo(d.plan.dailyMaxMin), reason: 'limite diário em $day');
    expect(total, lessThanOrEqualTo((a.minutes * 0.8).floor()), reason: 'teto de 80% em $day');
    for (var i = 0; i < list.length; i++) {
      expect(list[i].startMin, greaterThanOrEqualTo(hmToMinutes(a.from)));
      expect(list[i].endMin, lessThanOrEqualTo(hmToMinutes(a.to)));
      if (i > 0) {
        expect(list[i].startMin, greaterThanOrEqualTo(list[i - 1].endMin), reason: 'sessões sobrepostas em $day');
        expect(list[i].subjectId == list[i - 1].subjectId, isFalse, reason: 'mesma matéria seguida em $day');
      }
    }
    for (final s in d.subjects) {
      expect(countOf(list, s.id), lessThanOrEqualTo(2), reason: 'mais de 2 de ${s.name} em $day');
    }
  });
}

void main() {
  final now = DateTime(2026, 6, 8, 7, 0); // segunda-feira, 7h
  final mon = DateTime(2026, 6, 8, 12);
  final sun = DateTime(2026, 6, 14, 12);

  test('plano semanal respeita horários, limite, 80% e alternância', () {
    final d = sample();
    final r = generatePlan(d, mon, sun, now);
    expect(r.sessions.length, greaterThan(10));
    expect(r.sessions.length, lessThanOrEqualTo(15));
    checkRules(d, r.sessions);
    expect(r.leftovers, isEmpty);
    for (final s in d.subjects) {
      expect(countOf(r.sessions, s.id), greaterThan(0), reason: '${s.name} sem sessão');
    }
    // Só usa assuntos cadastrados.
    for (final p in r.sessions) {
      if (p.subjectId == 'mat') {
        expect(['Equações', 'Funções'].contains(p.topic), isTrue);
      } else {
        expect(p.topic, isNull);
      }
    }
  });

  test('matéria difícil recebe mais sessões', () {
    final r = generatePlan(sample(), mon, sun, now);
    expect(countOf(r.sessions, 'mat'), greaterThan(countOf(r.sessions, 'his')));
    expect(countOf(r.sessions, 'mat'), greaterThan(countOf(r.sessions, 'ing')));
  });

  test('plano mensal só usa dias de hoje em diante', () {
    final d = sample();
    final r = generatePlan(d, DateTime(2026, 6, 1, 12), DateTime(2026, 6, 30, 12), now);
    expect(r.sessions.length, greaterThan(30));
    expect(r.sessions.every((p) => p.day.compareTo('2026-06-08') >= 0 && p.day.compareTo('2026-06-30') <= 0), isTrue);
    checkRules(d, r.sessions);
  });

  test('prova próxima tem prioridade e revisão na véspera', () {
    final d = sample();
    d.exams.add(Exam(id: 'e', subjectId: 'his', title: 'Era Vargas', date: '2026-06-11'));
    final r = generatePlan(d, mon, sun, now);
    checkRules(d, r.sessions);
    expect(r.sessions.first.subjectId, 'his', reason: 'a primeira sessão da semana vai para a prova mais próxima');
    final before = r.sessions.where((p) => p.subjectId == 'his' && p.day.compareTo('2026-06-11') < 0).toList();
    expect(before.length, greaterThanOrEqualTo(2));
    expect(before.any((p) => p.day == '2026-06-10' && p.topic == 'Era Vargas'), isTrue, reason: 'revisão na véspera');
    expect(countOf(r.sessions, 'his'), greaterThan(countOf(r.sessions, 'ing')));
  });

  test('dias indisponíveis, datas bloqueadas e limite diário', () {
    final d = sample(plan: settings(dailyMax: 30));
    d.plan.blocked.add('2026-06-10');
    final r = generatePlan(d, mon, sun, now);
    checkRules(d, r.sessions);
    expect(r.sessions.any((p) => p.day == '2026-06-10'), isFalse);
    expect(r.sessions.any((p) => p.day == '2026-06-13' || p.day == '2026-06-14'), isFalse);
    expect(r.sessions.length, 4, reason: 'uma sessão por dia em quatro dias');
  });

  test('sem tempo para tudo: informa o que ficou de fora e aceita prioridade', () {
    final s = PlanSettings(dailyMaxMin: 90, sessionMin: 25, gapMin: 10, configured: true);
    s.days[0] = DayAvail(on: true, from: '18:00', to: '18:40');
    final d = sample(plan: s);
    final r = generatePlan(d, mon, sun, now);
    expect(r.sessions.length, 1);
    expect(r.leftovers.length, 2);
    final r2 = generatePlan(d, mon, sun, now, prioritize: {'ing'});
    expect(r2.sessions.single.subjectId, 'ing');
  });

  test('falta de dados não gera plano', () {
    final semMaterias = AppData(profile: Profile(nickname: 'x'), plan: settings());
    expect(generatePlan(semMaterias, mon, sun, now).sessions, isEmpty);
    final semDisp = sample(plan: PlanSettings());
    expect(generatePlan(semDisp, mon, sun, now).sessions, isEmpty);
    final semDias = sample(plan: PlanSettings(configured: true));
    final r = generatePlan(semDias, mon, sun, now);
    expect(r.sessions, isEmpty);
    expect(r.slots, 0);
  });

  test('gerar de novo preserva concluídas, fixadas e manuais', () {
    final d = sample();
    final r = generatePlan(d, mon, sun, now);
    d.planSessions.addAll(r.sessions);
    final done = d.planSessions[0]..state = PlanState.concluida;
    final pinned = d.planSessions[1]..pinned = true;
    final manual = PlanSession(id: 'm1', subjectId: 'ing', day: '2026-06-12', start: '18:00', minutes: 25, manual: true);
    d.planSessions.add(manual);

    final r2 = generatePlan(d, mon, sun, now);
    final keptIds = r2.kept.map((p) => p.id).toSet();
    expect(keptIds.containsAll([done.id, pinned.id, 'm1']), isTrue);
    expect(r2.kept.firstWhere((p) => p.id == done.id).state, PlanState.concluida);
    final all = [...r2.kept, ...r2.sessions];
    expect(all.map((p) => p.id).toSet().length, all.length, reason: 'ids únicos');
    // Nenhuma sessão nova bate com as preservadas.
    for (final n in r2.sessions) {
      for (final k in r2.kept.where((k) => k.day == n.day)) {
        expect(n.startMin < k.endMin && k.startMin < n.endMin, isFalse);
      }
    }
    final byDay = <String, int>{};
    for (final p in all) {
      byDay[p.day] = (byDay[p.day] ?? 0) + p.minutes;
    }
    expect(byDay.values.every((m) => m <= 90), isTrue);
  });

  test('conflito de horário, limite diário e alternativas', () {
    final d = sample(plan: settings(dailyMax: 30));
    d.planSessions.add(PlanSession(id: 'a', subjectId: 'mat', day: '2026-06-08', start: '18:00', minutes: 25));
    expect(checkSlot(d, day: '2026-06-08', startMin: 18 * 60 + 10, minutes: 25).overlap, isTrue);
    expect(checkSlot(d, day: '2026-06-08', startMin: 19 * 60, minutes: 25).overLimit, isTrue);
    expect(checkSlot(d, day: '2026-06-13', startMin: 18 * 60, minutes: 25).unavailable, isTrue);
    expect(checkSlot(d, day: '2026-06-08', startMin: 18 * 60, minutes: 25, ignoreId: 'a').ok, isTrue, reason: 'mover para o próprio horário');
    expect(checkSlot(d, day: '2026-06-09', startMin: 18 * 60, minutes: 25).ok, isTrue);

    final opts = suggestSlots(d, mon, 25, now);
    expect(opts.length, 3);
    expect(opts.first.day, '2026-06-09', reason: 'segunda já está no limite');
    for (final o in opts) {
      expect(checkSlot(d, day: o.day, startMin: o.startMin, minutes: 25).ok, isTrue);
    }

    final d2 = sample();
    d2.planSessions.add(PlanSession(id: 'a', subjectId: 'mat', day: '2026-06-08', start: '18:00', minutes: 25));
    final o2 = suggestSlots(d2, mon, 25, now);
    expect(o2.first.day, '2026-06-08');
    expect(o2.first.startMin, 18 * 60 + 35, reason: 'depois da sessão existente e do intervalo');
  });

  test('progresso, próxima sessão e sessões que ficaram para depois', () {
    final d = sample();
    d.planSessions.addAll([
      PlanSession(id: 'old', subjectId: 'mat', day: '2026-06-05', start: '18:00', minutes: 25),
      PlanSession(id: 'a', subjectId: 'mat', day: '2026-06-08', start: '18:00', minutes: 25, state: PlanState.concluida),
      PlanSession(id: 'b', subjectId: 'his', day: '2026-06-08', start: '18:35', minutes: 25),
    ]);
    final p = planProgress(sessionsBetween(d, '2026-06-08', '2026-06-14'));
    expect(p.total, 2);
    expect(p.done, 1);
    expect(nextPlanned(d, now)!.id, 'b');
    expect(missedSessions(d, now).single.id, 'old');
  });

  test('o plano persiste no JSON e some junto com a matéria', () async {
    final d = sample();
    d.planSessions.add(PlanSession(id: 'a', subjectId: 'mat', topic: 'Equações', day: '2026-06-08', start: '18:00', minutes: 25, pinned: true, moved: true, state: PlanState.incompleta));
    d.plan.blocked.add('2026-06-10');
    final back = AppData.fromJson(jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>);
    expect(back.plan.configured, isTrue);
    expect(back.plan.days[0].on, isTrue);
    expect(back.plan.days[5].on, isFalse);
    expect(back.plan.blocked, ['2026-06-10']);
    final p = back.planSessions.single;
    expect([p.topic, p.day, p.start, p.minutes, p.pinned, p.moved, p.state], ['Equações', '2026-06-08', '18:00', 25, true, true, PlanState.incompleta]);

    String? stored = jsonEncode(d.toJson());
    final st = AppState(read: () async => stored, write: (s) async { stored = s; return true; }, clear: () async => true);
    await st.load();
    expect(st.data.planSessions.length, 1);
    await st.removeSubject('mat');
    expect(st.data.planSessions, isEmpty);
  });

  test('AppState: editar, concluir, excluir, fixar, pausar e apagar', () async {
    String? stored;
    final st = AppState(read: () async => stored, write: (s) async { stored = s; return true; }, clear: () async => true);
    await st.load();
    final sub = await st.addSubject('Física');
    await st.savePlanSettings(settings());
    final a = PlanSession(id: 'a', subjectId: sub.id, day: '2026-06-08', start: '18:00', minutes: 25);
    final b = PlanSession(id: 'b', subjectId: sub.id, day: '2026-06-09', start: '18:00', minutes: 25);
    await st.upsertPlanSession(a);
    await st.upsertPlanSession(b);

    // Concluir pelo temporizador: 25 de 25 min = concluída; 10 de 25 = incompleta.
    await st.startSession(kind: SessionKind.estudo, title: 'x', subjectId: sub.id, planId: 'a', focusMin: 25);
    st.active!.phaseEndsAt = st.nowMs() - 1;
    st.syncSession();
    await st.finishAndRecord(minutes: 25);
    expect(st.data.planSessions.firstWhere((p) => p.id == 'a').state, PlanState.concluida);
    await st.startSession(kind: SessionKind.estudo, title: 'x', subjectId: sub.id, planId: 'b', focusMin: 25);
    await st.finishAndRecord(minutes: 10);
    expect(st.data.planSessions.firstWhere((p) => p.id == 'b').state, PlanState.incompleta);

    // Concluir à mão registra no histórico.
    final before = st.data.sessions.length;
    await st.setPlanState('b', PlanState.concluida, record: true);
    expect(st.data.sessions.length, before + 1);

    await st.togglePlanPin('a');
    expect(st.data.planSessions.firstWhere((p) => p.id == 'a').pinned, isTrue);
    await st.upsertPlanSession(PlanSession(id: 'b', subjectId: sub.id, day: '2026-06-10', start: '19:00', minutes: 30, moved: true));
    final moved = st.data.planSessions.firstWhere((p) => p.id == 'b');
    expect([moved.day, moved.start, moved.minutes, moved.moved], ['2026-06-10', '19:00', 30, true]);
    await st.removePlanSession('b');
    expect(st.data.planSessions.length, 1);
    await st.setPlanPaused(true);
    expect(st.data.plan.paused, isTrue);

    final st2 = AppState(read: () async => stored, write: (s) async { stored = s; return true; }, clear: () async => true);
    await st2.load();
    expect(st2.data.planSessions.single.id, 'a');
    expect(st2.data.plan.paused, isTrue);

    await st.clearPlan();
    expect(st.data.planSessions, isEmpty);
    expect(st.data.plan.configured, isTrue, reason: 'a disponibilidade continua');
  });

  test('applyPlan troca só o período e guarda a assinatura das provas', () async {
    String? stored;
    final st = AppState(read: () async => stored, write: (s) async { stored = s; return true; }, clear: () async => true);
    await st.load();
    st.data = sample();
    st.data.planSessions.add(PlanSession(id: 'fora', subjectId: 'mat', day: '2026-06-20', start: '18:00', minutes: 25));
    final r = generatePlan(st.data, mon, sun, now);
    await st.applyPlan(r, mon, sun);
    expect(st.data.planSessions.any((p) => p.id == 'fora'), isTrue);
    expect(st.data.planSessions.length, r.sessions.length + 1);
    expect(st.data.plan.examSig, examSignature(st.data));
    st.data.exams.add(Exam(id: 'e', subjectId: 'his', title: 'x', date: '2026-06-12'));
    expect(st.data.plan.examSig == examSignature(st.data), isFalse, reason: 'prova nova pede atualização');
  });

  test('aviso 10 minutos antes da sessão planejada; plano pausado não avisa', () {
    final d = sample();
    d.profile!.nudgeOn = false;
    d.planSessions.add(PlanSession(id: 'a', subjectId: 'mat', topic: 'Equações', day: '2026-06-08', start: '18:00', minutes: 25));
    final list = planReminderNotices(d, now);
    final n = list.firstWhere((x) => x.title == 'Sessão de estudo em 10 minutos');
    expect(n.when, DateTime(2026, 6, 8, 17, 50));
    expect(n.body, contains('Matemática: Equações'));
    d.plan.paused = true;
    expect(planReminderNotices(d, now).any((x) => x.title == 'Sessão de estudo em 10 minutos'), isFalse);
  });

  test('mural: mostra provas e atividades e sugere sessão antes da data', () {
    final d = sample();
    d.exams.add(Exam(id: 'e', subjectId: 'mat', title: 'Frações', date: '2026-06-11')); // quinta
    d.tasks.add(StudyTask(id: 't', subjectId: 'his', topic: 'Resumo cap. 2', deadline: '2026-06-09'));
    d.tasks.add(StudyTask(id: 'f', subjectId: 'ing', topic: 'Feita', deadline: '2026-06-09', status: TaskStatus.done));
    final items = boardItems(d);
    expect(items.map((i) => i.id).toList(), ['t', 'e']);
    expect(items.last.kind, BoardKind.prova);

    var sugs = boardSuggestions(d, now);
    expect(sugs.length, 2);
    expect(sugs.first.item.id, 't'); // o que vence antes vem primeiro
    final task = sugs.first, exam = sugs.last;
    expect(task.wanted, 1);
    expect(task.slot, isNotNull);
    expect(task.slot!.day.compareTo('2026-06-09') <= 0, isTrue);
    expect(exam.wanted, 3);
    expect(exam.slot!.day.compareTo('2026-06-11') < 0, isTrue);

    // Reservou a sessão da atividade: a sugestão dela some.
    d.planSessions.add(PlanSession(id: 'x', subjectId: 'his', topic: 'Resumo cap. 2', day: task.slot!.day, start: hmFromMinutes(task.slot!.startMin), minutes: 25, manual: true));
    sugs = boardSuggestions(d, now);
    expect(sugs.any((s) => s.item.id == 't'), isFalse);
    // O horário reservado não é oferecido de novo.
    final again = sugs.single.slot!;
    expect(again.day == task.slot!.day && again.startMin == task.slot!.startMin, isFalse);
  });
}
