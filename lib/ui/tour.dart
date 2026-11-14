// Tutorial da Foquinha: na primeira vez que a pessoa abre o app, a mascote
// passa por cada aba e explica, em uma frase, para que ela serve.

import 'package:flutter/material.dart';

import 'widgets/foquinha.dart';

class TourStep {
  final int tab; // aba que fica aberta durante o passo
  final bool pointTab; // destaca o botão da aba na barra de baixo
  final FoquinhaPose pose;
  final String title;
  final String text;
  const TourStep(this.tab, this.pose, this.title, this.text, {this.pointTab = false});
}

const kTourSteps = <TourStep>[
  TourStep(0, FoquinhaPose.acenando, 'Oi! Eu sou a Foquinha.',
      'Vou te mostrar o Foquinho rapidinho. A ideia é te ajudar a estudar com constância, no seu ritmo e sem pressão.'),
  TourStep(0, FoquinhaPose.apontando, 'Início',
      'Aqui ficam a sua sequência de dias, o tempo de hoje e uma sugestão do que fazer agora. Tocou em Começar, o temporizador abre.',
      pointTab: true),
  TourStep(0, FoquinhaPose.feliz, 'Temporizador',
      'Você escolhe os minutos e foca. Quando o tempo acaba, eu toco o alarme e guardo tudo no histórico.'),
  TourStep(1, FoquinhaPose.apontando, 'Plano',
      'Cadastre suas matérias (marque as difíceis), tarefas e provas. No Mural eu monto o seu plano da semana e do mês nos horários que você tem livres.',
      pointTab: true),
  TourStep(2, FoquinhaPose.apontando, 'Histórico',
      'Quanto você estudou em cada dia da semana. Sem ranking: o que conta é o seu ritmo.',
      pointTab: true),
  TourStep(3, FoquinhaPose.apontando, 'Ajustes',
      'Aqui você liga os avisos ao longo do dia e o alarme. Se quiser me ver de novo, toque em "Rever o tutorial da Foquinha".',
      pointTab: true),
  TourStep(0, FoquinhaPose.comemorando, 'Pronto!',
      'Que tal começar com 10 minutos agora? Eu fico torcendo por você.'),
];

class FoquinhaTour extends StatefulWidget {
  final GlobalKey navKey; // barra de abas, para saber onde destacar
  final int tabCount;
  final ValueChanged<int> onTab;
  final VoidCallback onDone;
  const FoquinhaTour({super.key, required this.navKey, required this.tabCount, required this.onTab, required this.onDone});

  @override
  State<FoquinhaTour> createState() => _FoquinhaTourState();
}

class _FoquinhaTourState extends State<FoquinhaTour> {
  int step = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onTab(kTourSteps[0].tab);
    });
  }

  void _go(int i) {
    if (i >= kTourSteps.length) {
      widget.onDone();
      return;
    }
    setState(() => step = i);
    widget.onTab(kTourSteps[i].tab);
  }

  Rect? _tabRect() {
    final s = kTourSteps[step];
    if (!s.pointTab) return null;
    final box = widget.navKey.currentContext?.findRenderObject();
    final me = context.findRenderObject();
    if (box is! RenderBox || me is! RenderBox || !box.hasSize) return null;
    final origin = me.globalToLocal(box.localToGlobal(Offset.zero));
    final w = box.size.width / widget.tabCount;
    return Rect.fromLTWH(origin.dx + w * s.tab + 4, origin.dy + 4, w - 8, box.size.height - 8);
  }

  double _navHeight() {
    final box = widget.navKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size.height : 80;
  }

  @override
  Widget build(BuildContext context) {
    final s = kTourSteps[step];
    final last = step == kTourSteps.length - 1;
    final hole = _tabRect();
    final bottom = _navHeight() + 12;
    return Stack(
      children: [
        // Fundo escurecido; toques nele não fazem nada (o tutorial usa os botões do balão).
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: CustomPaint(painter: _DimPainter(hole: hole, ring: Theme.of(context).colorScheme.primaryContainer)),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: bottom,
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: FoquinhaBubble(
                key: ValueKey(step),
                pose: s.pose,
                title: s.title,
                text: s.text,
                counter: '${step + 1} de ${kTourSteps.length}',
                actions: [
                  if (!last) TextButton(onPressed: widget.onDone, child: const Text('Pular')),
                  if (step > 0 && !last) TextButton(onPressed: () => _go(step - 1), child: const Text('Voltar')),
                  FilledButton(onPressed: () => _go(step + 1), child: Text(last ? 'Começar' : 'Próximo')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DimPainter extends CustomPainter {
  final Rect? hole;
  final Color ring;
  _DimPainter({required this.hole, required this.ring});

  @override
  void paint(Canvas canvas, Size size) {
    final all = Path()..addRect(Offset.zero & size);
    final paint = Paint()..color = const Color(0x8C000000);
    if (hole == null) {
      canvas.drawPath(all, paint);
      return;
    }
    final r = RRect.fromRectAndRadius(hole!, const Radius.circular(18));
    canvas.drawPath(Path.combine(PathOperation.difference, all, Path()..addRRect(r)), paint);
    canvas.drawRRect(r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = ring);
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.hole != hole || old.ring != ring;
}
