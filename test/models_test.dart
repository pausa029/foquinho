import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foquinho/models/models.dart';

void main() {
  group('dayKey e parseDayKey', () {
    test('ida e volta', () {
      final d = DateTime(2026, 3, 7, 15, 30);
      expect(dayKey(d), '2026-03-07');
      final back = parseDayKey('2026-03-07')!;
      expect(back.year, 2026);
      expect(back.month, 3);
      expect(back.day, 7);
    });

    test('rejeita datas inválidas', () {
      expect(parseDayKey('2026-02-30'), isNull);
      expect(parseDayKey('abc'), isNull);
      expect(parseDayKey(null), isNull);
    });
  });

  group('validHm', () {
    test('normaliza e valida horários', () {
      expect(validHm('8:05'), '08:05');
      expect(validHm('23:59'), '23:59');
      expect(validHm('24:00'), isNull);
      expect(validHm('oi'), isNull);
    });
  });

  group('AppData JSON', () {
    test('ida e volta preserva os dados', () {
      final d = AppData(
        profile: Profile(nickname: 'Ana', sports: ['Corrida'], studyGoalMin: 90, screenGoalMin: 180),
        onboarded: true,
      );
      d.subjects.add(Subject(id: 's1', name: 'Matemática', hard: true, topics: ['Frações']));
      d.exams.add(Exam(id: 'e1', subjectId: 's1', title: 'Frações', date: '2030-01-10'));
      d.tasks.add(StudyTask(id: 't1', subjectId: 's1', topic: 'Lista 2', minutes: 30));
      d.sessions.add(Session(id: 'x1', kind: SessionKind.estudo, title: 'Estudar', subjectId: 's1', minutes: 25, startedAt: 1700000000000));
      d.screenLog['2026-01-01'] = 200;

      final json = jsonEncode(d.toJson());
      final back = AppData.fromJson(jsonDecode(json) as Map<String, dynamic>);

      expect(back.profile!.nickname, 'Ana');
      expect(back.profile!.sports, ['Corrida']);
      expect(back.profile!.studyGoalMin, 90);
      expect(back.profile!.screenGoalMin, 180);
      expect(back.onboarded, isTrue);
      expect(back.subjects.single.hard, isTrue);
      expect(back.subjects.single.topics, ['Frações']);
      expect(back.exams.single.date, '2030-01-10');
      expect(back.tasks.single.minutes, 30);
      expect(back.sessions.single.minutes, 25);
      expect(back.screenLog['2026-01-01'], 200);
      expect(back.activities.length, defaultActivities().length);
    });

    test('ignora registros corrompidos sem quebrar', () {
      final back = AppData.fromJson({
        'subjects': [
          {'id': 's1', 'name': 'História'},
          {'name': 'sem id'},
          'lixo',
        ],
        'exams': [
          {'id': 'e1', 'subjectId': 's1', 'date': '2026-99-99'},
          {'id': 'e2', 'subjectId': 'inexistente'},
        ],
        'sessions': [
          {'id': 'a', 'minutes': 'dez', 'startedAt': 1},
          {'id': 'b', 'minutes': 10, 'startedAt': 1},
        ],
        'screenLog': {'2026-01-01': 100, 'ruim': 5, '2026-01-02': 'x'},
      });
      expect(back.subjects.length, 1);
      expect(back.exams.length, 1);
      expect(back.exams.single.date, isNull);
      expect(back.sessions.length, 1);
      expect(back.screenLog.keys.toList(), ['2026-01-01']);
    });
  });

  test('Exam.daysUntil conta a partir de hoje', () {
    final now = DateTime(2026, 5, 10, 20);
    expect(Exam(id: '1', subjectId: 's', title: '', date: '2026-05-10').daysUntil(now), 0);
    expect(Exam(id: '1', subjectId: 's', title: '', date: '2026-05-13').daysUntil(now), 3);
    expect(Exam(id: '1', subjectId: 's', title: '', date: '2026-05-09').daysUntil(now), -1);
    expect(Exam(id: '1', subjectId: 's', title: '').daysUntil(now), isNull);
  });

  test('tutorial da Foquinha: começa não visto e é lembrado depois de visto', () {
    final d = AppData();
    expect(d.tourDone, isFalse);
    d.tourDone = true;
    expect(AppData.fromJson(d.toJson()).tourDone, isTrue);
    expect(AppData.fromJson(<String, dynamic>{}).tourDone, isFalse);
  });
}
