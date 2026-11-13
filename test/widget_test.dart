// Teste de fumaça da interface: o app abre na configuração inicial
// e, depois de concluída, mostra o painel.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foquinho/data/app_state.dart';
import 'package:foquinho/main.dart';

void main() {
  testWidgets('abre a configuração inicial e chega ao painel', (tester) async {
    String? stored;
    final state = AppState(
      read: () async => stored,
      write: (s) async {
        stored = s;
        return true;
      },
      clear: () async {
        stored = null;
        return true;
      },
    );
    await state.load();

    await tester.pumpWidget(FoquinhoApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Menos tela. Mais estudo.'), findsOneWidget);
    expect(find.text('Pular tudo'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Rafa');
    await tester.tap(find.text('Pular tudo'));
    await tester.pumpAndSettle();

    expect(find.text('Oi, Rafa'), findsOneWidget);
    expect(find.text('Estudar agora'), findsOneWidget);
    expect(find.text('Pausa ativa'), findsNothing);
    expect(find.text('Ver plano'), findsOneWidget);

    // Na primeira vez, a Foquinha aparece com o tutorial.
    expect(find.text('Oi! Eu sou a Foquinha.'), findsOneWidget);
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('2 de ${7}'), findsOneWidget);
    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();
    expect(find.text('Oi! Eu sou a Foquinha.'), findsNothing);
    expect(state.data.tourDone, isTrue);

    // Desmonta a árvore para encerrar os temporizadores da interface.
    await tester.pumpWidget(const SizedBox());
  });
}
