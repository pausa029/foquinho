// Caderno de erros: lista, refazer e anotar questões erradas.

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

String _when(String due) {
  final d = parseDayKey(due);
  if (d == null) return '';
  final t = DateTime.now();
  final days = DateTime(d.year, d.month, d.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (days <= 0) return 'refazer hoje';
  if (days == 1) return 'refazer amanhã';
  return 'refazer em ${fmtDate(d)}';
}

class MistakesScreen extends StatelessWidget {
  const MistakesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final d = state.data;
    final cs = Theme.of(context).colorScheme;
    final due = state.mistakesDue;
    final open = d.mistakes.where((e) => !e.learned).toList()..sort((a, b) => a.due.compareTo(b.due));
    final learned = d.mistakes.where((e) => e.learned).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Caderno de erros')),
      floatingActionButton: d.subjects.isEmpty
          ? null
          : FloatingActionButton.extended(onPressed: () => _add(context), icon: const Icon(Icons.add), label: const Text('Anotar erro')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          const InfoNote('Questões que você errou voltam para ser refeitas 1, 3 e 7 dias depois. Acertou 3 vezes seguidas? Aprendeu e sai da lista.'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Guardar os erros do quiz automaticamente'),
            value: d.saveQuizMistakes,
            onChanged: state.setSaveQuizMistakes,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: due.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MistakePracticeScreen(ids: [for (final e in due) e.id]))),
            icon: const Icon(Icons.replay),
            label: Text(due.isEmpty ? 'Nada para refazer hoje' : 'Refazer ${due.length} ${due.length == 1 ? 'questão' : 'questões'} de hoje'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          if (open.isNotEmpty && due.length < open.length)
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MistakePracticeScreen(ids: [for (final e in open) e.id]))),
              child: const Text('Treinar todas agora (antes da prova)'),
            ),
          SectionTitle('Para aprender (${open.length})'),
          if (open.isEmpty)
            const EmptyState(icon: Icons.menu_book_outlined, title: 'Caderno vazio', text: 'Os erros do quiz entram aqui. Você também pode anotar um erro de prova ou de exercício.'),
          for (final e in open)
            Dismissible(
              key: ValueKey(e.id),
              direction: DismissDirection.endToStart,
              background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete_outline)),
              onDismissed: (_) => state.removeMistake(e.id),
              child: Card(
                child: ListTile(
                  title: Text(e.question, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${d.subjectName(e.subjectId)}${e.topic == null ? '' : ' · ${e.topic}'} · ${_when(e.due)}${e.streak > 0 ? ' · ${e.streak}/3 acertos' : ''}'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MistakePracticeScreen(ids: [e.id]))),
                ),
              ),
            ),
          if (learned > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('$learned ${learned == 1 ? 'questão aprendida' : 'questões aprendidas'}. 🎉', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final state = AppScope.of(context);
    final subjects = state.data.subjects;
    String subjectId = subjects.first.id;
    final topic = TextEditingController();
    final q = TextEditingController();
    final a = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Anotar um erro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: subjectId,
                  decoration: const InputDecoration(labelText: 'Matéria'),
                  items: [for (final s in subjects) DropdownMenuItem(value: s.id, child: Text(s.name))],
                  onChanged: (v) => set(() => subjectId = v ?? subjectId),
                ),
                TextField(controller: topic, decoration: const InputDecoration(labelText: 'Assunto (opcional)'), textCapitalization: TextCapitalization.sentences),
                TextField(controller: q, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Questão que errou'), textCapitalization: TextCapitalization.sentences),
                TextField(controller: a, minLines: 1, maxLines: 4, decoration: const InputDecoration(labelText: 'Resposta certa'), textCapitalization: TextCapitalization.sentences),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok == true && q.text.trim().isNotEmpty && a.text.trim().isNotEmpty) {
      await state.addMistake(subjectId: subjectId, topic: topic.text, question: q.text, answerText: a.text);
    }
  }
}

/// Refazer questões do caderno, uma por vez.
class MistakePracticeScreen extends StatefulWidget {
  final List<String> ids;
  const MistakePracticeScreen({super.key, required this.ids});

  @override
  State<MistakePracticeScreen> createState() => _MistakePracticeScreenState();
}

class _MistakePracticeScreenState extends State<MistakePracticeScreen> {
  int index = 0;
  int? picked;
  bool revealed = false;
  int right = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final items = [for (final id in widget.ids) ...state.data.mistakes.where((e) => e.id == id)];
    if (index >= items.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Caderno de erros')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('$right de ${items.length} certas', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(right == items.length ? 'Mandou bem! As certas voltam mais tarde para fixar.' : 'As que errou voltam amanhã. Errar aqui é o melhor lugar para errar.',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Voltar')),
          ],
        ),
      );
    }
    final e = items[index];
    final answered = e.hasOptions ? picked != null : revealed;
    Future<void> next(bool ok) async {
      await state.answerMistake(e.id, ok);
      if (ok) right++;
      setState(() {
        index++;
        picked = null;
        revealed = false;
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text('Questão ${index + 1} de ${items.length}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${state.data.subjectName(e.subjectId)}${e.topic == null ? '' : ' · ${e.topic}'}', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(e.question, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (e.hasOptions)
            for (var i = 0; i < e.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: answered && i == e.answer
                      ? cs.primaryContainer
                      : (answered && i == picked ? cs.errorContainer : cs.surfaceContainerHighest),
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
                          Expanded(child: Text(e.options[i])),
                        ],
                      ),
                    ),
                  ),
                ),
              )
          else if (!revealed)
            OutlinedButton.icon(onPressed: () => setState(() => revealed = true), icon: const Icon(Icons.visibility), label: const Text('Pensei na resposta. Mostrar')),
          if (answered && e.answerText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(e.hasOptions ? e.answerText : 'Resposta: ${e.answerText}'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (answered && e.hasOptions)
            FilledButton(onPressed: () => next(picked == e.answer), child: Text(picked == e.answer ? 'Certo! Próxima' : 'Próxima')),
          if (answered && !e.hasOptions)
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => next(false), child: const Text('Errei'))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: () => next(true), child: const Text('Acertei'))),
              ],
            ),
        ],
      ),
    );
  }
}
