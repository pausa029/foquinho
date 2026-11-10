import 'package:flutter_test/flutter_test.dart';
import 'package:telatchau/logic/stats.dart';
import 'package:telatchau/logic/suggestions.dart';
import 'package:telatchau/models/models.dart';

AppData sample() {
  final d = AppData(profile: Profile(nickname: 'Bia', sports: ['Futebol']), onboarded: true);
  d.subjects.addAll([
    Subject(id: 'mat', name: 'Matemática', hard: true, topics: ['Equações']),
    Subject(id: 'his', name: 'História', topics: ['Era Vargas']),
    Subject(id: 'ing', name: 'Inglês'),
  ]);
  d.exams.add(Exam(id: 'e1', subjectId: 'his', title: 'Era Vargas', date: '2026-06-12'));
  d.tasks.add(StudyTask(id: 't1', subjectId: 'ing', topic: 'Verbos', minutes: 20, deadline: '2026-06-20'));
  return d;
}

void main() {
  group('stats', () {
    test('dia sem registro não tem dados', () {
      final d = sample();
      final s = dayStats(d, '2026-06-01');
      expect(s.hasData, isFalse);
      expect(s.screenMin, isNull);
    });

    test('soma estudo e exercício por dia e por semana', () {
      final d = sample();
      final mon = DateTime(2026, 6, 8, 10); // segunda-feira
      final tue = DateTime(2026, 6, 9, 10);
      d.sessions.addAll([
        Session(id: '1', kind: SessionKind.estudo, title: 'a', subjectId: 'mat', minutes: 25, startedAt: mon.millisecondsSinceEpoch),
        Session(id: '2', kind: SessionKind.estudo, title: 'b', subjectId: 'mat', minutes: 15, startedAt: mon.millisecondsSinceEpoch),
        Session(id: '3', kind: SessionKind.exercicio, title: 'c', minutes: 10, startedAt: tue.millisecondsSinceEpoch),
      ]);
      d.screenLog['2026-06-09'] = 120;
      final day = dayStats(d, '2026-06-08');
      expect(day.studyMin, 40);
      expect(day.moveMin, 0);
      expect(day.bySubject['mat'], 40);

      final w = weekStats(d, weekStart(tue));
      expect(w.start, '2026-06-08');
      expect(w.studyMin, 40);
      expect(w.moveMin, 10);
      expect(w.studyDays, 1);
      expect(w.moveDays, 1);
      expect(w.screenDays, 1);
      expect(w.screenAvg, 120);
      expect(w.days.length, 7);
    });

    test('weekStart devolve segunda-feira', () {
      expect(dayKey(weekStart(DateTime(2026, 6, 14))), '2026-06-08'); // domingo -> segunda anterior
      expect(dayKey(weekStart(DateTime(2026, 6, 8))), '2026-06-08');
    });

    test('formatação de minutos', () {
      expect(fmtMin(45), '45 min');
      expect(fmtMin(60), '1h');
      expect(fmtMin(125), '2h05');
      expect(fmtClock(61000), '01:01');
      expect(fmtClock(0), '00:00');
    });
  });

  group('sugestões', () {
    test('prova próxima vem primeiro, depois matéria difícil e tarefa', () {
      final d = sample();
      final list = studySuggestions(d, now: DateTime(2026, 6, 10));
      expect(list.isNotEmpty, isTrue);
      expect(list.first.subjectId, 'his');
      expect(list.first.title, contains('Era Vargas'));
      expect(list.any((s) => s.subjectId == 'mat' && s.title.contains('questões')), isTrue);
      expect(list.any((s) => s.taskId == 't1'), isTrue);
    });

    test('sem cadastro, sem sugestões inventadas', () {
      final d = AppData(profile: Profile(nickname: 'X'));
      expect(studySuggestions(d), isEmpty);
    });

    test('provas passadas não aparecem', () {
      final d = sample();
      final list = studySuggestions(d, now: DateTime(2026, 7, 1));
      expect(list.any((s) => s.title.contains('prova')), isFalse);
    });

    test('movimento prioriza esporte preferido e respeita filtros', () {
      final d = sample();
      final list = moveSuggestions(d, limit: 3);
      expect(list.first.activity!.sport, 'Futebol');
      final short = moveSuggestions(d, maxMinutes: 5, limit: 20);
      expect(short.every((s) => s.minutes <= 5), isTrue);
      final home = moveSuggestions(d, place: Place.casa, limit: 20);
      expect(home.every((s) => s.activity!.place != Place.arLivre), isTrue);
    });
  });
}
