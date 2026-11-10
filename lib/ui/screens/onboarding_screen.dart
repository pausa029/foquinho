// Configuração inicial: curta, opcional e fácil de pular.

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../logic/stats.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

const List<String> kSubjectOptions = [
  'Matemática', 'Português', 'Redação', 'Inglês', 'História', 'Geografia', 'Ciências', 'Biologia', 'Física', 'Química', 'Filosofia', 'Sociologia', 'Artes', 'Educação Física',
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;
  static const int steps = 5;

  final nick = TextEditingController();
  SchoolLevel? level;
  final subjects = <String>[]; // nomes
  final hard = <String>{};
  final sports = <String>[];
  int studyGoal = 60;
  int moveGoal = 30;
  int? screenGoal;
  bool remindersOn = true;
  String remindFrom = '08:00';
  String remindTo = '21:00';
  String quietFrom = '22:00';
  String quietTo = '07:00';

  @override
  void dispose() {
    nick.dispose();
    super.dispose();
  }

  Future<void> finish() async {
    final state = AppScope.of(context);
    final name = nick.text.trim();
    final p = Profile(
      nickname: name.isEmpty ? 'Estudante' : name,
      level: level,
      sports: List.of(sports),
      studyGoalMin: studyGoal,
      moveGoalMin: moveGoal,
      screenGoalMin: screenGoal,
      remindersOn: remindersOn,
      remindFrom: remindFrom,
      remindTo: remindTo,
      quietFrom: quietFrom,
      quietTo: quietTo,
    );
    await state.saveProfile(p);
    for (final s in subjects) {
      await state.addSubject(s, hard: hard.contains(s));
    }
    await state.finishOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  for (var i = 0; i < steps; i++)
                    Expanded(
                      child: Container(
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i <= step ? cs.primary : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Passo ${step + 1} de $steps · tudo é opcional', style: TextStyle(color: cs.onSurfaceVariant))),
                  TextButton(onPressed: finish, child: const Text('Pular tudo')),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [_body()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (step > 0) OutlinedButton(onPressed: () => setState(() => step--), child: const Text('Voltar')),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      if (step < steps - 1) {
                        setState(() => step++);
                      } else {
                        finish();
                      }
                    },
                    child: Text(step < steps - 1 ? 'Continuar' : 'Concluir'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String t, [String? sub]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(t, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
        if (sub != null) ...[const SizedBox(height: 6), Text(sub, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _body() {
    switch (step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.waving_hand_outlined, color: Theme.of(context).colorScheme.onPrimary),
                ),
                const SizedBox(width: 10),
                Text('Foquinho', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            _title('Menos tela. Mais estudo e movimento.', 'Como você quer ser chamado? Não pedimos e-mail nem telefone.'),
            TextField(
              controller: nick,
              maxLength: 20,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome ou apelido'),
            ),
            const SizedBox(height: 12),
            Text('Série ou nível (opcional)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in SchoolLevel.values)
                  ChoiceChip(label: Text(schoolLevelLabel(l)), selected: level == l, onSelected: (v) => setState(() => level = v ? l : null)),
              ],
            ),
            const SizedBox(height: 16),
            const InfoNote('Seus dados ficam só neste aparelho. Nada é enviado para a internet.'),
          ],
        );
      case 1:
        final all = [...kSubjectOptions, ...subjects.where((s) => !kSubjectOptions.contains(s))];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title('Quais matérias você está estudando?', 'Elas viram sugestões de estudo feitas para você.'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in all)
                  FilterChip(
                    label: Text(s),
                    selected: subjects.contains(s),
                    onSelected: (v) => setState(() {
                      if (v) {
                        subjects.add(s);
                      } else {
                        subjects.remove(s);
                        hard.remove(s);
                      }
                    }),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: const Text('Outra matéria'),
                  onPressed: () async {
                    final v = await promptText(context, title: 'Nome da matéria', maxLength: 40);
                    if (v != null && !subjects.contains(v)) setState(() => subjects.add(v));
                  },
                ),
              ],
            ),
            if (subjects.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Quais você considera mais difíceis?', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Elas aparecem primeiro nas sugestões.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in subjects)
                    FilterChip(
                      label: Text(s),
                      selected: hard.contains(s),
                      onSelected: (v) => setState(() => v ? hard.add(s) : hard.remove(s)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const InfoNote('Assuntos de prova, datas e trabalhos você cadastra depois na aba Plano.'),
          ],
        );
      case 2:
        final all = [...kSportOptions, ...sports.where((s) => !kSportOptions.contains(s))];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title('Quais esportes ou atividades você gosta?', 'Marque quantos quiser. Dá para mudar depois.'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in all)
                  FilterChip(
                    label: Text(s),
                    selected: sports.contains(s),
                    onSelected: (v) => setState(() => v ? sports.add(s) : sports.remove(s)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: const Text('Outro'),
                  onPressed: () async {
                    final v = await promptText(context, title: 'Esporte ou atividade', maxLength: 40);
                    if (v != null && !sports.contains(v)) setState(() => sports.add(v));
                  },
                ),
              ],
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title('Quanto tempo por dia você quer dedicar?', 'Comece pequeno. Você ajusta quando quiser.'),
            _stepRow('Estudo por dia', fmtMin(studyGoal), () => setState(() => studyGoal = (studyGoal - 15).clamp(15, 600).toInt()), () => setState(() => studyGoal = (studyGoal + 15).clamp(15, 600).toInt())),
            _stepRow('Atividade física por dia', fmtMin(moveGoal), () => setState(() => moveGoal = (moveGoal - 10).clamp(10, 300).toInt()), () => setState(() => moveGoal = (moveGoal + 10).clamp(10, 300).toInt())),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Meta diária de tempo de tela'),
              subtitle: const Text('O app não mede o tempo sozinho: você informa o valor que o celular mostra.'),
              value: screenGoal != null,
              onChanged: (v) => setState(() => screenGoal = v ? 240 : null),
            ),
            if (screenGoal != null)
              _stepRow('Tempo de tela por dia', fmtMin(screenGoal!), () => setState(() => screenGoal = (screenGoal! - 15).clamp(15, 1440).toInt()), () => setState(() => screenGoal = (screenGoal! + 15).clamp(15, 1440).toInt())),
            const SizedBox(height: 12),
            const InfoNote('Metas são objetivos, não obrigações. Passar delas não gera bronca nem punição.'),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title('Quando você aceita lembretes?', 'Os lembretes aparecem dentro do app. No Android, dá para ligar também as notificações do sistema.'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar lembretes de estudo e movimento'),
              value: remindersOn,
              onChanged: (v) => setState(() => remindersOn = v),
            ),
            if (remindersOn) ...[
              _timeRow('Aceito lembretes das', remindFrom, (v) => setState(() => remindFrom = v)),
              _timeRow('até as', remindTo, (v) => setState(() => remindTo = v)),
              const Divider(),
              _timeRow('Não me incomodar das', quietFrom, (v) => setState(() => quietFrom = v)),
              _timeRow('até as', quietTo, (v) => setState(() => quietTo = v)),
            ],
            const SizedBox(height: 12),
            const InfoNote('No app Android, você pode ligar depois as notificações do sistema em Ajustes → Lembretes, para ser avisado mesmo com o app fechado.'),
          ],
        );
    }
  }

  Widget _stepRow(String label, String value, VoidCallback minus, VoidCallback plus) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(onPressed: minus, icon: const Icon(Icons.remove_circle_outline), tooltip: 'Diminuir $label'),
          SizedBox(width: 64, child: Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
          IconButton(onPressed: plus, icon: const Icon(Icons.add_circle_outline), tooltip: 'Aumentar $label'),
        ],
      ),
    );
  }

  Widget _timeRow(String label, String value, ValueChanged<String> onPick) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: OutlinedButton(
        onPressed: () async {
          final v = await pickHm(context, value);
          if (v != null) onPick(v);
        },
        child: Text(value),
      ),
    );
  }
}
