// Ajustes: perfil, metas, lembretes, aparência, privacidade e exclusão de dados.

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../logic/stats.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/foquinha.dart';
import 'account_screen.dart';
import 'reviews_screen.dart';

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
          if (state.cloudAvailable) ...[
            const SectionTitle('Conta'),
            Card(
              child: ListTile(
                leading: Icon(state.signedIn ? Icons.cloud_done_outlined : Icons.account_circle_outlined),
                title: Text(state.signedIn ? (state.session!.email.isEmpty ? 'Conta conectada' : state.session!.email) : 'Entrar ou criar conta'),
                subtitle: Text(state.signedIn ? (state.cloudNote ?? 'Seus dados estão guardados na conta') : 'Guarde seus dados e use em outro aparelho'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen())),
              ),
            ),
          ],
          const SectionTitle('Estudo'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_repeat),
              title: const Text('Revisões'),
              subtitle: Text(state.data.reviewOn ? 'Revisão 1, 7 e 30 dias depois de cada estudo' : 'Desligadas'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReviewsScreen())),
            ),
          ),
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
              ],
            ),
          ),

          const SectionTitle('Meta diária'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _stepRow(context, 'Estudo', fmtMin(p.studyGoalMin), () => saveP((x) => x.studyGoalMin = (x.studyGoalMin - 15).clamp(15, 600).toInt()), () => saveP((x) => x.studyGoalMin = (x.studyGoalMin + 15).clamp(15, 600).toInt())),
                ],
              ),
            ),
          ),

          const SectionTitle('Lembretes'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Lembretes'),
                  subtitle: const Text('Chave geral: vale para os lembretes dentro do app e para as notificações.'),
                  value: p.remindersOn,
                  onChanged: (v) => saveP((x) => x.remindersOn = v),
                ),
                if (p.remindersOn) ...[
                  _timeTile(context, 'Aceito lembretes das', p.remindFrom, (v) => saveP((x) => x.remindFrom = v)),
                  _timeTile(context, 'até as', p.remindTo, (v) => saveP((x) => x.remindTo = v)),
                  _timeTile(context, 'Não me incomodar das', p.quietFrom, (v) => saveP((x) => x.quietFrom = v)),
                  _timeTile(context, 'até as', p.quietTo, (v) => saveP((x) => x.quietTo = v)),
                ],
              ],
            ),
          ),

          const SectionTitle('Notificações e alarme'),
          Card(
            child: Column(
              children: [
                if (!state.notificationsSupported)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: InfoNote('Notificações do sistema só existem no aplicativo instalado (Android). Nesta versão, os lembretes aparecem dentro do app e o temporizador avisa na tela.'),
                  )
                else ...[
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Notificações do sistema'),
                    subtitle: Text(p.notifyOn ? 'Ligadas: o Foquinho avisa mesmo com o app fechado.' : 'Desligadas.'),
                    value: p.notifyOn,
                    onChanged: (v) => _toggleNotifications(context, state, v),
                  ),
                  if (p.notifyOn) ...[
                    const ListTile(
                      leading: Icon(Icons.alarm),
                      title: Text('Alarme do temporizador'),
                      subtitle: Text('Toca e vibra quando o foco ou o intervalo termina, mesmo com a tela apagada. No fim da sessão o som repete até você parar. Usa o volume de alarme do celular.'),
                    ),
                    SwitchListTile(
                      title: const Text('Lembrete para estudar'),
                      value: p.studyRemindOn,
                      onChanged: (v) => saveP((x) => x.studyRemindOn = v),
                    ),
                    if (p.studyRemindOn) _timeTile(context, 'Todos os dias às', p.studyRemindAt, (v) => saveP((x) => x.studyRemindAt = v)),
                    SwitchListTile(
                      title: const Text('Avisos ao longo do dia'),
                      subtitle: const Text('Um por vez, alternando: estudar, revisar, prova ou tarefa chegando, beber água e alongar.'),
                      value: p.nudgeOn,
                      onChanged: (v) => saveP((x) => x.nudgeOn = v),
                    ),
                    if (p.nudgeOn)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _stepRow(context, 'Um aviso a cada', fmtMin(p.nudgeEveryMin), () => saveP((x) => x.nudgeEveryMin = (x.nudgeEveryMin - 15).clamp(30, 480).toInt()), () => saveP((x) => x.nudgeEveryMin = (x.nudgeEveryMin + 15).clamp(30, 480).toInt())),
                      ),
                    const ListTile(
                      leading: Icon(Icons.event_note_outlined),
                      title: Text('Tarefas e provas'),
                      subtitle: Text('Aviso na véspera e no dia do prazo das tarefas; 3 dias antes, na véspera e no dia das provas.'),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => state.notifier?.showTest(),
                          icon: const Icon(Icons.volume_up_outlined),
                          label: const Text('Testar o som do alarme'),
                        ),
                      ),
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: InfoNote('Os avisos são agendados no próprio aparelho, sem internet, e renovados cada vez que você abre o app (os do dia a dia valem por 3 dias; provas, tarefas e sessões, por 7). Eles chegam em horário fixo. Cada aviso some quando chega o próximo, para não acumular. O período "não me incomodar" é respeitado.'),
                  ),
                ],
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

          const SectionTitle('Permissões'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('O que esta versão faz e não faz', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _bullet(context, Icons.check, 'Metas, temporizadores, sugestões e histórico funcionam sem nenhuma permissão.'),
                  _bullet(context, state.notificationsSupported ? Icons.check : Icons.close, state.notificationsSupported ? 'Notificações e alarme do temporizador com o app fechado, se você ligar em "Notificações e alarme". É a única permissão que o app pede.' : 'Nesta versão (navegador) não há notificações com o app fechado; elas existem no aplicativo Android.'),
                ],
              ),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Foquinha(pose: FoquinhaPose.acenando, size: 44),
              title: const Text('Rever o tutorial da Foquinha'),
              subtitle: const Text('Mostra de novo para que serve cada parte do app'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => state.setTourDone(false),
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
          Center(child: Text('Foquinho · Estude no seu ritmo.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
        ],
      ),
    );
  }

  Future<void> _toggleNotifications(BuildContext context, AppState state, bool on) async {
    if (!on) {
      await state.disableNotifications();
      return;
    }
    // Explica antes de pedir a permissão ao sistema.
    final go = await confirmDialog(
      context,
      title: 'Ligar notificações?',
      text: 'O Foquinho usa notificações para: tocar o alarme quando o temporizador termina, lembrar a hora de estudar e avisar de tarefas e provas. Nada é enviado para a internet. Em seguida o celular vai pedir a sua permissão.',
      yes: 'Continuar',
    );
    if (!go) return;
    final ok = await state.enableNotifications();
    if (!context.mounted) return;
    showSnack(context, ok ? 'Notificações ligadas.' : 'Permissão negada. Para ligar depois, libere as notificações do Foquinho nas configurações do celular.');
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
}
