// Widgets reutilizados em várias telas.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../logic/stats.dart';
import '../../models/models.dart';
import '../screens/session_screen.dart';

class StatusBanner extends StatelessWidget {
  final String text;
  const StatusBanner({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: cs.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: TextStyle(color: cs.onErrorContainer))),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.text, this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 40, color: cs.primary),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            if (text != null) ...[
              const SizedBox(height: 6),
              Text(text!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            ],
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

/// Aviso curto dentro de um cartão, com ícone e texto (não depende só de cor).
class InfoNote extends StatelessWidget {
  final String text;
  final IconData icon;
  const InfoNote(this.text, {super.key, this.icon = Icons.info_outline});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: cs.onSurfaceVariant))),
        ],
      ),
    );
  }
}

/// Barra de progresso com texto: nunca depende só da cor.
class GoalProgress extends StatelessWidget {
  final String label;
  final int done;
  final int goal;
  final Color color;
  const GoalProgress({super.key, required this.label, required this.done, required this.goal, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = goal <= 0 ? 0.0 : (done / goal).clamp(0.0, 1.0).toDouble();
    final reached = goal > 0 && done >= goal;
    final text = '$label: ${fmtMin(done)} de ${fmtMin(goal)}${reached ? ' — meta alcançada' : ''}';
    return Semantics(
      label: text,
      value: '${(pct * 100).round()}%',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(text)),
                if (reached) Icon(Icons.check_circle, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: pct, minHeight: 10, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faixa fixa que mostra a sessão em andamento e abre o temporizador.
class ActiveSessionBar extends StatefulWidget {
  const ActiveSessionBar({super.key});

  @override
  State<ActiveSessionBar> createState() => _ActiveSessionBarState();
}

class _ActiveSessionBarState extends State<ActiveSessionBar> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final st = AppScope.of(context);
      st.syncSession();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final a = state.active;
    if (a == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final isStudy = a.kind == SessionKind.estudo;
    final label = state.finished
        ? 'Tempo concluído — toque para registrar'
        : '${isStudy ? 'Estudo' : 'Exercício'}${a.cycles > 1 ? ' · ${a.phase == Phase.foco ? 'foco' : 'intervalo'} ${a.cycleIndex}/${a.cycles}' : ''}${a.paused ? ' · pausado' : ''}';
    return Material(
      color: isStudy ? cs.primaryContainer : cs.tertiaryContainer,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SessionScreen())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(isStudy ? Icons.menu_book : Icons.directions_run),
              const SizedBox(width: 10),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
              if (!state.finished)
                Text(fmtClock(state.remainingMs()), style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pergunta de confirmação. Devolve true se a pessoa confirmou.
Future<bool> confirmDialog(BuildContext context, {required String title, required String text, String yes = 'Confirmar', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error, foregroundColor: Theme.of(ctx).colorScheme.onError) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(yes),
        ),
      ],
    ),
  );
  return r == true;
}

/// Seletor de horário que devolve "HH:mm" (ou null se cancelado).
Future<String?> pickHm(BuildContext context, String current) async {
  final cur = validHm(current) ?? '08:00';
  final m = hmToMinutes(cur);
  final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60));
  if (t == null) return null;
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Seletor de data que devolve "AAAA-MM-DD" (ou null se cancelado).
Future<String?> pickDay(BuildContext context, String? current) async {
  final now = DateTime.now();
  final init = parseDayKey(current) ?? now;
  final d = await showDatePicker(
    context: context,
    initialDate: init.isBefore(now) ? now : init,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 3),
  );
  if (d == null) return null;
  return dayKey(d);
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Campo de texto simples em diálogo. Devolve o texto ou null.
Future<String?> promptText(BuildContext context, {required String title, String initial = '', String hint = '', int maxLength = 60}) async {
  final ctrl = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: maxLength,
        decoration: InputDecoration(hintText: hint),
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Salvar')),
      ],
    ),
  );
  final v = r?.trim();
  return (v == null || v.isEmpty) ? null : v;
}
