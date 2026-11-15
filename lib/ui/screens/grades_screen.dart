// Notas: lança as notas de cada unidade e mostra quanto falta para passar.

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

class GradesScreen extends StatelessWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final d = state.data;
    final c = d.grading;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas'),
        actions: [
          IconButton(
            tooltip: 'Como é a nota da escola',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GradeConfigScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          InfoNote(
            '${c.units} ${c.units == 1 ? c.unitName.toLowerCase() : '${c.unitName.toLowerCase()}s'} no ano. '
            'Cada uma: ${c.parts.map((p) => '${p.name} ${fmtPts(p.max)}').join(' + ')}. '
            'Para passar: ${fmtPts(c.passPct)}% dos pontos. Toque em ⚙ para mudar.',
          ),
          if (d.subjects.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: EmptyState(icon: Icons.school_outlined, title: 'Cadastre suas matérias', text: 'Em Plano → Matérias.'),
            ),
          for (final s in d.subjects) ...[
            const SizedBox(height: 8),
            _SubjectGradeCard(subject: s),
          ],
          const SizedBox(height: 12),
          Text('As notas ficam só no seu aparelho (e na sua conta, se estiver conectada).', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SubjectGradeCard extends StatelessWidget {
  final Subject subject;
  const _SubjectGradeCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final d = state.data;
    final st = gradeStatus(d.grading, d.grades, subject.id);
    final cs = Theme.of(context).colorScheme;
    final total = d.grading.yearMax(subject.id);
    String line;
    Color color;
    if (st.launchedMax == 0) {
      line = 'Nenhuma nota lançada. Para passar: ${fmtPts(st.pass)} de ${fmtPts(total)}.';
      color = cs.onSurfaceVariant;
    } else if (st.passed) {
      line = 'Já passou! ${fmtPts(st.earned)} de ${fmtPts(st.pass)} necessários.';
      color = Colors.green.shade700;
    } else if (st.impossible) {
      line = 'Faltam ${fmtPts(st.missing)} e só restam ${fmtPts(st.remainingMax)} pontos. Converse com o professor sobre recuperação.';
      color = cs.error;
    } else {
      final pct = st.neededPct!;
      line = 'Faltam ${fmtPts(st.missing)} pontos. Precisa de ${pct.round()}% no que falta (${fmtPts(st.remainingMax)} em jogo).';
      color = pct > 80 ? cs.error : (pct > 60 ? Colors.orange.shade800 : cs.primary);
    }
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SubjectGradesScreen(subjectId: subject.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                  Text('${fmtPts(st.earned)} / ${fmtPts(total)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    LinearProgressIndicator(value: total == 0 ? 0 : (st.earned / total).clamp(0, 1), minHeight: 10, backgroundColor: cs.surfaceContainerHighest),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment(total == 0 ? -1 : (st.pass / total) * 2 - 1, 0),
                        child: Container(width: 2, color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(line, style: TextStyle(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class SubjectGradesScreen extends StatefulWidget {
  final String subjectId;
  const SubjectGradesScreen({super.key, required this.subjectId});

  @override
  State<SubjectGradesScreen> createState() => _SubjectGradesScreenState();
}

class _SubjectGradesScreenState extends State<SubjectGradesScreen> {
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final d = state.data;
    final c = d.grading;
    final parts = c.partsFor(widget.subjectId);
    final cs = Theme.of(context).colorScheme;
    final custom = c.bySubject.containsKey(widget.subjectId);
    return DefaultTabController(
      length: c.units,
      child: Scaffold(
        appBar: AppBar(
          title: Text(d.subjectName(widget.subjectId)),
          bottom: TabBar(isScrollable: c.units > 3, tabs: [for (var u = 1; u <= c.units; u++) Tab(text: '${u}ª ${c.unitName}')]),
        ),
        body: TabBarView(
          children: [
            for (var u = 1; u <= c.units; u++)
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  for (final p in parts) _gradeField(context, state, u, p),
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final sum = parts.fold<double>(0, (a, p) {
                      final g = d.grades.where((g) => g.subjectId == widget.subjectId && g.unit == u && g.part == p.name);
                      return a + (g.isEmpty ? 0 : g.first.value);
                    });
                    return Text('Total da ${c.unitName.toLowerCase()}: ${fmtPts(sum)} de ${fmtPts(c.unitMax(widget.subjectId))}',
                        style: const TextStyle(fontWeight: FontWeight.w600));
                  }),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _editParts(context, state),
                    icon: const Icon(Icons.edit_note),
                    label: Text(custom ? 'Partes desta matéria (personalizadas)' : 'Esta matéria tem partes diferentes?'),
                  ),
                  if (custom)
                    TextButton(
                      onPressed: () async {
                        c.bySubject.remove(widget.subjectId);
                        await state.setGrading(c);
                      },
                      child: const Text('Voltar ao padrão da escola'),
                    ),
                  const SizedBox(height: 8),
                  Text('Deixe vazio o que ainda não saiu. O app calcula quanto falta com base no que já foi lançado.',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _gradeField(BuildContext context, AppState state, int unit, GradePart p) {
    final d = state.data;
    final g = d.grades.where((g) => g.subjectId == widget.subjectId && g.unit == unit && g.part == p.name);
    final value = g.isEmpty ? null : g.first.value;
    return Card(
      child: ListTile(
        title: Text(p.name),
        subtitle: Text('vale ${fmtPts(p.max)}'),
        trailing: Text(value == null ? '—' : fmtPts(value), style: Theme.of(context).textTheme.titleLarge),
        onTap: () async {
          final v = await promptText(context,
              title: '${p.name} (0 a ${fmtPts(p.max)})', initial: value == null ? '' : fmtPts(value), maxLength: 5);
          if (v == null) return;
          final t = v.trim().replaceAll(',', '.');
          if (t.isEmpty) {
            await state.setGrade(widget.subjectId, unit, p.name, null);
            return;
          }
          final n = double.tryParse(t);
          if (n == null || n < 0 || n > p.max) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Digite um número de 0 a ${fmtPts(p.max)}.')));
            }
            return;
          }
          await state.setGrade(widget.subjectId, unit, p.name, n);
        },
      ),
    );
  }

  Future<void> _editParts(BuildContext context, AppState state) async {
    final c = state.data.grading;
    final parts = await Navigator.of(context).push<List<GradePart>>(MaterialPageRoute(
      builder: (_) => PartsEditor(
        title: 'Partes de ${state.data.subjectName(widget.subjectId)}',
        initial: c.partsFor(widget.subjectId),
      ),
    ));
    if (parts == null) return;
    c.bySubject[widget.subjectId] = parts;
    await state.setGrading(c);
  }
}

/// Configuração geral: unidades, partes e média para passar.
class GradeConfigScreen extends StatefulWidget {
  const GradeConfigScreen({super.key});

  @override
  State<GradeConfigScreen> createState() => _GradeConfigScreenState();
}

class _GradeConfigScreenState extends State<GradeConfigScreen> {
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = state.data.grading;
    return Scaffold(
      appBar: AppBar(title: const Text('Como é a nota da escola')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Divisão do ano', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Unidade', label: Text('Unidades')),
              ButtonSegment(value: 'Bimestre', label: Text('Bimestres')),
              ButtonSegment(value: 'Trimestre', label: Text('Trimestres')),
            ],
            selected: {c.unitName},
            onSelectionChanged: (s) async {
              c.unitName = s.first;
              if (s.first == 'Bimestre') c.units = 4;
              if (s.first == 'Trimestre') c.units = 3;
              await state.setGrading(c);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Text('Quantas no ano')),
              IconButton(onPressed: c.units > 1 ? () => state.setGrading(c..units = c.units - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
              Text('${c.units}', style: Theme.of(context).textTheme.titleLarge),
              IconButton(onPressed: c.units < 6 ? () => state.setGrading(c..units = c.units + 1) : null, icon: const Icon(Icons.add_circle_outline)),
            ],
          ),
          const Divider(height: 32),
          Text('Partes de cada ${c.unitName.toLowerCase()} (padrão)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final p in c.parts) Text('• ${p.name}: ${fmtPts(p.max)} pontos'),
          Text('Total por ${c.unitName.toLowerCase()}: ${fmtPts(c.parts.fold<double>(0, (a, p) => a + p.max))}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final parts = await Navigator.of(context).push<List<GradePart>>(MaterialPageRoute(
                builder: (_) => PartsEditor(title: 'Partes de cada ${c.unitName.toLowerCase()}', initial: c.parts),
              ));
              if (parts == null) return;
              c.parts = parts;
              await state.setGrading(c);
            },
            icon: const Icon(Icons.edit_note),
            label: const Text('Mudar as partes'),
          ),
          const Divider(height: 32),
          Text('Para passar: ${fmtPts(c.passPct)}% dos pontos do ano', style: Theme.of(context).textTheme.titleSmall),
          Slider(
            value: c.passPct,
            min: 30,
            max: 100,
            divisions: 70,
            label: '${c.passPct.round()}%',
            onChanged: (v) => setState(() => c.passPct = v.roundToDouble()),
            onChangeEnd: (v) => state.setGrading(c..passPct = v.roundToDouble()),
          ),
          const InfoNote('Exemplo: média 6 numa escala de 0 a 10 = 60%. Se uma matéria tem partes diferentes, ajuste dentro da própria matéria.'),
        ],
      ),
    );
  }
}

/// Editor de partes (nome + quanto vale).
class PartsEditor extends StatefulWidget {
  final String title;
  final List<GradePart> initial;
  const PartsEditor({super.key, required this.title, required this.initial});

  @override
  State<PartsEditor> createState() => _PartsEditorState();
}

class _PartsEditorState extends State<PartsEditor> {
  late final List<(TextEditingController, TextEditingController)> rows = [
    for (final p in widget.initial) (TextEditingController(text: p.name), TextEditingController(text: fmtPts(p.max))),
  ];

  @override
  void dispose() {
    for (final r in rows) {
      r.$1.dispose();
      r.$2.dispose();
    }
    super.dispose();
  }

  List<GradePart>? _parse() {
    final out = <GradePart>[];
    final names = <String>{};
    for (final r in rows) {
      final name = r.$1.text.trim();
      final max = double.tryParse(r.$2.text.trim().replaceAll(',', '.'));
      if (name.isEmpty && r.$2.text.trim().isEmpty) continue;
      if (name.isEmpty || max == null || max <= 0 || max > 1000 || !names.add(name.toLowerCase())) return null;
      out.add(GradePart(name, max));
    }
    return out.isEmpty ? null : out;
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parse();
    final total = parsed?.fold<double>(0, (a, p) => a + p.max);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: rows[i].$1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Parte'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: rows[i].$2,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Vale'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remover',
                    onPressed: rows.length > 1 ? () => setState(() => rows.removeAt(i)) : null,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () => setState(() => rows.add((TextEditingController(), TextEditingController()))),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar parte'),
          ),
          const SizedBox(height: 8),
          Text(parsed == null ? 'Confira: cada parte precisa de nome (sem repetir) e de um valor.' : 'Total: ${fmtPts(total!)} pontos'),
          const SizedBox(height: 16),
          FilledButton(onPressed: parsed == null ? null : () => Navigator.pop(context, parsed), child: const Text('Salvar')),
        ],
      ),
    );
  }
}
