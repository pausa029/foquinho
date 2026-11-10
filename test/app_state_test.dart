import 'package:flutter_test/flutter_test.dart';
import 'package:foquinho/data/app_state.dart';
import 'package:foquinho/models/models.dart';

/// Armazenamento em memória para os testes (sem shared_preferences).
class MemStore {
  String? value;
  bool failWrites = false;
  Future<String?> read() async => value;
  Future<bool> write(String s) async {
    if (failWrites) return false;
    value = s;
    return true;
  }

  Future<bool> clear() async {
    value = null;
    return true;
  }
}

AppState make(MemStore m) => AppState(read: m.read, write: m.write, clear: m.clear);

void main() {
  test('carrega vazio e grava perfil', () async {
    final m = MemStore();
    final st = make(m);
    await st.load();
    expect(st.status, LoadStatus.ok);
    expect(st.hasProfile, isFalse);

    await st.saveProfile(Profile(nickname: 'Leo'));
    await st.finishOnboarding();
    expect(m.value, contains('Leo'));

    final st2 = make(m);
    await st2.load();
    expect(st2.data.profile!.nickname, 'Leo');
    expect(st2.data.onboarded, isTrue);
  });

  test('dados ilegíveis não derrubam o app', () async {
    final m = MemStore()..value = '{isto não é json';
    final st = make(m);
    await st.load();
    expect(st.status, LoadStatus.erroLeitura);
    expect(st.data.subjects, isEmpty);
  });

  test('falha de gravação vira aviso', () async {
    final m = MemStore()..failWrites = true;
    final st = make(m);
    await st.load();
    await st.addSubject('Física');
    expect(st.status, LoadStatus.erroEscrita);
    expect(st.data.subjects.single.name, 'Física');
  });

  test('matérias, provas e tarefas: cadastrar, editar e apagar', () async {
    final st = make(MemStore());
    await st.load();
    final s = await st.addSubject('Química');
    final again = await st.addSubject('química', hard: true);
    expect(again.id, s.id, reason: 'não duplica matéria com o mesmo nome');
    expect(st.data.subjects.single.hard, isTrue);

    await st.upsertExam(Exam(id: 'e', subjectId: s.id, title: 'Ligações', date: '2030-02-02'));
    await st.upsertTask(StudyTask(id: 't', subjectId: s.id, topic: 'Lista 1'));
    await st.setTaskStatus('t', TaskStatus.doing);
    expect(st.data.tasks.single.status, TaskStatus.doing);

    await st.removeSubject(s.id);
    expect(st.data.subjects, isEmpty);
    expect(st.data.exams, isEmpty, reason: 'provas da matéria removida somem');
    expect(st.data.tasks, isEmpty);
  });

  test('sessão simples: iniciar, pausar, retomar, concluir e registrar', () async {
    final st = make(MemStore());
    await st.load();
    final s = await st.addSubject('Geografia');
    await st.upsertTask(StudyTask(id: 't1', subjectId: s.id, topic: 'Mapas'));

    await st.startSession(kind: SessionKind.estudo, title: 'Mapas', subjectId: s.id, taskId: 't1', focusMin: 25);
    expect(st.active, isNotNull);
    expect(st.data.tasks.single.status, TaskStatus.doing, reason: 'tarefa vai para "em andamento"');
    expect(st.remainingMs(), inInclusiveRange(24 * 60000, 25 * 60000));

    await st.pauseSession();
    final r1 = st.remainingMs();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(st.remainingMs(), r1, reason: 'pausado não anda');
    await st.resumeSession();
    expect(st.active!.paused, isFalse);

    // Simula o fim do tempo: o relógio passou do fim da fase.
    st.active!.phaseEndsAt = st.nowMs() - 10;
    expect(st.syncSession(), 'fim');
    expect(st.finished, isTrue);
    expect(st.concludeMinutes(), 25);

    final rec = await st.finishAndRecord(minutes: 25, note: 'foi bem', markTaskDone: true);
    expect(rec, isNotNull);
    expect(st.active, isNull);
    expect(st.data.sessions.single.minutes, 25);
    expect(st.data.sessions.single.note, 'foi bem');
    expect(st.data.tasks.single.status, TaskStatus.done);
  });

  test('sessão com intervalos avança foco -> intervalo -> foco -> fim', () async {
    final st = make(MemStore());
    await st.load();
    await st.startSession(kind: SessionKind.estudo, title: 'Foco', focusMin: 25, breakMin: 5, cycles: 2);
    final a = st.active!;
    a.phaseEndsAt = st.nowMs() - 1;
    expect(st.syncSession(), 'intervalo');
    expect(a.phase, Phase.intervalo);
    expect(a.focusDoneMs, 25 * 60000);
    a.phaseEndsAt = st.nowMs() - 1;
    expect(st.syncSession(), 'foco');
    expect(a.cycleIndex, 2);
    a.phaseEndsAt = st.nowMs() - 1;
    expect(st.syncSession(), 'fim');
    expect(st.concludeMinutes(), 50);
  });

  test('cancelar não registra nada', () async {
    final st = make(MemStore());
    await st.load();
    await st.startSession(kind: SessionKind.exercicio, title: 'Caminhada', focusMin: 10);
    await st.cancelSession();
    expect(st.active, isNull);
    expect(st.data.sessions, isEmpty);
  });

  test('sessão em andamento sobrevive ao fechar e abrir o app', () async {
    final m = MemStore();
    final st = make(m);
    await st.load();
    await st.startSession(kind: SessionKind.estudo, title: 'Persistente', focusMin: 10);
    final st2 = make(m);
    await st2.load();
    expect(st2.active, isNotNull);
    expect(st2.active!.title, 'Persistente');
  });

  test('tempo de tela manual e histórico', () async {
    final st = make(MemStore());
    await st.load();
    await st.setScreenMinutes('2026-01-05', 90);
    expect(st.data.screenLog['2026-01-05'], 90);
    await st.setScreenMinutes('2026-01-05', null);
    expect(st.data.screenLog.containsKey('2026-01-05'), isFalse);

    await st.addSession(Session(id: 'x', kind: SessionKind.estudo, title: 't', minutes: 5, startedAt: 0));
    await st.clearHistory();
    expect(st.data.sessions, isEmpty);
  });

  test('apagar tudo limpa perfil e dados', () async {
    final m = MemStore();
    final st = make(m);
    await st.load();
    await st.saveProfile(Profile(nickname: 'Zé'));
    await st.addSubject('Artes');
    await st.deleteEverything();
    expect(st.data.profile, isNull);
    expect(st.data.subjects, isEmpty);
    expect(st.data.onboarded, isFalse);
    expect(m.value, isNot(contains('Zé')));
  });
}
