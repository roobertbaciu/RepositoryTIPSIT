import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/stats_screen.dart';
import 'screens/timer_screen.dart';
import 'state/app_state.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..load(),
      child: const FlowFocusApp(),
    ),
  );
}

class FlowFocusApp extends StatelessWidget {
  const FlowFocusApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1E847F);

    return MaterialApp(
      title: 'FlowFocus - Tilt & Swipe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF6FAFB),
        textTheme: Theme.of(context).textTheme.copyWith(
              displayMedium: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.7,
              ),
              headlineMedium: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              titleLarge: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
              bodyLarge: const TextStyle(
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
      ),
      home: const _RootShell(),
    );
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          TimerScreen(),
          StatsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Timer',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}
