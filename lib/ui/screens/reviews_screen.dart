// Revisão espaçada: cartão do mural (Início) e tela com todas as revisões.

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../logic/stats.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import 'session_screen.dart';

String reviewName(AppData d, Review r) => '${d.subjectName(r.subjectId)}${r.topic == null ? '' : ' · ${r.topic}'}';

String reviewWhen(Review r) {
  final due = parseDayKey(r.due);
  if (due == null) return '';
  final t = DateTime.now();
  final days = DateTime(due.year, due.month, due.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (days < 0) return 'atrasada ${-days == 1 ? '1 dia' : '${-days} dias'}';
  if (days == 0) return 'hoje';
  if (days == 1) return 'amanhã';
  return 'em ${fmtDate(due)}';
}

void startReview(BuildContext context, Review r) {
  final d = AppScope.of(context).data;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SessionScreen(
      kind: SessionKind.estudo,
      presetTitle: 'Revisão: ${reviewName(d, r)}',
      presetMinutes: 15,
      presetSubjectId: r.subjectId,
      presetTopic: r.topic,
    ),
  ));
}

/// Cartão do Início: revisões de hoje (ou a próxima, se não houver nenhuma hoje).
class ReviewsCard extends StatelessWidget {
  const ReviewsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final due = state.reviewsDue;
    final next = state.reviewsUpcoming;
    final cs = Theme.of(context).colorScheme;
    if (due.isEmpty && next.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          due.isEmpty ? 'Revisões' : 'Revisões de hoje (${due.length})',
          trailing: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReviewsScreen())),
            child: const Text('Ver todas'),
          ),
        ),
        if (due.isEmpty)
          Card(
            child: ListTile(
              leading: Icon(Icons.event_repeat, color: cs.primary),
              title: Text('Nenhuma revisão hoje'),
              subtitle: Text('Próxima: ${reviewName(state.data, next.first)} · ${reviewWhen(next.first)}'),
            ),
          )
        else
          for (final r in due.take(3)) ReviewTile(r: r),
        if (due.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('e mais ${due.length - 3} em "Ver todas".', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
      ],
    );
  }
}

class ReviewTile extends StatelessWidget {
  final Review r;
  const ReviewTile({super.key, required this.r});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final isDue = r.due.compareTo(dayKey(DateTime.now())) <= 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reviewName(state.data, r), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${r.label} · ${reviewWhen(r)}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (isDue) FilledButton.tonal(onPressed: () => startReview(context, r), child: const Text('Revisar (15 min)')),
                OutlinedButton(
                  onPressed: () async {
                    await state.completeReview(r.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revisão marcada como feita.')));
                    }
                  },
                  child: const Text('Já revisei'),
                ),
                if (isDue) TextButton(onPressed: () => state.postponeReview(r.id), child: const Text('Amanhã')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final d = state.data;
    final due = state.reviewsDue;
    final next = state.reviewsUpcoming;
    final done = d.reviews.where((r) => r.done).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Revisões')),
      floatingActionButton: d.subjects.isEmpty
          ? null
          : FloatingActionButton.extended(onPressed: () => _add(context), icon: const Icon(Icons.add), label: const Text('Nova revisão')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          const InfoNote('Depois de estudar um assunto no temporizador, o Foquinho agenda revisões curtas para 1, 7 e 30 dias depois. Revisar no tempo certo é o que faz o conteúdo não ser esquecido.'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Criar revisões automaticamente'),
            subtitle: const Text('Depois de cada estudo com matéria.'),
            value: d.reviewOn,
            onChanged: state.setReviewOn,
          ),
          SectionTitle('Para hoje (${due.length})'),
          if (due.isEmpty) const EmptyState(icon: Icons.check_circle_outline, title: 'Nada para revisar hoje'),
          for (final r in due) _dismissible(context, r),
          SectionTitle('Próximas (${next.length})'),
          if (next.isEmpty) const EmptyState(icon: Icons.event_repeat, title: 'Nenhuma revisão agendada', text: 'Estude um assunto no temporizador e a revisão aparece aqui.'),
          for (final r in next) _dismissible(context, r),
          if (done > 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text('$done ${done == 1 ? 'assunto revisado' : 'assuntos revisados'} até o fim (3 revisões).', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  Widget _dismissible(BuildContext context, Review r) {
    final state = AppScope.of(context);
    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => state.removeReview(r.id),
      child: ReviewTile(r: r),
    );
  }

  Future<void> _add(BuildContext context) async {
    final state = AppScope.of(context);
    final subjects = state.data.subjects;
    String subjectId = subjects.first.id;
    final topic = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Nova revisão'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: subjectId,
                decoration: const InputDecoration(labelText: 'Matéria'),
                items: [for (final s in subjects) DropdownMenuItem(value: s.id, child: Text(s.name))],
                onChanged: (v) => set(() => subjectId = v ?? subjectId),
              ),
              const SizedBox(height: 8),
              TextField(controller: topic, decoration: const InputDecoration(labelText: 'Assunto (opcional)'), textCapitalization: TextCapitalization.sentences),
              const SizedBox(height: 8),
              const Text('A 1ª revisão fica para amanhã.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Agendar')),
          ],
        ),
      ),
    );
    if (ok == true) await state.addReview(subjectId, topic.text);
  }
}
