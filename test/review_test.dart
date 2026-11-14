import 'package:flutter_test/flutter_test.dart';
import 'package:foquinho/data/app_state.dart';
import 'package:foquinho/logic/reminders.dart';
import 'package:foquinho/models/models.dart';

import 'app_state_test.dart' show MemStore, make;

String inDays(int n) {
  final t = DateTime.now();
  return dayKey(DateTime(t.year, t.month, t.day + n, 12));
}

void main() {
  Future<AppState> withStudy() async {
    final m = MemStore();
    final st = make(m);
    await st.load();
    await st.saveProfile(Profile(nickname: 'Bia'));
    final s = await st.addSubject('Matemática');
    await st.startSession(kind: SessionKind.estudo, title: 'Frações', subjectId: s.id, topic: 'Frações', focusMin: 25);
    await st.finishAndRecord(minutes: 25);
    return st;
  }

  test('estudar um assunto agenda a 1ª revisão para amanhã', () async {
    final st = await withStudy();
    expect(st.data.reviews.length, 1);
    final r = st.data.reviews.single;
    expect(r.topic, 'Frações');
    expect(r.step, 0);
    expect(r.due, inDays(1));
    expect(st.reviewsDue, isEmpty);
    expect(st.reviewsUpcoming.length, 1);
  });

  test('revisões seguem 1, 7 e 30 dias e depois terminam', () async {
    final st = await withStudy();
    final r = st.data.reviews.single;
    await st.completeReview(r.id);
    expect(r.step, 1);
    expect(r.due, inDays(6));
    await st.completeReview(r.id);
    expect(r.step, 2);
    expect(r.due, inDays(23));
    await st.completeReview(r.id);
    expect(r.done, isTrue);
    expect(st.reviewsUpcoming, isEmpty);
  });

  test('estudar de novo o assunto com revisão vencida conta como revisão', () async {
    final st = await withStudy();
    final r = st.data.reviews.single;
    r.due = inDays(0);
    expect(st.reviewsDue.length, 1);
    await st.startSession(kind: SessionKind.estudo, title: 'Frações', subjectId: r.subjectId, topic: 'frações', focusMin: 15);
    await st.finishAndRecord(minutes: 15);
    expect(st.data.reviews.length, 1, reason: 'não cria outra para o mesmo assunto');
    expect(r.step, 1);
    expect(st.reviewsDue, isEmpty);
  });

  test('adiar, desligar e apagar a matéria', () async {
    final st = await withStudy();
    final r = st.data.reviews.single;
    r.due = inDays(-2);
    await st.postponeReview(r.id);
    expect(r.due, inDays(1));
    await st.setReviewOn(false);
    final s2 = await st.addSubject('História');
    await st.startSession(kind: SessionKind.estudo, title: 'Brasil', subjectId: s2.id, focusMin: 10);
    await st.finishAndRecord(minutes: 10);
    expect(st.data.reviews.length, 1);
    await st.removeSubject(r.subjectId);
    expect(st.data.reviews, isEmpty);
  });

  test('revisões sobrevivem a salvar e abrir de novo', () async {
    final d = AppData(reviewOn: false, reviews: [Review(id: 'r1', subjectId: 'mat', topic: 'Frações', created: '2026-06-01', step: 1, due: '2026-06-08')]);
    d.subjects.add(Subject(id: 'mat', name: 'Matemática'));
    final back = AppData.fromJson(d.toJson());
    expect(back.reviewOn, isFalse);
    expect(back.reviews.single.step, 1);
    expect(back.reviews.single.due, '2026-06-08');
  });

  test('revisão vencida entra no aviso da manhã e no rodízio', () {
    final now = DateTime(2026, 6, 10, 7, 0);
    final d = AppData(profile: Profile(nickname: 'Bia', notifyOn: true), onboarded: true);
    d.subjects.add(Subject(id: 'mat', name: 'Matemática'));
    d.reviews.add(Review(id: 'r1', subjectId: 'mat', topic: 'Frações', created: '2026-06-08', due: '2026-06-09'));
    final list = planReminderNotices(d, now);
    expect(list.any((n) => n.title == 'Revisão hoje' && n.body.contains('Frações') && n.when.day == 10), isTrue);
    expect(list.any((n) => n.title == 'Hora de revisar' && n.body.contains('Frações')), isTrue);
  });
}
