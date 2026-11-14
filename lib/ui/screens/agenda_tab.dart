// Agenda do planejamento de estudos: visão semanal e mensal, sessões do dia,
// progresso, criação/edição/reagendamento e geração do plano.

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../logic/planner.dart';
import '../../logic/stats.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import 'availability_screen.dart';
import 'session_screen.dart';

class AgendaTab extends StatefulWidget {
  final VoidCallback onGoSubjects;
  const AgendaTab({super.key, required this.onGoSubjects});

  @override
  State<AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<AgendaTab> {
  bool month = false;
  DateTime anchor = dayOnly(DateTime.now());
  String? selDay;
  PlanResult? last; // resultado da última geração (para mostrar o que não coube)
  final Set<String> prioritize = <String>{};

  // Semana = 7 dias corridos a partir de hoje (ou do dia escolhido), nunca dias que já passaram.
  DateTime get _today => dayOnly(DateTime.now());
  DateTime get _weekFrom => anchor.isBefore(_today) ? _today : anchor;
  DateTime get rangeFrom => month ? DateTime(anchor.year, anchor.month, 1, 12) : _weekFrom;
  DateTime get rangeTo => month ? DateTime(anchor.year, anchor.month + 1, 0, 12) : addDaysTo(_weekFrom, 6);
  bool get _canGoBack => month || _weekFrom.isAfter(_today);

  void _shift(int dir) {
    setState(() {
      if (month) {
        anchor = DateTime(anchor.year, anchor.month + dir, 1, 12);
      } else {
        final a = addDaysTo(_weekFrom, 7 * dir);
        anchor = a.isBefore(_today) ? _today : a;
      }
      selDay = null;
      last = null;
    });
  }

  Future<void> _openAvailability() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AvailabilityScreen()));
    if (mounted) setState(() {});
  }

  String _name(AppData d, PlanSession p) => '${d.subjectName(p.subjectId)}${p.topic == null ? '' : ' · ${p.topic}'}';

  String _dayLabel(String key, DateTime now) {
    final dt = parseDayKey(key)!;
    final today = dayKey(now) == key;
    return '${kWeekdayShort[dt.weekday - 1]} ${fmtDay(key)}${today ? ' · hoje' : ''}';
  }

  // ---------- gerar o plano ----------

  Future<void> _generate() async {
    final state = AppScope.of(context);
    final d = state.data;
    final now = DateTime.now();
    final from = rangeFrom, to = rangeTo;
    final r = generatePlan(d, from, to, now, prioritize: prioritize);
    final keptIds = r.kept.map((p) => p.id).toSet();
    final leaving = sessionsBetween(d, dayKey(from), dayKey(to)).where((p) => !keptIds.contains(p.id)).toList();

    if (r.sessions.isEmpty && leaving.isEmpty) {
      setState(() => last = r);
      showSnack(context, r.slots == 0 ? month ? 'Não há horários livres neste mês. Confira a disponibilidade.' : 'Não há horários livres nos próximos 7 dias. Confira a disponibilidade e o limite por dia.' : 'Nada novo para encaixar neste período.');
      return;
    }
    if (leaving.isNotEmpty) {
      final ok = await _confirmChange(d, now, leaving, r);
      if (!ok) return;
    }
    await state.applyPlan(r, from, to);
    if (!mounted) return;
    setState(() => last = r);
    showSnack(context, r.sessions.length == 1 ? '1 sessão planejada.' : '${r.sessions.length} sessões planejadas.');
  }

  /// Mostra o que sai e o que entra antes de aplicar.
  Future<bool> _confirmChange(AppData d, DateTime now, List<PlanSession> leaving, PlanResult r) async {
    String line(PlanSession p) => '${_dayLabel(p.day, now)} ${p.start} · ${_name(d, p)}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atualizar o plano?'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('Ficam como estão: ${r.kept.length} ${r.kept.length == 1 ? 'sessão' : 'sessões'} (concluídas, fixadas, manuais ou de dias que já passaram).'),
              const SizedBox(height: 12),
              Text('Saem (${leaving.length}):', style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final p in leaving.take(8)) Text(line(p)),
              if (leaving.length > 8) Text('e mais ${leaving.length - 8}.'),
              const SizedBox(height: 12),
              Text('Entram (${r.sessions.length}):', style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final p in r.sessions.take(8)) Text(line(p)),
              if (r.sessions.length > 8) Text('e mais ${r.sessions.length - 8}.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aplicar')),
        ],
      ),
    );
    return ok == true;
  }

  // ---------- criar, editar e mover ----------

  Future<void> _edit({PlanSession? existing, String? day}) async {
    final state = AppScope.of(context);
    final d = state.data;
    if (d.subjects.isEmpty) return;
    final now = DateTime.now();
    var subjectId = existing?.subjectId ?? d.subjects.first.id;
    if (d.subjectById(subjectId) == null) subjectId = d.subjects.first.id;
    String? topic = existing?.topic;
    var dayK = existing?.day ?? day ?? dayKey(now);
    var start = existing?.start ?? '18:00';
    var minutes = existing?.minutes ?? d.plan.sessionMin;
    if (existing == null) {
      final sug = suggestSlots(d, parseDayKey(dayK) ?? now, minutes, now, count: 1);
      if (sug.isNotEmpty && sug.first.day == dayK) start = hmFromMinutes(sug.first.startMin);
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final topics = d.subjectById(subjectId)?.topics ?? const <String>[];
          final topicValue = topics.contains(topic) ? topic : null;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(existing == null ? 'Nova sessão' : 'Editar ou mover sessão', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: subjectId,
                  decoration: const InputDecoration(labelText: 'Matéria'),
                  items: [for (final s in d.subjects) DropdownMenuItem(value: s.id, child: Text(s.name))],
                  onChanged: (v) => setSt(() {
                    subjectId = v ?? subjectId;
                    topic = null;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: topicValue,
                  decoration: InputDecoration(labelText: 'Assunto', helperText: topics.isEmpty ? 'Cadastre assuntos na aba Matérias para escolher aqui.' : null),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Sem assunto específico')),
                    for (final t in topics) DropdownMenuItem<String?>(value: t, child: Text(t, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setSt(() => topic = v),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dia'),
                  subtitle: Text('${kWeekdayShort[parseDayKey(dayK)!.weekday - 1]}, ${fmtDate(parseDayKey(dayK)!)}'),
                  trailing: IconButton(
                    tooltip: 'Escolher o dia',
                    icon: const Icon(Icons.event),
                    onPressed: () async {
                      final v = await pickDay(ctx, dayK);
                      if (v != null) setSt(() => dayK = v);
                    },
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Horário de início'),
                  subtitle: Text(start),
                  trailing: IconButton(
                    tooltip: 'Escolher o horário',
                    icon: const Icon(Icons.schedule),
                    onPressed: () async {
                      final v = await pickHm(ctx, start);
                      if (v != null) setSt(() => start = v);
                    },
                  ),
                ),
                Row(
                  children: [
                    const Expanded(child: Text('Duração')),
                    IconButton(onPressed: () => setSt(() => minutes = (minutes - 5).clamp(10, 120).toInt()), icon: const Icon(Icons.remove_circle_outline), tooltip: 'Diminuir duração'),
                    SizedBox(width: 64, child: Text('$minutes min', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
                    IconButton(onPressed: () => setSt(() => minutes = (minutes + 5).clamp(10, 120).toInt()), icon: const Icon(Icons.add_circle_outline), tooltip: 'Aumentar duração'),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
              ],
            ),
          );
        },
      ),
    );
    if (saved != true || !mounted) return;

    // Confere choque de horário, limite diário e disponibilidade antes de gravar.
    var startMin = hmToMinutes(start);
    final check = checkSlot(d, day: dayK, startMin: startMin, minutes: minutes, ignoreId: existing?.id);
    if (!check.ok) {
      final choice = await _conflictDialog(d, now, check, dayK, minutes, existing?.id);
      if (choice == null) return;
      if (choice is SlotOption) {
        dayK = choice.day;
        startMin = choice.startMin;
      }
    }
    final changedTime = existing != null && (existing.day != dayK || existing.startMin != startMin);
    final p = PlanSession(
      id: existing?.id ?? newId(),
      subjectId: subjectId,
      topic: topic,
      day: dayK,
      start: hmFromMinutes(startMin),
      minutes: minutes,
      state: existing == null || (changedTime && existing.state != PlanState.concluida) ? PlanState.planejada : existing.state,
      pinned: existing?.pinned ?? false,
      manual: true,
      moved: changedTime || (existing?.moved ?? false),
    );
    await state.upsertPlanSession(p);
    if (mounted) showSnack(context, existing == null ? 'Sessão criada.' : (changedTime ? 'Sessão reagendada.' : 'Sessão atualizada.'));
  }

  /// Avisa do conflito e oferece horários livres. Devolve SlotOption, 'forcar' ou null.
  Future<Object?> _conflictDialog(AppData d, DateTime now, SlotCheck c, String dayK, int minutes, String? ignoreId) {
    final reasons = <String>[
      if (c.overlap) 'Esse horário bate com outra sessão.',
      if (c.overLimit) 'Com essa sessão, o dia passa do seu limite de ${fmtMin(d.plan.dailyMaxMin)}.',
      if (c.unavailable) 'Esse dia ou horário está fora da sua disponibilidade.',
    ];
    final options = suggestSlots(d, parseDayKey(dayK) ?? now, minutes, now, ignoreId: ignoreId);
    return showDialog<Object>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Esse horário tem um conflito'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final r in reasons) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(r)),
              const SizedBox(height: 6),
              Text(options.isEmpty ? 'Não encontrei horários livres nas próximas semanas.' : 'Horários livres mais próximos:', style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final o in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available_outlined),
                  title: Text('${_dayLabel(o.day, now)} às ${hmFromMinutes(o.startMin)}'),
                  onTap: () => Navigator.pop(ctx, o),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          if (!c.overlap) TextButton(onPressed: () => Navigator.pop(ctx, 'forcar'), child: const Text('Salvar mesmo assim')),
        ],
      ),
    );
  }

  /// Reagendamento rápido: escolhe entre os próximos horários livres.
  Future<void> _reschedule(PlanSession p) async {
    final state = AppScope.of(context);
    final d = state.data;
    final now = DateTime.now();
    final options = suggestSlots(d, now, p.minutes, now, ignoreId: p.id);
    if (options.isEmpty) {
      showSnack(context, 'Não encontrei horários livres. Confira a disponibilidade ou mova a sessão manualmente.');
      return;
    }
    final o = await showDialog<SlotOption>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Reagendar ${d.subjectName(p.subjectId)}'),
        children: [
          for (final o in options)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, o), child: Text('${_dayLabel(o.day, now)} às ${hmFromMinutes(o.startMin)}')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ],
      ),
    );
    if (o == null) return;
    p
      ..day = o.day
      ..start = hmFromMinutes(o.startMin)
      ..state = PlanState.planejada
      ..moved = true;
    await state.upsertPlanSession(p);
    if (mounted) showSnack(context, 'Sessão reagendada.');
  }

  void _startTimer(AppData d, PlanSession p) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SessionScreen(
        kind: SessionKind.estudo,
        presetTitle: '${d.subjectName(p.subjectId)}${p.topic == null ? '' : ': ${p.topic}'}',
        presetMinutes: p.minutes.clamp(1, 180).toInt(),
        presetSubjectId: p.subjectId,
        presetTopic: p.topic,
        presetPlanId: p.id,
      ),
    ));
  }

  // ---------- construção da tela ----------

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final d = state.data;
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();

    if (d.subjects.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'Cadastre suas matérias primeiro',
            text: 'O planejamento distribui as matérias que você cadastrar. Sem elas não há o que organizar.',
            action: FilledButton(onPressed: widget.onGoSubjects, child: const Text('Cadastrar matérias')),
          ),
        ],
      );
    }
    if (!d.plan.configured) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EmptyState(
            icon: Icons.event_available_outlined,
            title: 'Quando você pode estudar?',
            text: 'Para montar o plano, o Foquinho precisa saber seus dias e horários livres e quanto tempo por dia você quer estudar. Ele não inventa horários.',
            action: FilledButton(onPressed: _openAvailability, child: const Text('Informar disponibilidade')),
          ),
        ],
      );
    }

    final from = rangeFrom, to = rangeTo;
    final fromK = dayKey(from), toK = dayKey(to);
    final inRange = sessionsBetween(d, fromK, toK);
    final prog = planProgress(inRange);
    final todayK = dayKey(now);
    final todayList = sessionsBetween(d, todayK, todayK);
    final next = nextPlanned(d, now);
    final missed = missedSessions(d, now);
    final examsChanged = d.planSessions.isNotEmpty && d.plan.examSig != null && d.plan.examSig != examSignature(d);
    final hasGenerated = inRange.any((p) => !p.manual);
    final leftovers = last?.leftovers ?? const <PlanLeftover>[];
    final title = month
        ? '${const ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'][anchor.month - 1]} de ${anchor.year}'
        : (fromK == dayKey(now) ? 'Próximos 7 dias · ${fmtDay(fromK)} a ${fmtDay(toK)}' : '${fmtDay(fromK)} a ${fmtDay(toK)}');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Semana'), icon: Icon(Icons.view_week_outlined)),
                  ButtonSegment(value: true, label: Text('Mês'), icon: Icon(Icons.calendar_month_outlined)),
                ],
                selected: {month},
                onSelectionChanged: (s) => setState(() {
                  month = s.first;
                  if (!month) anchor = _today;
                  selDay = null;
                  last = null;
                }),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opções do plano',
              onSelected: (v) async {
                if (v == 'disp') {
                  await _openAvailability();
                } else if (v == 'pausa') {
                  await state.setPlanPaused(!d.plan.paused);
                } else if (v == 'apagar') {
                  final ok = await confirmDialog(context, title: 'Apagar o plano?', text: 'Todas as sessões planejadas serão apagadas. O histórico de estudo e a sua disponibilidade continuam.', yes: 'Apagar plano', danger: true);
                  if (ok) {
                    await state.clearPlan();
                    if (mounted) setState(() => last = null);
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'disp', child: Text('Disponibilidade')),
                PopupMenuItem(value: 'pausa', child: Text(d.plan.paused ? 'Retomar o plano' : 'Pausar o plano')),
                const PopupMenuItem(value: 'apagar', child: Text('Apagar o plano')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(onPressed: _canGoBack ? () => _shift(-1) : null, icon: const Icon(Icons.chevron_left), tooltip: month ? 'Mês anterior' : 'Semana anterior'),
            Expanded(child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
            IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right), tooltip: month ? 'Próximo mês' : 'Próxima semana'),
          ],
        ),

        if (d.plan.paused)
          Card(
            color: cs.secondaryContainer,
            child: ListTile(
              leading: Icon(Icons.pause_circle_outline, color: cs.onSecondaryContainer),
              title: Text('Plano pausado', style: TextStyle(color: cs.onSecondaryContainer, fontWeight: FontWeight.w600)),
              subtitle: Text('As sessões continuam aqui, sem avisos. Retome quando quiser.', style: TextStyle(color: cs.onSecondaryContainer)),
              trailing: TextButton(onPressed: () => state.setPlanPaused(false), child: const Text('Retomar')),
            ),
          ),
        if (examsChanged)
          Card(
            color: cs.tertiaryContainer,
            child: ListTile(
              leading: Icon(Icons.event_note_outlined, color: cs.onTertiaryContainer),
              title: Text('Suas provas mudaram', style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.w600)),
              subtitle: Text('O plano foi montado antes da mudança. Você vê o que muda antes de aplicar.', style: TextStyle(color: cs.onTertiaryContainer)),
              trailing: TextButton(onPressed: _generate, child: const Text('Atualizar')),
            ),
          ),

        // Resumo: hoje, próxima sessão e progresso.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todayList.isEmpty ? 'Hoje: nenhuma sessão planejada' : 'Hoje: ${todayList.length} ${todayList.length == 1 ? 'sessão' : 'sessões'}, ${fmtMin(todayList.fold<int>(0, (a, p) => a + p.minutes))}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  next == null ? 'Sem próxima sessão planejada.' : 'Próxima: ${_dayLabel(next.day, now)} às ${next.start} · ${_name(d, next)}',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                if (next != null) ...[
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(onPressed: () => _startTimer(d, next), icon: const Icon(Icons.play_arrow), label: const Text('Iniciar a próxima sessão')),
                ],
                const SizedBox(height: 12),
                Semantics(
                  label: '${month ? 'Neste mês' : 'Nesta semana'}: ${prog.done} de ${prog.total} sessões concluídas',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(prog.total == 0 ? 'Nada planejado neste período.' : '${prog.done} de ${prog.total} concluídas · ${fmtMin(prog.doneMin)} de ${fmtMin(prog.plannedMin)}'),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(value: prog.total == 0 ? 0 : prog.done / prog.total, minHeight: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(onPressed: _generate, icon: const Icon(Icons.auto_awesome_outlined), label: Text(hasGenerated ? 'Gerar de novo' : (month ? 'Montar plano do mês' : 'Montar plano da semana'))),
              OutlinedButton.icon(onPressed: () => _edit(day: selDay), icon: const Icon(Icons.add), label: const Text('Nova sessão')),
            ],
          ),
        ),

        ..._comingCards(state, d, now),
        if (missed.isNotEmpty) _missedCard(state, d, now, missed),
        if (leftovers.isNotEmpty) _leftoverCard(d, leftovers),

        if (month) ..._monthView(state, d, now, from, to, inRange) else ..._weekView(state, d, now, from, inRange),

        const SizedBox(height: 12),
        const InfoNote('O plano fica guardado só neste aparelho, junto com os outros dados do Foquinho. Nada é enviado para a internet.'),
      ],
    );
  }

  Widget _missedCard(AppState state, AppData d, DateTime now, List<PlanSession> missed) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ficou para depois?', style: Theme.of(context).textTheme.titleMedium),
            Text('Acontece. Escolha o que fazer com ${missed.length == 1 ? 'esta sessão' : 'estas sessões'}.', style: TextStyle(color: cs.onSurfaceVariant)),
            for (final p in missed.take(4))
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('${_dayLabel(p.day, now)} ${p.start} · ${_name(d, p)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton(onPressed: () => _reschedule(p), child: const Text('Reagendar')),
                      TextButton(onPressed: () => state.removePlanSession(p.id), child: const Text('Remover')),
                      TextButton(onPressed: () => state.setPlanState(p.id, PlanState.naoRealizada), child: const Text('Deixar sem reposição')),
                    ],
                  ),
                ],
              ),
            if (missed.length > 4) Text('e mais ${missed.length - 4}.', style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _leftoverCard(AppData d, List<PlanLeftover> leftovers) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.info_outline, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text('Não coube tudo neste período', style: Theme.of(context).textTheme.titleMedium)),
            ]),
            const SizedBox(height: 6),
            for (final l in leftovers)
              Text(l.beforeExam
                  ? '${d.subjectName(l.subjectId)}: ${l.placed} de ${l.wanted} sessões antes da prova.'
                  : '${d.subjectName(l.subjectId)}: nenhuma sessão coube.'),
            const SizedBox(height: 8),
            Text('O que você quer priorizar?', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in leftovers)
                  FilterChip(
                    label: Text(d.subjectName(l.subjectId)),
                    selected: prioritize.contains(l.subjectId),
                    onSelected: (v) => setState(() => v ? prioritize.add(l.subjectId) : prioritize.remove(l.subjectId)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(onPressed: prioritize.isEmpty ? null : _generate, child: const Text('Gerar de novo com prioridade')),
                OutlinedButton(onPressed: _openAvailability, child: const Text('Aumentar o tempo disponível')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _weekView(AppState state, AppData d, DateTime now, DateTime from, List<PlanSession> inRange) {
    final out = <Widget>[];
    for (var i = 0; i < 7; i++) {
      final day = addDaysTo(from, i);
      final k = dayKey(day);
      final list = inRange.where((p) => p.day == k).toList();
      out.add(_dayHeader(d, now, day, list));
      out.addAll(_dayItems(state, d, now, k));
      out.addAll(list.map((p) => _sessionTile(state, d, now, p)));
    }
    return out;
  }

  Widget _dayHeader(AppData d, DateTime now, DateTime day, List<PlanSession> list) {
    final cs = Theme.of(context).colorScheme;
    final k = dayKey(day);
    final avail = dayAvailable(d.plan, day);
    final mins = list.where((p) => p.occupies).fold<int>(0, (a, p) => a + p.minutes);
    final info = list.isEmpty ? (avail ? 'livre' : (d.plan.blocked.contains(k) ? 'data sem estudo' : 'descanso')) : '${list.length} ${list.length == 1 ? 'sessão' : 'sessões'} · ${fmtMin(mins)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text('${_dayLabel(k, now)} · $info', style: TextStyle(fontWeight: FontWeight.w700, color: k == dayKey(now) ? cs.primary : cs.onSurface)),
            ),
          ),
          IconButton(
            tooltip: 'Nova sessão em ${fmtDay(k)}',
            icon: const Icon(Icons.add),
            onPressed: () => _edit(day: k),
          ),
        ],
      ),
    );
  }

  List<Widget> _monthView(AppState state, AppData d, DateTime now, DateTime from, DateTime to, List<PlanSession> inRange) {
    final cs = Theme.of(context).colorScheme;
    final count = <String, int>{};
    final doneCount = <String, int>{};
    for (final p in inRange) {
      count[p.day] = (count[p.day] ?? 0) + 1;
      if (p.state == PlanState.concluida) doneCount[p.day] = (doneCount[p.day] ?? 0) + 1;
    }
    final itemDays = boardItems(d).map((i) => i.day).toSet();
    final todayK = dayKey(now);
    final sel = selDay != null && selDay!.compareTo(dayKey(from)) >= 0 && selDay!.compareTo(dayKey(to)) <= 0
        ? selDay!
        : (todayK.compareTo(dayKey(from)) >= 0 && todayK.compareTo(dayKey(to)) <= 0 ? todayK : dayKey(from));
    final cells = <Widget>[];
    for (var i = 0; i < from.weekday - 1; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = from; !day.isAfter(to); day = addDaysTo(day, 1)) {
      final k = dayKey(day);
      final n = count[k] ?? 0;
      final dn = doneCount[k] ?? 0;
      final isSel = k == sel;
      cells.add(Semantics(
        button: true,
        selected: isSel,
        onTap: () => setState(() => selDay = k),
        label: '${fmtDay(k)}: ${n == 0 ? 'sem sessões' : '$n ${n == 1 ? 'sessão' : 'sessões'}, $dn ${dn == 1 ? 'concluída' : 'concluídas'}'}${itemDays.contains(k) ? ', tem prova ou atividade' : ''}',
        child: ExcludeSemantics(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => selDay = k),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSel ? cs.primaryContainer : null,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: k == todayK ? cs.primary : cs.outlineVariant, width: k == todayK ? 2 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${day.day}', style: TextStyle(fontWeight: FontWeight.w600, color: isSel ? cs.onPrimaryContainer : cs.onSurface)),
                  Text(
                    '${n == 0 ? (dayAvailable(d.plan, day) ? '' : '–') : (dn == n ? '$n ✓' : '$n')}${itemDays.contains(k) ? ' !' : ''}',
                    style: TextStyle(fontSize: 11, color: isSel ? cs.onPrimaryContainer : cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
    }
    final list = inRange.where((p) => p.day == sel).toList();
    return [
      Row(
        children: [
          for (final w in kWeekdayShort) Expanded(child: Center(child: Text(w, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)))),
        ],
      ),
      const SizedBox(height: 4),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.95,
        children: cells,
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('Número = sessões do dia · ✓ = todas concluídas · – = descanso · ! = prova ou atividade', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ),
      _dayHeader(d, now, parseDayKey(sel)!, list),
      ..._dayItems(state, d, now, sel),
      if (list.isEmpty) Text('Nenhuma sessão neste dia.', style: TextStyle(color: cs.onSurfaceVariant)),
      ...list.map((p) => _sessionTile(state, d, now, p)),
    ];
  }

  IconData _itemIcon(BoardKind k) => k == BoardKind.prova ? Icons.school_outlined : (k == BoardKind.trabalho ? Icons.work_outline : Icons.assignment_outlined);

  String _itemName(AppData d, BoardItem it) => '${it.kindLabel} · ${d.subjectName(it.subjectId)}${it.title.isEmpty ? '' : ': ${it.title}'}';

  Widget? _doneButton(AppState state, BoardItem it) {
    if (it.kind != BoardKind.atividade) return null;
    return IconButton(
      tooltip: 'Marcar atividade como feita',
      icon: const Icon(Icons.check_circle_outline),
      onPressed: () async {
        await state.setTaskStatus(it.id, TaskStatus.done);
        if (mounted) showSnack(context, 'Atividade concluída.');
      },
    );
  }

  /// Provas, trabalhos e atividades do dia [k], mostrados no próprio dia do mural.
  List<Widget> _dayItems(AppState state, AppData d, DateTime now, String k) {
    final cs = Theme.of(context).colorScheme;
    return [
      for (final it in boardItems(d).where((i) => i.day == k))
        Card(
          color: cs.tertiaryContainer,
          child: ListTile(
            dense: true,
            leading: Icon(_itemIcon(it.kind), color: cs.onTertiaryContainer),
            title: Text(_itemName(d, it), style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.w600)),
            subtitle: Text(it.kind == BoardKind.atividade ? 'Prazo neste dia' : 'Marcado para este dia', style: TextStyle(color: cs.onTertiaryContainer)),
            trailing: _doneButton(state, it),
          ),
        ),
    ];
  }

  /// "Chegando": o que vence nos próximos 14 dias (e atividades atrasadas) e
  /// sugestões de sessão para encaixar no mural antes da data.
  List<Widget> _comingCards(AppState state, AppData d, DateTime now) {
    final cs = Theme.of(context).colorScheme;
    final today = dayOnly(now);
    final todayK = dayKey(today);
    final limitK = dayKey(addDaysTo(today, 14));
    final items = boardItems(d).where((i) => i.day.compareTo(limitK) <= 0 && (i.day.compareTo(todayK) >= 0 || i.kind == BoardKind.atividade)).toList();
    if (items.isEmpty) return const [];
    final sugs = boardSuggestions(d, now);
    String whenOf(BoardItem it) {
      final left = dayOnly(parseDayKey(it.day)!).difference(today).inDays;
      return left < 0 ? 'atrasada, prazo ${fmtDay(it.day)}' : '${relativeDays(left)} (${_dayLabel(it.day, now).replaceAll(' · hoje', '')})';
    }

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text('Chegando', style: Theme.of(context).textTheme.titleMedium)),
              Text('Provas, trabalhos e atividades que você cadastrou.', style: TextStyle(color: cs.onSurfaceVariant)),
              for (final it in items.take(6))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_itemIcon(it.kind), color: it.day.compareTo(todayK) <= 0 ? cs.error : cs.primary),
                  title: Text(_itemName(d, it)),
                  subtitle: Text(whenOf(it)),
                  trailing: _doneButton(state, it),
                ),
              if (items.length > 6) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('e mais ${items.length - 6}.', style: TextStyle(color: cs.onSurfaceVariant))),
            ],
          ),
        ),
      ),
      if (sugs.isNotEmpty)
        Card(
          color: cs.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text('Sugestões para o mural', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSecondaryContainer))),
                for (final s in sugs) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${_itemName(d, s.item)} ${s.daysLeft < 0 ? 'está atrasada' : 'é ${relativeDays(s.daysLeft)}'}. '
                    '${s.planned == 0 ? 'Ainda não há sessão reservada.' : 'Há ${s.planned} de ${s.wanted} sessões sugeridas.'}',
                    style: TextStyle(color: cs.onSecondaryContainer),
                  ),
                  const SizedBox(height: 4),
                  if (s.slot != null)
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.add),
                      label: Text('Reservar ${s.minutes} min ${_dayLabel(s.slot!.day, now)} às ${hmFromMinutes(s.slot!.startMin)}'),
                      onPressed: () async {
                        final o = s.slot!;
                        await state.upsertPlanSession(PlanSession(
                          id: newId(),
                          subjectId: s.item.subjectId,
                          topic: s.item.title.isEmpty ? null : s.item.title,
                          day: o.day,
                          start: hmFromMinutes(o.startMin),
                          minutes: s.minutes,
                          manual: true,
                        ));
                        if (mounted) showSnack(context, 'Sessão reservada no mural.');
                      },
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: Text('Não há horário livre antes da data.', style: TextStyle(color: cs.onSecondaryContainer))),
                        TextButton(onPressed: _openAvailability, child: const Text('Ver horários')),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
    ];
  }

  Widget _sessionTile(AppState state, AppData d, DateTime now, PlanSession p) {
    final cs = Theme.of(context).colorScheme;
    final icon = switch (p.state) {
      PlanState.planejada => Icons.schedule,
      PlanState.concluida => Icons.check_circle,
      PlanState.incompleta => Icons.timelapse,
      PlanState.naoRealizada => Icons.remove_circle_outline,
    };
    final tags = <String>[
      '${p.minutes} min',
      planStateLabel(p.state),
      if (p.moved) 'reagendada',
      if (p.pinned) 'fixada',
      if (p.manual) 'manual',
    ];
    final done = p.state == PlanState.concluida;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: done ? cs.primary : cs.onSurfaceVariant),
        title: Text('${p.start} · ${d.subjectName(p.subjectId)}'),
        subtitle: Text('${p.topic == null ? '' : '${p.topic}\n'}${tags.join(' · ')}'),
        isThreeLine: p.topic != null,
        trailing: PopupMenuButton<String>(
          tooltip: 'Ações da sessão',
          onSelected: (v) async {
            switch (v) {
              case 'iniciar':
                _startTimer(d, p);
              case 'concluir':
                await state.setPlanState(p.id, PlanState.concluida, record: true);
                if (mounted) showSnack(context, 'Concluída. ${fmtMin(p.minutes)} registrados no histórico.');
              case 'incompleta':
                await state.setPlanState(p.id, PlanState.incompleta);
              case 'nao':
                await state.setPlanState(p.id, PlanState.naoRealizada);
              case 'planejada':
                await state.setPlanState(p.id, PlanState.planejada);
              case 'mover':
                await _edit(existing: p);
              case 'rapido':
                await _reschedule(p);
              case 'fixar':
                await state.togglePlanPin(p.id);
              case 'excluir':
                final ok = await confirmDialog(context, title: 'Excluir esta sessão?', text: '${_dayLabel(p.day, now)} ${p.start} · ${_name(d, p)}', yes: 'Excluir', danger: true);
                if (ok) await state.removePlanSession(p.id);
            }
          },
          itemBuilder: (_) => [
            if (!done) const PopupMenuItem(value: 'iniciar', child: Text('Iniciar com o temporizador')),
            if (!done) const PopupMenuItem(value: 'concluir', child: Text('Marcar como concluída')),
            if (p.state != PlanState.incompleta && !done) const PopupMenuItem(value: 'incompleta', child: Text('Marcar como incompleta')),
            if (p.state != PlanState.naoRealizada && !done) const PopupMenuItem(value: 'nao', child: Text('Marcar como não realizada')),
            if (p.state != PlanState.planejada && !done) const PopupMenuItem(value: 'planejada', child: Text('Voltar para planejada')),
            const PopupMenuItem(value: 'mover', child: Text('Editar ou mover')),
            if (!done) const PopupMenuItem(value: 'rapido', child: Text('Reagendar para o próximo horário livre')),
            PopupMenuItem(value: 'fixar', child: Text(p.pinned ? 'Desafixar' : 'Fixar (não muda ao gerar de novo)')),
            const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
          ],
        ),
      ),
    );
  }
}
