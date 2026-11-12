// A Foquinha, mascote do app, e o balão de fala dela.

import 'package:flutter/material.dart';

enum FoquinhaPose { feliz, acenando, apontando, comemorando, pensando }

class Foquinha extends StatelessWidget {
  final FoquinhaPose pose;
  final double size;
  const Foquinha({super.key, this.pose = FoquinhaPose.feliz, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/foquinha/${pose.name}.png',
      width: size,
      height: size,
      excludeFromSemantics: true,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
    );
  }
}

/// Balão com a Foquinha ao lado: título, texto e botões.
class FoquinhaBubble extends StatelessWidget {
  final FoquinhaPose pose;
  final String title;
  final String text;
  final String? counter;
  final List<Widget> actions;
  const FoquinhaBubble({super.key, required this.pose, required this.title, required this.text, this.counter, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Foquinha(pose: pose, size: 104),
        ),
        Material(
          color: cs.surface,
          elevation: 6,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cs.primary, width: 2),
            ),
            child: Semantics(
              liveRegion: true,
              container: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: cs.primary))),
                      if (counter != null) Text(counter!, style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(text, style: tt.bodyLarge),
                  const SizedBox(height: 4),
                  Wrap(alignment: WrapAlignment.end, spacing: 4, runSpacing: 4, children: actions),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
