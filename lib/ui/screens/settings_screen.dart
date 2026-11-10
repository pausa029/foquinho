// Ajustes: perfil, metas, lembretes, aparência, privacidade e exclusão de dados.

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../logic/stats.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final d = state.data;
    final p = d.profile ?? Profile(nickname: 'Estudante');
    final cs = Theme.of(context).colorScheme;

    Future<void> saveP(void Function(Profile) edit) async {
      edit(p);
      await state.saveProfile(p);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SectionTitle('Perfil'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Nome ou apelido'),
                  subtitle: Text(p.nickname),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final v = await promptText(context, title: 'Nome ou apelido', initial: p.nickname, maxLength: 20);
                    if (v != null) await saveP((x) => x.nickname = v);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Série ou nível'),
                  subtitle: Text(p.level == null ? 'Não informado' : schoolLevelLabel(p.level!)),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final v = await showDialog<SchoolLevel?>(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: const Text('Série ou nível'),
                        children: [
                          for (final l in SchoolLevel.values) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, l), child: Text(schoolLevelLabel(l))),
                          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, null), child: const Text('Prefiro não informar')),
                        ],
                      ),
                    );
                    await saveP((x) => x.level = v);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sports_soccer_outlined),
                  title: const Text('Esportes e atividades'),
                  subtitle: Text(p.sports.isEmpty ? 'Nenhum escolhido' : p.sports.join(', ')),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editSports(context, state, p),
                ),
              ],
            ),
          ),

          const SectionTitle('Metas diárias'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _stepRow(context, 'Estudo', fmtMin(p.studyGoalMin), () => saveP((x) => x.studyGoalMin = (x.studyGoalMin - 15).clamp(15, 600).toInt()), () => saveP((x) => x.studyGoalMin = (x.studyGoalMin + 15).clamp(15, 600).toInt())),
                  _stepRow(context, 'Atividade física', fmtMin(p.moveGoalMin), () => saveP((x) => x.moveGoalMin = (x.moveGoalMin - 10).clamp(10, 300).toInt()), () => saveP((x) => x.moveGoalMin = (x.moveGoalMin + 10).clamp(10, 300).toInt())),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Meta de tempo de tela'),
                    subtitle: const Text('Registro manual: o app não mede o tempo sozinho.'),
                    value: p.screenGoalMin != null,
                    onChanged: (v) => saveP((x) => x.screenGoalMin = v ? 240 : null),
                  ),
                  if (p.screenGoalMin != null)
                    _stepRow(context, 'Tempo de tela', fmtMin(p.screenGoalMin!), () => saveP((x) => x.screenGoalMin = (x.screenGoalMin! - 15).clamp(15, 1440).toInt()), () => saveP((x) => x.screenGoalMin = (x.screenGoalMin! + 15).clamp(15, 1440).toInt())),
                ],
              ),
            ),
          ),

          const SectionTitle('Lembretes'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Lembretes dentro do app'),
                  subtitle: const Text('Aparecem no painel inicial quando o app está aberto.'),
                  value: p.remindersOn,
                  onChanged: (v) => saveP((x) => x.remindersOn = v),
                ),
                if (p.remindersOn) ...[
                  _timeTile(context, 'Aceito lembretes das', p.remindFrom, (v) => saveP((x) => x.remindFrom = v)),
                  _timeTile(context, 'até as', p.remindTo, (v) => saveP((x) => x.remindTo = v)),
                  _timeTile(context, 'Não me incomodar das', p.quietFrom, (v) => saveP((x) => x.quietFrom = v)),
                  _timeTile(context, 'até as', p.quietTo, (v) => saveP((x) => x.quietTo = v)),
                ],
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: InfoNote('Notificações com o app fechado não existem nesta versão: assim o app não pede nenhuma permissão do sistema.'),
                ),
              ],
            ),
          ),

          const SectionTitle('Aparência e avisos'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: const Text('Tema'),
                  subtitle: Text(switch (d.theme) { ThemeChoice.sistema => 'Igual ao sistema', ThemeChoice.claro => 'Claro', ThemeChoice.escuro => 'Escuro' }),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SegmentedButton<ThemeChoice>(
                    segments: const [
                      ButtonSegment(value: ThemeChoice.sistema, label: Text('Sistema')),
                      ButtonSegment(value: ThemeChoice.claro, label: Text('Claro')),
                      ButtonSegment(value: ThemeChoice.escuro, label: Text('Escuro')),
                    ],
                    selected: {d.theme},
                    onSelectionChanged: (s) => state.setTheme(s.first),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration),
                  title: const Text('Vibrar ao terminar uma fase'),
                  subtitle: const Text('Depende do aparelho permitir vibração.'),
                  value: d.soundOn,
                  onChanged: (v) => state.setSound(v),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: InfoNote('O tamanho do texto segue o ajuste de acessibilidade do seu celular.'),
                ),
              ],
            ),
          ),

          const SectionTitle('Tempo de tela e permissões'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('O que esta versão faz e não faz', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _bullet(context, Icons.check, 'Registro manual do tempo de tela, identificado como manual.'),
                  _bullet(context, Icons.check, 'Metas, temporizadores, sugestões e histórico funcionam sem nenhuma permissão.'),
                  _bullet(context, Icons.close, 'Não lê o tempo de tela sozinho. No Android isso exige a permissão especial "Acesso a dados de uso"; no iPhone, as APIs de Tempo de Uso da Apple, que exigem autorização e aprovação especiais. Nenhuma das duas foi implementada.'),
                  _bullet(context, Icons.close, 'Não bloqueia nem limita outros apps. Para isso, use Bem-estar digital (Android) ou Tempo de Uso (iPhone).'),
                  _bullet(context, Icons.close, 'Não envia notificações com o app fechado.'),
                ],
              ),
            ),
          ),

          const SectionTitle('Privacidade'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bullet(context, Icons.phone_android, 'Tudo fica guardado só neste aparelho, no espaço do próprio app. Não existe servidor, conta online nem sincronização.'),
                  _bullet(context, Icons.lock_outline, 'Não pedimos e-mail, telefone, senha, localização nem nome completo. Como não há senha, não há senha para proteger.'),
                  _bullet(context, Icons.block, 'Nenhum dado é vendido, compartilhado ou usado para anúncios. O app não tem rastreadores.'),
                  _bullet(context, Icons.child_care, 'Se você tem menos de 18 anos: nada sai do aparelho, mas vale combinar o uso com seus responsáveis.'),
                  _bullet(context, Icons.delete_outline, 'Desinstalar o app ou usar o botão abaixo apaga tudo.'),
                ],
              ),
            ),
          ),

          const SectionTitle('Apagar'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.delete_outline, color: cs.error),
                  title: const Text('Apagar perfil e todos os dados'),
                  subtitle: const Text('Volta para a tela inicial. Não tem volta.'),
                  onTap: () async {
                    final ok = await confirmDialog(context, title: 'Apagar tudo?', text: 'Perfil, matérias, provas, tarefas, atividades e histórico serão apagados deste aparelho.', yes: 'Apagar tudo', danger: true);
                    if (ok) await state.deleteEverything();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text('Foquinho 1.0 · Menos tela. Mais estudo e movimento.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _stepRow(BuildContext context, String label, String value, VoidCallback minus, VoidCallback plus) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(onPressed: minus, icon: const Icon(Icons.remove_circle_outline), tooltip: 'Diminuir $label'),
        SizedBox(width: 64, child: Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
        IconButton(onPressed: plus, icon: const Icon(Icons.add_circle_outline), tooltip: 'Aumentar $label'),
      ],
    );
  }

  Widget _timeTile(BuildContext context, String label, String value, ValueChanged<String> onPick) {
    return ListTile(
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

  Widget _bullet(BuildContext context, IconData i, String t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(t)),
        ],
      ),
    );
  }

  Future<void> _editSports(BuildContext context, AppState state, Profile p) async {
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
                Text('Esportes e atividades', style: Theme.of(ctx).textTheme.titleLarge),
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
}
