// Exercício e pausa ativa: sugestões por preferência, tempo disponível e local.

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../logic/suggestions.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import 'session_screen.dart';

class MoveScreen extends StatefulWidget {
  const MoveScreen({super.key});

  @override
  State<MoveScreen> createState() => _MoveScreenState();
}

class _MoveScreenState extends State<MoveScreen> {
  int? maxMinutes; // null = qualquer
  Place? place; // null = qualquer
  bool showAll = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final d = state.data;
    final cs = Theme.of(context).colorScheme;
    final sugs = moveSuggestions(d, maxMinutes: maxMinutes, place: place, limit: showAll ? 100 : 6);
    final prefs = d.profile?.sports ?? const <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimento'),
        actions: [
          IconButton(
            tooltip: 'Editar meus esportes',
            icon: const Icon(Icons.tune),
            onPressed: () => _editSports(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editActivity(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Nova atividade'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SessionScreen(kind: SessionKind.exercicio))),
            icon: const Icon(Icons.timer_outlined),
            label: const Text('Pausa ativa livre (temporizador)'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: cs.tertiary, foregroundColor: cs.onTertiary),
          ),
          const SizedBox(height: 8),
          if (prefs.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.sports_soccer_outlined),
                title: const Text('Quais esportes você curte?'),
                subtitle: const Text('Com isso as sugestões ficam na sua cara.'),
                trailing: TextButton(onPressed: () => _editSports(context), child: const Text('Escolher')),
              ),
            )
          else
            Text('Seus esportes: ${prefs.join(', ')}', style: TextStyle(color: cs.onSurfaceVariant)),
          const SectionTitle('Tempo disponível'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(label: const Text('Qualquer'), selected: maxMinutes == null, onSelected: (_) => setState(() => maxMinutes = null)),
              for (final m in const [5, 10, 15, 20, 30])
                ChoiceChip(label: Text('até $m min'), selected: maxMinutes == m, onSelected: (_) => setState(() => maxMinutes = m)),
            ],
          ),
          const SectionTitle('Local'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(label: const Text('Qualquer'), selected: place == null, onSelected: (_) => setState(() => place = null)),
              ChoiceChip(label: const Text('Em casa'), selected: place == Place.casa, onSelected: (_) => setState(() => place = Place.casa)),
              ChoiceChip(label: const Text('Ao ar livre'), selected: place == Place.arLivre, onSelected: (_) => setState(() => place = Place.arLivre)),
            ],
          ),
          const SectionTitle('Sugestões'),
          if (sugs.isEmpty)
            EmptyState(
              icon: Icons.search_off,
              title: 'Nenhuma atividade com esses filtros',
              text: d.activities.isEmpty ? 'A lista de atividades está vazia.' : 'Tente outro tempo ou local, ou crie uma atividade.',
              action: d.activities.isEmpty ? OutlinedButton(onPressed: () => state.restoreDefaultActivities(), child: const Text('Restaurar lista padrão')) : null,
            ),
          for (final s in sugs) _activityCard(context, state, s),
          if (!showAll && d.activities.length > 6)
            TextButton(onPressed: () => setState(() => showAll = true), child: const Text('Mostrar todas as atividades')),
          const SizedBox(height: 8),
          const InfoNote('Respeite seus limites e pare se sentir dor ou mal-estar. O TelaTchau não faz diagnóstico nem promete resultados de saúde.'),
        ],
      ),
    );
  }

  Widget _activityCard(BuildContext context, AppState state, Suggestion s) {
    final a = s.activity!;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.directions_run, color: cs.onTertiaryContainer),
        ),
        title: Text(a.name),
        subtitle: Text('${a.minutes} min · ${placeLabel(a.place)} · ${a.sport}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Editar atividade',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editActivity(context, a),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SessionScreen(kind: SessionKind.exercicio, presetTitle: a.name, presetMinutes: a.minutes),
              )),
              child: const Text('Iniciar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSports(BuildContext context) async {
    final state = AppScope.of(context);
    final p = state.data.profile ?? Profile(nickname: 'Estudante');
    final sel = List<String>.of(p.sports);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final all = [...kSportOptions, ...sel.where((s) => !kSportOptions.contains(s))];
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text('Meus esportes e atividades', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in all)
                      FilterChip(label: Text(s), selected: sel.contains(s), onSelected: (v) => setSt(() => v ? sel.add(s) : sel.remove(s))),
                    ActionChip(
                      avatar: const Icon(Icons.add),
                      label: const Text('Outro'),
                      onPressed: () async {
                        final v = await promptText(ctx, title: 'Esporte ou atividade', maxLength: 40);
                        if (v != null && !sel.contains(v)) setSt(() => sel.add(v));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
              ],
            ),
          );
        },
      ),
    );
    if (saved != true) return;
    p.sports = sel;
    await state.saveProfile(p);
  }

  Future<void> _editActivity(BuildContext context, Activity? act) async {
    final state = AppScope.of(context);
    final name = TextEditingController(text: act?.name ?? '');
    int minutes = act?.minutes ?? 10;
    Place place = act?.place ?? Place.qualquer;
    final sports = state.data.profile?.sports ?? const <String>[];
    final sportOptions = <String>{...kSportOptions, ...sports, if (act != null) act.sport, 'Outro'}.toList();
    String sport = act?.sport ?? (sports.isNotEmpty ? sports.first : 'Outro');
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(act == null ? 'Nova atividade' : 'Editar atividade', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nome da atividade', hintText: 'Ex.: treinar saque de vôlei'),
              ),
              DropdownButtonFormField<String>(
                value: sport,
                decoration: const InputDecoration(labelText: 'Esporte ou categoria'),
                items: [for (final s in sportOptions) DropdownMenuItem(value: s, child: Text(s))],
                onChanged: (v) => setSt(() => sport = v ?? sport),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Place>(
                value: place,
                decoration: const InputDecoration(labelText: 'Local'),
                items: [for (final p in Place.values) DropdownMenuItem(value: p, child: Text(placeLabel(p)))],
                onChanged: (v) => setSt(() => place = v ?? place),
              ),
              Row(
                children: [
                  const Expanded(child: Text('Duração')),
                  IconButton(onPressed: () => setSt(() => minutes = (minutes - 5).clamp(5, 240).toInt()), icon: const Icon(Icons.remove_circle_outline), tooltip: 'Diminuir duração'),
                  SizedBox(width: 64, child: Text('$minutes min', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
                  IconButton(onPressed: () => setSt(() => minutes = (minutes + 5).clamp(5, 240).toInt()), icon: const Icon(Icons.add_circle_outline), tooltip: 'Aumentar duração'),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  if (name.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Dê um nome à atividade.')));
                    return;
                  }
                  Navigator.pop(ctx, 'save');
                },
                child: const Text('Salvar'),
              ),
              if (act != null)
                TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('Excluir atividade')),
            ],
          ),
        ),
      ),
    );
    if (result == 'delete' && act != null) {
      await state.removeActivity(act.id);
    } else if (result == 'save') {
      await state.upsertActivity(Activity(id: act?.id ?? newId(), name: name.text.trim(), minutes: minutes, place: place, sport: sport));
    }
  }
}
