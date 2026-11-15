import 'package:flutter_test/flutter_test.dart';
import 'package:foquinho/logic/report.dart';
import 'package:foquinho/logic/suggestions.dart';
import 'package:foquinho/models/models.dart';
import 'package:foquinho/services/cloud.dart';

import 'app_state_test.dart' show MemStore, make;

String inDays(int n) {
  final t = DateTime.now();
  return dayKey(DateTime(t.year, t.month, t.day + n, 12));
}

void main() {
  test('erros do quiz vão para o caderno, sem repetir, e voltam 1, 3 e 7 dias depois', () async {
    final st = make(MemStore());
    await st.load();
    final s = await st.addSubject('Matemática');
    const q = QuizQuestion(q: '2 + 2 = ?', options: ['3', '4', '5', '6'], answer: 1, explain: 'Dois mais dois é quatro.');
    expect(await st.addQuizMistakes(s.id, 'Soma', [q]), 1);
    expect(await st.addQuizMistakes(s.id, 'Soma', [q]), 0, reason: 'mesma pergunta não entra de novo');
    final e = st.data.mistakes.single;
    expect(e.due, inDays(1));
    expect(st.mistakesDue, isEmpty);
    await st.answerMistake(e.id, true);
    expect(e.due, inDays(3));
    await st.answerMistake(e.id, false);
    expect(e.streak, 0);
    expect(e.due, inDays(1));
    for (var i = 0; i < 3; i++) {
      await st.answerMistake(e.id, true);
    }
    expect(e.learned, isTrue);
  });

  test('erro anotado à mão, sugestão de refazer e salvar/ler', () async {
    final st = make(MemStore());
    await st.load();
    final s = await st.addSubject('História');
    await st.addMistake(subjectId: s.id, question: 'Quando foi a Independência?', answerText: '1822');
    final e = st.data.mistakes.single;
    expect(e.hasOptions, isFalse);
    e.due = inDays(0);
    expect(st.mistakesDue.length, 1);
    final sug = studySuggestions(st.data, limit: 10);
    expect(sug.any((x) => x.title.contains('caderno de erros')), isTrue);
    final back = AppData.fromJson(st.data.toJson());
    expect(back.mistakes.single.answerText, '1822');
    await st.removeSubject(s.id);
    expect(st.data.mistakes, isEmpty);
  });

  test('relatório: soma por matéria e aponta o que está para trás', () {
    final now = DateTime(2026, 6, 20, 12);
    final d = AppData();
    d.subjects.addAll([Subject(id: 'mat', name: 'Matemática', hard: true), Subject(id: 'his', name: 'História')]);
    d.sessions.add(Session(id: 's1', kind: SessionKind.estudo, title: 'x', subjectId: 'his', minutes: 90, startedAt: DateTime(2026, 6, 19, 10).millisecondsSinceEpoch));
    d.sessions.add(Session(id: 's2', kind: SessionKind.estudo, title: 'x', subjectId: 'mat', minutes: 20, startedAt: DateTime(2026, 6, 5, 10).millisecondsSinceEpoch));
    d.exams.add(Exam(id: 'e1', subjectId: 'mat', title: 'Frações', date: '2026-06-25'));
    final week = subjectReport(d, days: 7, now: now);
    final mat = week.firstWhere((r) => r.subject.id == 'mat');
    final his = week.firstWhere((r) => r.subject.id == 'his');
    expect(his.minutes, 90);
    expect(mat.minutes, 0);
    expect(mat.daysSinceLast, 15);
    expect(mat.behind, isTrue);
    expect(mat.alerts.any((a) => a.contains('Prova em 5 dias')), isTrue);
    expect(week.first.subject.id, 'mat', reason: 'quem está para trás aparece primeiro');
    final month = subjectReport(d, days: 30, now: now);
    expect(month.firstWhere((r) => r.subject.id == 'mat').minutes, 20);
  });
}
