// Disponibilidade para o planejamento: dias, horários, limite diário,
// duração das sessões, intervalo e datas bloqueadas.

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../logic/stats.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

const List<String> kWeekdayLong = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'];

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  PlanSettings? s;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Trabalha em uma cópia: só grava ao tocar em Salvar.
    s ??= PlanSettings.fromJson(AppScope.of(context).data.plan.toJson());
  }

  @override
  Widget build(BuildContext context) {
    final st = s!;
    final cs = Theme.of(context).colorScheme;
    final anyDay = st.days.any((d) => d.on && d.minutes > 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Quando posso estudar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('O plano só usa os dias e horários marcados aqui. Dias desligados ficam como descanso.', style: TextStyle(color: cs.onSurfaceVariant)),
          const SectionTitle('Dias e horários'),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < 7; i++) ...[
                  SwitchListTile(
                    title: Text(kWeekdayLong[i]),
                    subtitle: Text(st.days[i].on ? (st.days[i].minutes > 0 ? 'Das ${st.days[i].from} às ${st.days[i].to}' : 'O horário final precisa ser depois do inicial') : 'Descanso'),
                    value: st.days[i].on,
                    onChanged: (v) => setState(() => st.days[i].on = v),
                  ),
                  if (st.days[i].on)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          const Text('Das'),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () async {
                              final v = await pickHm(context, st.days[i].from);
                              if (v != null) setState(() => st.days[i].from = v);
                            },
                            child: Text(st.days[i].from),
                          ),
                          const SizedBox(width: 8),
                          const Text('às'),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () async {
                              final v = await pickHm(context, st.days[i].to);
                              if (v != null) setState(() => st.days[i].to = v);
                            },
                            child: Text(st.days[i].to),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SectionTitle('Quanto estudar'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _step('Limite por dia', fmtMin(st.dailyMaxMin), () => setState(() => st.dailyMaxMin = (st.dailyMaxMin - 15).clamp(15, 480).toInt()), () => setState(() => st.dailyMaxMin = (st.dailyMaxMin + 15).clamp(15, 480).toInt())),
                  const SizedBox(height: 4),
                  const Text('Duração de cada sessão'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in const [25, 40, 50])
                        ChoiceChip(label: Text('$m min'), selected: st.sessionMin == m, onSelected: (_) => setState(() => st.sessionMin = m)),
                    ],
                  ),
                  _step('Intervalo entre sessões', '${st.gapMin} min', () => setState(() => st.gapMin = (st.gapMin - 5).clamp(0, 30).toInt()), () => setState(() => st.gapMin = (st.gapMin + 5).clamp(0, 30).toInt())),
                  Text('O plano ocupa no máximo 80% do tempo livre de cada dia, para sobrar espaço para imprevistos.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SectionTitle('Datas sem estudo'),
          Card(
            child: Column(
              children: [
                if (st.blocked.isEmpty)
                  const ListTile(title: Text('Nenhuma data bloqueada'), subtitle: Text('Use para feriados, viagens ou dias de descanso.')),
                for (final k in (st.blocked.toList()..sort()))
                  ListTile(
                    leading: const Icon(Icons.event_busy_outlined),
                    title: Text(fmtDate(parseDayKey(k)!)),
                    trailing: IconButton(
                      tooltip: 'Liberar esta data',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => st.blocked.remove(k)),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final v = await pickDay(context, null);
                        if (v != null && !st.blocked.contains(v)) setState(() => st.blocked.add(v));
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Bloquear uma data'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!anyDay) const InfoNote('Marque pelo menos um dia com horário válido para o plano poder ser montado.'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: !anyDay
                ? null
                : () async {
                    final nav = Navigator.of(context);
                    st.configured = true;
                    await AppScope.of(context).savePlanSettings(st);
                    nav.pop(true);
                  },
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Widget _step(String label, String value, VoidCallback minus, VoidCallback plus) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(onPressed: minus, icon: const Icon(Icons.remove_circle_outline), tooltip: 'Diminuir: $label'),
        SizedBox(width: 64, child: Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
        IconButton(onPressed: plus, icon: const Icon(Icons.add_circle_outline), tooltip: 'Aumentar: $label'),
      ],
    );
  }
}
