// Quiz com IA: escolhe matéria e assunto, a IA monta as questões, o aluno responde.

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../services/cloud.dart';
import '../widgets/common.dart';
import 'account_screen.dart';

class QuizScreen extends StatefulWidget {
  final String? subjectId;
  final String? topic;
  const QuizScreen({super.key, this.subjectId, this.topic});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  String? subjectId;
  late final TextEditingController topic = TextEditingController(text: widget.topic ?? '');
  final notes = TextEditingController();
  int count = 5;
  bool loading = false;
  String? error;

  List<QuizQuestion>? questions;
  int index = 0;
  int? picked;
  final answers = <int>[];

  @override
  void initState() {
    super.initState();
    subjectId = widget.subjectId;
  }

  @override
  void dispose() {
    topic.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final state = AppScope.of(context);
    final sid = subjectId ?? (state.data.subjects.isEmpty ? null : state.data.subjects.first.id);
    if (sid == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final qs = await state.makeQuiz(subjectId: sid, topic: topic.text, text: notes.text, count: count);
      if (!mounted) return;
      setState(() {
        subjectId = sid;
        questions = qs;
        index = 0;
        picked = null;
        answers.clear();
      });
    } on CloudError catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Não foi possível gerar o quiz. Tente de novo.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qs = questions;
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz com IA')),
      body: qs == null ? _form(context) : (index < qs.length ? _question(context, qs) : _result(context, qs)),
    );
  }

  Widget _form(BuildContext context) {
    final state = AppScope.of(context);
    final d = state.data;
    final cs = Theme.of(context).colorScheme;
    if (!state.signedIn) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const EmptyState(icon: Icons.lock_outline, title: 'Entre na sua conta', text: 'O quiz com IA funciona com a conta conectada.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen())),
            child: const Text('Entrar'),
          ),
        ],
      );
    }
    if (d.subjects.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: EmptyState(icon: Icons.school_outlined, title: 'Cadastre uma matéria primeiro', text: 'Em Plano → Matérias.'),
      );
    }
    final sid = subjectId ?? d.subjects.first.id;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const InfoNote('A IA cria questões de múltipla escolha sobre o assunto. Confira com o seu material: a IA pode errar.', icon: Icons.auto_awesome),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: d.subjects.any((s) => s.id == sid) ? sid : d.subjects.first.id,
          decoration: const InputDecoration(labelText: 'Matéria'),
          items: [for (final s in d.subjects) DropdownMenuItem(value: s.id, child: Text(s.name))],
          onChanged: loading ? null : (v) => setState(() => subjectId = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: topic,
          enabled: !loading,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Assunto', hintText: 'Ex.: frações, Revolução Francesa, citologia'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: notes,
          enabled: !loading,
          minLines: 3,
          maxLines: 8,
          maxLength: 8000,
          decoration: const InputDecoration(labelText: 'Resumo ou trecho do caderno (opcional)', hintText: 'Cole aqui para as questões seguirem o seu material'),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Text('Questões:'),
            const SizedBox(width: 12),
            SegmentedButton<int>(
              segments: const [ButtonSegment(value: 5, label: Text('5')), ButtonSegment(value: 10, label: Text('10'))],
              selected: {count},
              onSelectionChanged: loading ? null : (s) => setState(() => count = s.first),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(error!, style: TextStyle(color: cs.error)),
          ),
        FilledButton.icon(
          onPressed: loading ? null : _generate,
          icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
          label: Text(loading ? 'Criando as questões...' : 'Gerar quiz'),
        ),
      ],
    );
  }

  Widget _question(BuildContext context, List<QuizQuestion> qs) {
    final q = qs[index];
    final cs = Theme.of(context).colorScheme;
    final answered = picked != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        LinearProgressIndicator(value: (index + (answered ? 1 : 0)) / qs.length),
        const SizedBox(height: 12),
        Text('Questão ${index + 1} de ${qs.length}', style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        Text(q.q, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        for (var i = 0; i < q.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _option(context, q, i),
          ),
        if (answered) ...[
          const SizedBox(height: 8),
          Card(
            color: picked == q.answer ? cs.primaryContainer : cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(picked == q.answer ? 'Certo!' : 'Resposta certa: ${String.fromCharCode(65 + q.answer)}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: picked == q.answer ? cs.onPrimaryContainer : cs.onErrorContainer)),
                  if (q.explain.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(q.explain, style: TextStyle(color: picked == q.answer ? cs.onPrimaryContainer : cs.onErrorContainer)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => setState(() {
              answers.add(picked!);
              picked = null;
              index++;
            }),
            child: Text(index + 1 < qs.length ? 'Próxima' : 'Ver resultado'),
          ),
        ],
      ],
    );
  }

  Widget _option(BuildContext context, QuizQuestion q, int i) {
    final cs = Theme.of(context).colorScheme;
    final answered = picked != null;
    Color? bg;
    if (answered && i == q.answer) bg = cs.primaryContainer;
    if (answered && i == picked && i != q.answer) bg = cs.errorContainer;
    return Material(
      color: bg ?? cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: answered ? null : () => setState(() => picked = i),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${String.fromCharCode(65 + i)})', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Expanded(child: Text(q.options[i])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _result(BuildContext context, List<QuizQuestion> qs) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    var right = 0;
    for (var i = 0; i < qs.length; i++) {
      if (answers[i] == qs[i].answer) right++;
    }
    final wrong = [for (var i = 0; i < qs.length; i++) if (answers[i] != qs[i].answer) qs[i]];
    final pct = (right * 100 / qs.length).round();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text('$right de ${qs.length} certas', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(pct >= 80 ? 'Mandou bem! Você domina esse assunto.' : (pct >= 50 ? 'Bom caminho. Revise as que errou.' : 'Vale estudar de novo esse assunto.'),
            style: TextStyle(color: cs.onSurfaceVariant)),
        if (wrong.isNotEmpty) ...[
          const SectionTitle('Para revisar'),
          for (final q in wrong)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.q, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Certa: ${q.options[q.answer]}'),
                    if (q.explain.isNotEmpty) Text(q.explain, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        if (pct < 80 && subjectId != null)
          OutlinedButton.icon(
            onPressed: () async {
              await state.addReview(subjectId!, topic.text);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revisão agendada para amanhã.')));
            },
            icon: const Icon(Icons.event_repeat),
            label: const Text('Agendar revisão deste assunto'),
          ),
        const SizedBox(height: 8),
        FilledButton(onPressed: () => setState(() => questions = null), child: const Text('Fazer outro quiz')),
      ],
    );
  }
}
