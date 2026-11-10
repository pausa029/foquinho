import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_state.dart';
import 'models/models.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/move_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/plan_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  state.load();
  runApp(TelaTchauApp(state: state));
}

class TelaTchauApp extends StatelessWidget {
  final AppState state;
  const TelaTchauApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final mode = switch (state.data.theme) {
            ThemeChoice.sistema => ThemeMode.system,
            ThemeChoice.claro => ThemeMode.light,
            ThemeChoice.escuro => ThemeMode.dark,
          };
          return MaterialApp(
            title: 'TelaTchau',
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const RootScreen(),
          );
        },
      ),
    );
  }
}

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0F6E56), brightness: b);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    visualDensity: VisualDensity.standard,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48), textStyle: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 40)),
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  );
}

/// Decide entre carregamento, configuração inicial e o app principal.
class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.status == LoadStatus.carregando) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(semanticsLabel: 'Carregando'),
              SizedBox(height: 16),
              Text('Abrindo o TelaTchau…'),
            ],
          ),
        ),
      );
    }
    if (!state.data.onboarded) return const OnboardingScreen();
    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final pages = [
      HomeScreen(onGoTo: (i) => setState(() => index = i)),
      const PlanScreen(),
      const MoveScreen(),
      const HistoryScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: Column(
        children: [
          if (state.status == LoadStatus.erroLeitura || state.status == LoadStatus.erroEscrita)
            StatusBanner(text: state.lastError ?? 'Problema ao acessar os dados.'),
          Expanded(child: IndexedStack(index: index, children: pages)),
          const ActiveSessionBar(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Plano'),
          NavigationDestination(icon: Icon(Icons.directions_run_outlined), selectedIcon: Icon(Icons.directions_run), label: 'Movimento'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Histórico'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}
