import 'package:flutter_test/flutter_test.dart';
import 'package:foquinho/models/models.dart';

void main() {
  // Escola do exemplo: 3 unidades; cada uma Qualitativo 2 + Simulados 8 + Prova 8 + Projeto 2 = 20.
  test('sem notas: precisa de 60% de 60 pontos', () {
    final c = GradeConfig();
    final st = gradeStatus(c, [], 'mat');
    expect(c.yearMax('mat'), 60);
    expect(st.pass, 36);
    expect(st.remainingMax, 60);
    expect(st.neededPct, closeTo(60, 0.01));
    expect(st.passed, isFalse);
  });

  test('calcula quanto falta com as notas lançadas', () {
    final c = GradeConfig();
    final g = [
      Grade(subjectId: 'mat', unit: 1, part: 'Qualitativo', value: 2),
      Grade(subjectId: 'mat', unit: 1, part: 'Simulados', value: 6),
      Grade(subjectId: 'mat', unit: 1, part: 'Prova', value: 5),
      Grade(subjectId: 'mat', unit: 1, part: 'Projeto', value: 2),
    ];
    final st = gradeStatus(c, g, 'mat');
    expect(st.earned, 15);
    expect(st.missing, 21);
    expect(st.remainingMax, 40);
    expect(st.neededPct, closeTo(52.5, 0.01));
  });

  test('matéria com partes diferentes e situação impossível', () {
    final c = GradeConfig(units: 1, passPct: 60);
    c.bySubject['art'] = [GradePart('Projeto', 6), GradePart('Prova', 4)];
    expect(c.unitMax('art'), 10);
    final st = gradeStatus(c, [Grade(subjectId: 'art', unit: 1, part: 'Projeto', value: 1)], 'art');
    expect(st.missing, 5);
    expect(st.remainingMax, 4);
    expect(st.impossible, isTrue);
  });

  test('salva e lê de volta', () {
    final d = AppData(grading: GradeConfig(units: 4, unitName: 'Bimestre', passPct: 70));
    d.subjects.add(Subject(id: 'mat', name: 'Matemática'));
    d.grading.bySubject['mat'] = [GradePart('Prova', 10)];
    d.grades.add(Grade(subjectId: 'mat', unit: 2, part: 'Prova', value: 7.5));
    final back = AppData.fromJson(d.toJson());
    expect(back.grading.units, 4);
    expect(back.grading.unitName, 'Bimestre');
    expect(back.grading.passPct, 70);
    expect(back.grading.partsFor('mat').single.max, 10);
    expect(back.grades.single.value, 7.5);
    expect(fmtPts(7.5), '7,5');
    expect(fmtPts(8), '8');
  });
}
