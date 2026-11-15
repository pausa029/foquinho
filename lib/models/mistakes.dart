// Caderno de erros: questões que o aluno errou (no quiz ou anotadas à mão).
// Cada uma volta para ser refeita: 1, 3 e 7 dias depois. Acertou 3 vezes seguidas = aprendeu.

import 'models.dart';

const List<int> kMistakeGaps = [1, 3, 7];

class Mistake {
  String id;
  String subjectId;
  String? topic;
  String question;
  List<String> options; // vazio = questão aberta (anotada à mão)
  int answer; // índice da certa (só com alternativas)
  String answerText; // resposta certa por escrito (questão aberta) ou explicação
  String created; // AAAA-MM-DD
  String due; // quando refazer
  int streak; // acertos seguidos ao refazer
  bool learned;

  Mistake({
    required this.id,
    required this.subjectId,
    this.topic,
    required this.question,
    List<String>? options,
    this.answer = 0,
    this.answerText = '',
    required this.created,
    required this.due,
    this.streak = 0,
    this.learned = false,
  }) : options = options ?? <String>[];

  bool get hasOptions => options.length >= 2;

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'topic': topic,
        'question': question,
        'options': options,
        'answer': answer,
        'answerText': answerText,
        'created': created,
        'due': due,
        'streak': streak,
        'learned': learned,
      };

  static Mistake? fromJson(Map<String, dynamic> m) {
    final id = readStr(m, 'id');
    final sid = readStr(m, 'subjectId');
    final q = readStr(m, 'question');
    final due = readStr(m, 'due');
    if (id.isEmpty || sid.isEmpty || q.isEmpty || parseDayKey(due) == null) return null;
    final opts = m['options'] is List ? (m['options'] as List).map((e) => '$e').toList() : <String>[];
    final topic = readStr(m, 'topic');
    final created = readStr(m, 'created');
    return Mistake(
      id: id,
      subjectId: sid,
      topic: topic.isEmpty ? null : topic,
      question: q,
      options: opts,
      answer: readInt(m, 'answer', 0, min: 0, max: opts.isEmpty ? 0 : opts.length - 1),
      answerText: readStr(m, 'answerText'),
      created: parseDayKey(created) == null ? due : created,
      due: due,
      streak: readInt(m, 'streak', 0, min: 0, max: 10),
      learned: readBool(m, 'learned', false),
    );
  }
}
