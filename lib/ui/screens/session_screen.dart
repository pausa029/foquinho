// Temporizador de estudo (foco com intervalos) e de exercício / pausa ativa.
// O tempo é contado pelo relógio do aparelho, então continua certo mesmo
// se a tela apagar ou o app ficar em segundo plano.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_state.dart';
import '../../logic/stats.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

class SessionScreen extends StatefulWidget {
  final SessionKind? kind;
  final String? presetTitle;
  final int? presetMinutes;
  final String? presetSubjectId;
  final String? presetTopic;
  final String? presetTaskId;

  const SessionScreen({
    super.key,
    this.kind,
    this.presetTitle,
    this.presetMinutes,
    this.presetSubjectId,
    this.presetTopic,
    this.presetTaskId,
  });

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  Timer? _timer;
  late SessionKind kind;
  late TextEditingController title;
  String? subjectId;
  int minutes = 25;
  bool withBreaks = false;
  int focusMin = 25;
  int breakMin = 5;
  int cycles = 4;
  String? lastEvent;

  // tela de registro
  int doneMinutes = 0;
  final note = TextEditingController();
  bool markDone = true;
  bool _recordPrepared = false;

  @override
  void initState() {
    super.initState();
    kind = widget.kind ?? SessionKind.estudo;
    title = TextEditingController(text: widget.presetTitle ?? '');
    subjectId = widget.presetSubjectId;
    minutes = widget.presetMinutes ?? (kind == SessionKind.estudo ? 25 : 10);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final state = AppScope.of(context);
    final ev = state.syncSession();
    if (ev != null) {
      lastEvent = ev;
      if (state.data.soundOn) {
        HapticFeedback.heavyImpact();
        HapticFeedback.vibrate();
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    title.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final a = state.active;
    final Widget body;
    final String appTitle;
    if (a == null) {
      appTitle = kind == SessionKind.estudo ? 'Sessão de estudo' : 'Pausa ativa';
      body = _setup(context, state);
    } else if (state.finished || _forceRecord) {
      appTitle = 'Registrar sessão';
      body = _record(context, state, a);
    } else {
      appTitle = a.kind == SessionKind.estudo ? 'Estudando' : 'Em movimento';
      body = _running(context, state, a);
    }
    return Scaffold(
      appBar: AppBar(title: Text(appTitle)),
      body: SafeArea(child: body),
    );
  }

  // ---------- configuração ----------

  Widget _setup(BuildContext context, AppState state) {
    final d = state.data;
    final isStudy = kind == SessionKind.estudo;
    final cs = Theme.of(context).colorScheme;
    final presets = isStudy ? const [10, 15, 25, 50] : const [5, 10, 15, 20, 30];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.kind == null)
          SegmentedButton<SessionKind>(
            segments: const [
              ButtonSegment(value: SessionKind.estudo, label: Text('Estudo'), icon: Icon(Icons.menu_book)),
              ButtonSegment(value: SessionKind.exercicio, label: Text('Exercício'), icon: Icon(Icons.directions_run)),
            ],
            selected: {kind},
            onSelectionChanged: (s) => setState(() {
              kind = s.first;
              minutes = kind == SessionKind.estudo ? 25 : 10;
            }),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: title,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: isStudy ? 'O que você vai estudar? (opcional)' : 'Qual atividade? (opcional)'),
        ),
        if (isStudy) ...[
          const SizedBox(height: 8),
          Text('Matéria', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          if (d.subjects.isEmpty)
            Text('Cadastre matérias na aba Plano para escolher aqui.', style: TextStyle(color: cs.onSurfaceVariant))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(label: const Text('Nenhuma'), selected: subjectId == null, onSelected: (_) => setState(() => subjectId = null)),
                for (final s in d.subjects)
                  ChoiceChip(label: Text(s.name), selected: subjectId == s.id, onSelected: (_) => setState(() => subjectId = s.id)),
              ],
            ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Foco com intervalos'),
            subtitle: const Text('Blocos de foco com descanso entre eles, por exemplo 25/5 ou 50/10.'),
            value: withBreaks,
            onChanged: (v) => setState(() => withBreaks = v),
          ),
        ],
        if (isStudy && withBreaks) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(label: const Text('25 / 5'), selected: focusMin == 25 && breakMin == 5, onSelected: (_) => setState(() { focusMin = 25; breakMin = 5; })),
              ChoiceChip(label: const Text('50 / 10'), selected: focusMin == 50 && breakMin == 10, onSelected: (_) => setState(() { focusMin = 50; breakMin = 10; })),
            ],
          ),
          _stepper('Foco', '$focusMin min', () => setState(() => focusMin = (focusMin - 5).clamp(5, 120).toInt()), () => setState(() => focusMin = (focusMin + 5).clamp(5, 120).toInt())),
          _stepper('Intervalo', '$breakMin min', () => setState(() => breakMin = (breakMin - 1).clamp(1, 30).toInt()), () => setState(() => breakMin = (breakMin + 1).clamp(1, 30).toInt())),
          _stepper('Ciclos', '$cycles', () => setState(() => cycles = (cycles - 1).clamp(1, 8).toInt()), () => setState(() => cycles = (cycles + 1).clamp(1, 8).toInt())),
          Text(
            '$cycles ciclos de $focusMin min com $breakMin min de intervalo: ${fmtMin(cycles * focusMin)} de estudo, ${fmtMin(cycles * focusMin + (cycles - 1) * breakMin)} no total.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text('Duração', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in presets) ChoiceChip(label: Text('$m min'), selected: minutes == m, onSelected: (_) => setState(() => minutes = m)),
              ActionChip(
                label: Text(presets.contains(minutes) ? 'Outro' : '$minutes min'),
                onPressed: () async {
                  final v = await promptText(context, title: 'Minutos (1 a 180)', initial: '$minutes', maxLength: 3);
                  final n = int.tryParse(v ?? '');
                  if (n != null && n >= 1 && n <= 180) setState(() => minutes = n);
                },
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => _start(state),
          icon: const Icon(Icons.play_arrow),
          label: Text(isStudy && withBreaks ? 'Iniciar $cycles ciclos' : 'Iniciar ${fmtMin(minutes)}'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: isStudy ? cs.primary : cs.tertiary),
        ),
        const SizedBox(height: 12),
        if (!isStudy) const InfoNote('Respeite seus limites. Se sentir dor, tontura ou mal-estar, pare. O TelaTchau não dá orientação médica.'),
        if (isStudy) const InfoNote('Você pode sair desta tela: o tempo continua contando pelo relógio do aparelho.'),
      ],
    );
  }

  Future<void> _start(AppState state) async {
    final isStudy = kind == SessionKind.estudo;
    final t = title.text.trim();
    final subj = state.data.subjectById(subjectId);
    final autoTitle = isStudy ? (subj != null ? 'Estudar ${subj.name}' : 'Sessão de estudo') : 'Pausa ativa';
    await state.startSession(
      kind: kind,
      title: t.isEmpty ? autoTitle : t,
      subjectId: isStudy ? subjectId : null,
      topic: widget.presetTopic,
      taskId: isStudy ? widget.presetTaskId : null,
      focusMin: isStudy && withBreaks ? focusMin : minutes,
      breakMin: breakMin,
      cycles: isStudy && withBreaks ? cycles : 1,
    );
    _recordPrepared = false;
    if (mounted) setState(() {});
  }

  Widget _stepper(String label, String value, VoidCallback minus, VoidCallback plus) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(onPressed: minus, icon: const Icon(Icons.remove_circle_outline), tooltip: 'Diminuir $label'),
        SizedBox(width: 64, child: Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
        IconButton(onPressed: plus, icon: const Icon(Icons.add_circle_outline), tooltip: 'Aumentar $label'),
      ],
    );
  }

  // ---------- em andamento ----------

  Widget _running(BuildContext context, AppState state, ActiveSession a) {
    final cs = Theme.of(context).colorScheme;
    final isStudy = a.kind == SessionKind.estudo;
    final rem = state.remainingMs();
    final frac = a.phaseMs == 0 ? 0.0 : (1 - rem / a.phaseMs).clamp(0.0, 1.0).toDouble();
    final color = a.phase == Phase.intervalo ? cs.secondary : (isStudy ? cs.primary : cs.tertiary);
    final phaseLabel = a.paused
        ? 'Pausado'
        : a.cycles > 1
            ? '${a.phase == Phase.foco ? 'Foco' : 'Intervalo'} · ciclo ${a.cycleIndex} de ${a.cycles}'
            : (isStudy ? 'Foco' : 'Movimento');
    final remText = fmtClock(rem);
    final subj = state.data.subjectName(a.subjectId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: Text(a.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
        if (a.subjectId != null) Center(child: Text(subj, style: TextStyle(color: cs.onSurfaceVariant))),
        const SizedBox(height: 24),
        Semantics(
          label: 'Faltam $remText. $phaseLabel.',
          liveRegion: true,
          child: ExcludeSemantics(
            child: Center(
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: CircularProgressIndicator(value: frac, strokeWidth: 14, color: color, backgroundColor: cs.surfaceContainerHighest, strokeCap: StrokeCap.round),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(remText, style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
                        Text(phaseLabel.toUpperCase(), style: TextStyle(color: cs.onSurfaceVariant, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (lastEvent == 'intervalo') const InfoNote('Hora do intervalo. Levante, beba água, olhe para longe.', icon: Icons.self_improvement),
        if (lastEvent == 'foco') const InfoNote('De volta ao foco. Você está indo bem.', icon: Icons.bolt),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: a.paused
                  ? FilledButton.icon(onPressed: () => state.resumeSession(), icon: const Icon(Icons.play_arrow), label: const Text('Retomar'))
                  : OutlinedButton.icon(onPressed: () => state.pauseSession(), icon: const Icon(Icons.pause), label: const Text('Pausar')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  final mins = state.concludeMinutes();
                  final ok = await confirmDialog(context, title: 'Concluir agora?', text: 'Você fez ${fmtMin(mins)} até aqui. Dá para registrar esse tempo na próxima tela.', yes: 'Concluir');
                  if (!ok) return;
                  await state.pauseSession();
                  setState(() => _forceRecord = true);
                },
                icon: const Icon(Icons.check),
                label: const Text('Concluir'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            final ok = await confirmDialog(context, title: 'Cancelar a sessão?', text: 'Nada será registrado.', yes: 'Cancelar sessão', danger: true);
            if (!ok) return;
            await state.cancelSession();
            if (context.mounted) Navigator.of(context).maybePop();
          },
          icon: const Icon(Icons.close),
          label: const Text('Cancelar sem registrar'),
        ),
        const SizedBox(height: 8),
        const InfoNote('Pode deixar o celular de lado. O tempo continua contando mesmo fora desta tela.'),
      ],
    );
  }

  bool _forceRecord = false;

  // ---------- registro ----------

  Widget _record(BuildContext context, AppState state, ActiveSession a) {
    if (!_recordPrepared) {
      doneMinutes = state.concludeMinutes();
      _recordPrepared = true;
    }
    final cs = Theme.of(context).colorScheme;
    final isStudy = a.kind == SessionKind.estudo;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: Icon(Icons.check_circle, size: 64, color: isStudy ? cs.primary : cs.tertiary)),
        const SizedBox(height: 8),
        Center(child: Text(_forceRecord ? 'Sessão encerrada' : 'Tempo concluído', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
        Center(child: Text(a.title, textAlign: TextAlign.center)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quer registrar ${isStudy ? 'o estudo' : 'a atividade'}?', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _stepper('Minutos feitos', fmtMin(doneMinutes), () => setState(() => doneMinutes = (doneMinutes - 1).clamp(0, 600).toInt()), () => setState(() => doneMinutes = (doneMinutes + 1).clamp(0, 600).toInt())),
                const SizedBox(height: 8),
                TextField(
                  controller: note,
                  maxLength: 200,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Observação (opcional)', hintText: 'Ex.: entendi equações, falta revisar gráficos'),
                ),
                if (a.taskId != null)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Marcar a tarefa como concluída'),
                    value: markDone,
                    onChanged: (v) => setState(() => markDone = v ?? false),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: doneMinutes < 1
              ? null
              : () async {
                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final rec = await state.finishAndRecord(minutes: doneMinutes, note: note.text, markTaskDone: markDone);
                  _forceRecord = false;
                  messenger.showSnackBar(SnackBar(content: Text(rec == null ? 'Nada registrado.' : 'Registrado: ${fmtMin(rec.minutes)} de ${isStudy ? 'estudo' : 'exercício'}.')));
                  nav.maybePop();
                },
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Registrar no histórico'),
        ),
        if (doneMinutes < 1) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Menos de 1 minuto: não há o que registrar.', style: TextStyle(color: cs.onSurfaceVariant))),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () async {
            final nav = Navigator.of(context);
            await state.cancelSession();
            _forceRecord = false;
            nav.maybePop();
          },
          child: const Text('Não registrar'),
        ),
      ],
    );
  }
}
