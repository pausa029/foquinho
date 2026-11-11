// Plano de estudo: matérias, assuntos, dificuldades, provas/trabalhos e tarefas.

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../logic/stats.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import 'agenda_tab.dart';
import 'onboarding_screen.dart' show kSubjectOptions;
import 'session_screen.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plano de estudo'),
        bottom: TabBar(
          controller: tabs,
          tabs: const [Tab(text: 'Mural'), Tab(text: 'Tarefas'), Tab(text: 'Matérias'), Tab(text: 'Provas')],
        ),
      ),
      body: TabBarView(
        controller: tabs,
        children: [AgendaTab(onGoSubjects: () => tabs.animateTo(2)), const _TasksTab(), const _SubjectsTab(), const _ExamsTab()],
      ),
    );
  }
}

// ---------- tarefas (kanban) ----------

class _TasksTab extends StatelessWidget {
  const _TasksTab();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final d = state.data;
    final cols = [
      (TaskStatus.todo, 'A estudar', Icons.radio_button_unchecked),
      (TaskStatus.doing, 'Em andamento', Icons.timelapse),
      (TaskStatus.done, 'Concluído', Icons.check_circle_outline),
    ];
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editTask(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Nova tarefa'),
      ),
      body: d.subjects.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                EmptyState(icon: Icons.menu_book_outlined, title: 'Cadastre uma matéria primeiro', text: 'As tarefas pertencem a uma matéria. Use a aba Matérias.'),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final c in cols) ...[
                  SectionTitle('${c.$2} (${d.tasks.where((t) => t.status == c.$1).length})'),
                  if (d.tasks.where((t) => t.status == c.$1).isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        c.$1 == TaskStatus.todo ? 'Nenhuma tarefa aqui. Toque em "Nova tarefa".' : 'Nada por aqui.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  for (final t in d.tasks.where((t) => t.status == c.$1)) _TaskCard(task: t, icon: c.$3),
                ],
              ],
            ),
    );
  }

  static Future<void> _editTask(BuildContext context, StudyTask? task) async {
    final state = AppScope.of(context);
    final d = state.data;
    if (d.subjects.isEmpty) return;
    String subjectId = task?.subjectId ?? d.subjects.first.id;
    final topic = TextEditingController(text: task?.topic ?? '');
    int minutes = task?.minutes ?? 25;
    String? deadline = task?.deadline;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(task == null ? 'Nova tarefa' : 'Editar tarefa', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: subjectId,
                decoration: const InputDecoration(labelText: 'Matéria'),
                items: [for (final s in d.subjects) DropdownMenuItem(value: s.id, child: Text(s.name))],
                onChanged: (v) => setSt(() => subjectId = v ?? subjectId),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: topic,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Assunto ou o que fazer', hintText: 'Ex.: exercícios 1 a 10 de frações'),
              ),
              Row(
                children: [
                  const Expanded(child: Text('Duração')),
                  IconButton(onPressed: () => setSt(() => minutes = (minutes - 5).clamp(5, 480).toInt()), icon: const Icon(Icons.remove_circle_outline), tooltip: 'Diminuir duração'),
                  SizedBox(width: 64, child: Text(fmtMin(minutes), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
                  IconButton(onPressed: () => setSt(() => minutes = (minutes + 5).clamp(5, 480).toInt()), icon: const Icon(Icons.add_circle_outline), tooltip: 'Aumentar duração'),
                ],
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Prazo (opcional)'),
                subtitle: Text(deadline == null ? 'Sem prazo' : fmtDate(parseDayKey(deadline)!)),
                trailing: Wrap(
                  children: [
                    if (deadline != null) IconButton(onPressed: () => setSt(() => deadline = null), icon: const Icon(Icons.clear), tooltip: 'Remover prazo'),
                    IconButton(
                      onPressed: () async {
                        final v = await pickDay(ctx, deadline);
                        if (v != null) setSt(() => deadline = v);
                      },
                      icon: const Icon(Icons.event),
                      tooltip: 'Escolher prazo',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  if (topic.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Escreva o assunto da tarefa.')));
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true) return;
    await state.upsertTask(StudyTask(
      id: task?.id ?? newId(),
      subjectId: subjectId,
      topic: topic.text.trim(),
      minutes: minutes,
      deadline: deadline,
      status: task?.status ?? TaskStatus.todo,
      createdAt: task?.createdAt,
    ));
  }
}

class _TaskCard extends StatelessWidget {
  final StudyTask task;
  final IconData icon;
  const _TaskCard({required this.task, required this.icon});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final d = state.data;
    final cs = Theme.of(context).colorScheme;
    final dl = parseDayKey(task.deadline);
    final days = dl == null ? null : dl.difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 12)).inDays;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${d.subjectName(task.subjectId)} · ${task.topic}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '${fmtMin(task.minutes)}${days == null ? '' : ' · prazo ${relativeDays(days)}'}',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Mais opções',
                  onSelected: (v) async {
                    if (v == 'edit') {
                      await _TasksTab._editTask(context, task);
                    } else if (v == 'del') {
                      await state.removeTask(task.id);
                    } else {
                      await state.setTaskStatus(task.id, TaskStatus.values.firstWhere((s) => s.name == v));
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    if (task.status != TaskStatus.todo) const PopupMenuItem(value: 'todo', child: Text('Mover para "A estudar"')),
                    if (task.status != TaskStatus.doing) const PopupMenuItem(value: 'doing', child: Text('Mover para "Em andamento"')),
                    if (task.status != TaskStatus.done) const PopupMenuItem(value: 'done', child: Text('Marcar como concluída')),
                    const PopupMenuItem(value: 'del', child: Text('Excluir')),
                  ],
                ),
              ],
            ),
            if (task.status != TaskStatus.done)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SessionScreen(
                      kind: SessionKind.estudo,
                      presetTitle: '${d.subjectName(task.subjectId)}: ${task.topic}',
                      presetMinutes: task.minutes.clamp(1, 180).toInt(),
                      presetSubjectId: task.subjectId,
                      presetTopic: task.topic,
                      presetTaskId: task.id,
                    ),
                  )),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Estudar agora'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------- matérias ----------

class _SubjectsTab extends StatelessWidget {
  const _SubjectsTab();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final d = state.data;
    final cs = Theme.of(context).colorScheme;
    final missing = kSubjectOptions.where((n) => !d.subjects.any((s) => s.name.toLowerCase() == n.toLowerCase())).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (d.subjects.isEmpty)
          const EmptyState(icon: Icons.menu_book_outlined, title: 'Nenhuma matéria cadastrada', text: 'Escolha abaixo ou adicione outra.'),
        for (final s in d.subjects)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(s.name, style: Theme.of(context).textTheme.titleMedium)),
                      IconButton(
                        tooltip: 'Excluir matéria',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await confirmDialog(context, title: 'Excluir ${s.name}?', text: 'As provas e tarefas dessa matéria também serão removidas. As sessões já registradas continuam no histórico.', yes: 'Excluir', danger: true);
                          if (ok) await state.removeSubject(s.id);
                        },
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Considero difícil'),
                    subtitle: const Text('Aparece primeiro nas sugestões.'),
                    value: s.hard,
                    onChanged: (v) {
                      s.hard = v;
                      state.updateSubject(s);
                    },
                  ),
                  Text('Assuntos para provas e trabalhos', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in s.topics)
                        InputChip(
                          label: Text(t),
                          onDeleted: () {
                            s.topics.remove(t);
                            state.updateSubject(s);
                          },
                          deleteButtonTooltipMessage: 'Remover assunto',
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add),
                        label: const Text('Assunto'),
                        onPressed: () async {
                          final v = await promptText(context, title: 'Assunto de ${s.name}', hint: 'Ex.: equações do 2º grau', maxLength: 60);
                          if (v == null) return;
                          if (!s.topics.contains(v)) s.topics.add(v);
                          await state.updateSubject(s);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SectionTitle('Adicionar matéria'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final n in missing) ActionChip(label: Text(n), onPressed: () => state.addSubject(n)),
            ActionChip(
              avatar: const Icon(Icons.add),
              label: const Text('Outra'),
              onPressed: () async {
                final v = await promptText(context, title: 'Nome da matéria', maxLength: 40);
                if (v != null) await state.addSubject(v);
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ---------- provas e trabalhos ----------

class _ExamsTab extends StatelessWidget {
  const _ExamsTab();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final d = state.data;
    final now = DateTime.now();
    final upcoming = state.upcomingExams(now);
    final past = d.exams.where((e) => (e.daysUntil(now) ?? 0) < 0).toList();
    return Scaffold(
      floatingActionButton: d.subjects.isEmpty
          ? null
          : FloatingActionButton.extended(onPressed: () => _editExam(context, null), icon: const Icon(Icons.add), label: const Text('Prova ou trabalho')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (d.subjects.isEmpty)
            const EmptyState(icon: Icons.event_outlined, title: 'Cadastre uma matéria primeiro', text: 'Provas e trabalhos pertencem a uma matéria.')
          else if (upcoming.isEmpty)
            const EmptyState(icon: Icons.event_available_outlined, title: 'Nenhuma prova ou trabalho pela frente', text: 'Cadastre para receber sugestões de revisão no painel.'),
          for (final e in upcoming) _examTile(context, state, e, now),
          if (past.isNotEmpty) ...[
            const SectionTitle('Já passaram'),
            for (final e in past) _examTile(context, state, e, now),
            TextButton(
              onPressed: () async {
                for (final e in past) {
                  await state.removeExam(e.id);
                }
              },
              child: const Text('Limpar as que já passaram'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _examTile(BuildContext context, AppState state, Exam e, DateTime now) {
    final days = e.daysUntil(now);
    final kind = e.kind == ExamKind.trabalho ? 'Trabalho' : 'Prova';
    return Card(
      child: ListTile(
        leading: Icon(e.kind == ExamKind.trabalho ? Icons.assignment_outlined : Icons.event_note_outlined),
        title: Text('${state.data.subjectName(e.subjectId)}${e.title.isEmpty ? '' : ' · ${e.title}'}'),
        subtitle: Text(days == null ? '$kind · sem data' : '$kind · ${fmtDate(parseDayKey(e.date)!)} · ${relativeDays(days)}'),
        trailing: PopupMenuButton<String>(
          tooltip: 'Mais opções',
          onSelected: (v) async {
            if (v == 'edit') {
              await _editExam(context, e);
            } else {
              await state.removeExam(e.id);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(value: 'del', child: Text('Excluir')),
          ],
        ),
      ),
    );
  }

  static Future<void> _editExam(BuildContext context, Exam? exam) async {
    final state = AppScope.of(context);
    final d = state.data;
    if (d.subjects.isEmpty) return;
    String subjectId = exam?.subjectId ?? d.subjects.first.id;
    ExamKind kind = exam?.kind ?? ExamKind.prova;
    final title = TextEditingController(text: exam?.title ?? '');
    String? date = exam?.date;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(exam == null ? 'Nova prova ou trabalho' : 'Editar', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              SegmentedButton<ExamKind>(
                segments: const [
                  ButtonSegment(value: ExamKind.prova, label: Text('Prova')),
                  ButtonSegment(value: ExamKind.trabalho, label: Text('Trabalho')),
                ],
                selected: {kind},
                onSelectionChanged: (s) => setSt(() => kind = s.first),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: subjectId,
                decoration: const InputDecoration(labelText: 'Matéria'),
                items: [for (final s in d.subjects) DropdownMenuItem(value: s.id, child: Text(s.name))],
                onChanged: (v) => setSt(() => subjectId = v ?? subjectId),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Assunto (opcional)', hintText: 'Ex.: Revolução Francesa'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data (opcional)'),
                subtitle: Text(date == null ? 'Sem data' : fmtDate(parseDayKey(date)!)),
                trailing: Wrap(
                  children: [
                    if (date != null) IconButton(onPressed: () => setSt(() => date = null), icon: const Icon(Icons.clear), tooltip: 'Remover data'),
                    IconButton(
                      onPressed: () async {
                        final v = await pickDay(ctx, date);
                        if (v != null) setSt(() => date = v);
                      },
                      icon: const Icon(Icons.event),
                      tooltip: 'Escolher data',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
            ],
          ),
        ),
      ),
    );
    if (saved != true) return;
    final t = title.text.trim();
    await state.upsertExam(Exam(id: exam?.id ?? newId(), subjectId: subjectId, title: t, kind: kind, date: date));
    // Assunto da prova também vira assunto da matéria, para as sugestões.
    final subj = d.subjectById(subjectId);
    if (subj != null && t.isNotEmpty && !subj.topics.contains(t)) {
      subj.topics.add(t);
      await state.updateSubject(subj);
    }
  }
}
