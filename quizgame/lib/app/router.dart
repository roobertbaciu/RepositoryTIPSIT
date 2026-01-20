import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../logic/quiz_controller.dart';
import '../logic/quiz_scope.dart';

import '../ui/pages/home_page.dart';
import '../ui/pages/quiz_page.dart';
import '../ui/pages/results_page.dart';

/// Chiave del Navigator “root” (sopra a tutti i branch).
///
/// Serve quando si vuole avere un controllo esplicito sul navigator principale.
final _rootKey = GlobalKey<NavigatorState>();

/// Chiave del Navigator del branch Home (tab 0).
final _homeKey = GlobalKey<NavigatorState>();

/// Chiave del Navigator del branch Quiz (tab 1).
final _quizKey = GlobalKey<NavigatorState>();

/// Chiave del Navigator del branch Risultati (tab 2).
final _resultsKey = GlobalKey<NavigatorState>();

/// Crea e restituisce la configurazione di routing dell’app.
///
/// La configurazione usa:
/// - `StatefulShellRoute.indexedStack` per avere 3 tab con navigator separati
///   e stato preservato (ogni tab mantiene il suo stack). 
/// - `NavigationBar` come UI della tab bar (Material 3). 
GoRouter buildRouter() {
  return GoRouter(
    // Imposta il navigator root del router.
    navigatorKey: _rootKey,

    // Imposta la rotta iniziale dell’app.
    initialLocation: '/home',

    routes: [
      /// Crea una shell “a tab” con branch stateful.
      ///
      /// `indexedStack` ogni tab resta in memoria e conserva lo stato
      /// (utile quando si torna su Home e poi su Quiz, senza ricreare tutto). 
      StatefulShellRoute.indexedStack(
        /// Costruisce la UI “contenitore” (Scaffold) che ospita:
        /// - il contenuto della tab corrente (navShell)
        /// - la NavigationBar in basso
        ///
        /// Il parametro `navShell` (StatefulNavigationShell) permette di:
        /// - leggere l’indice della tab corrente (currentIndex)
        /// - cambiare tab in modo stateful con goBranch(). 
        builder: (context, state, navShell) {
          return Scaffold(
            // Mostra la pagina del branch corrente.
            // `navShell` è un widget che gestisce gli stack per ciascun branch.
            body: navShell,

            // Barra di navigazione a tab in basso.
            bottomNavigationBar: NavigationBar(
              // Determina quale tab è evidenziata.
              selectedIndex: navShell.currentIndex, 

              // Viene chiamato quando l’utente seleziona una destinazione.
              onDestinationSelected: (index) {
                // Recupera lo stato del quiz dal contesto (QuizScope è sopra MaterialApp).
                final quiz = QuizScope.of(context);

                // Se viene selezionata la tab 1 (Quiz) senza partita attiva,
                // mostra un messaggio e riporta su Home.
                if (index == 1 && quiz.status != QuizStatus.playing) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nessuna partita attiva. Avvia il quiz dalla Home.'),
                    ),
                  ); 

                  // Torna a Home in modo esplicito.
                  navShell.goBranch(0, initialLocation: true);
                  return;
                }

                // Se viene selezionata la tab 2 (Risultati) ma la partita non è finita,
                // blocca l’accesso e informa l’utente.
                if (index == 2 && quiz.status != QuizStatus.finished) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Risultati disponibili a fine partita.'),
                    ),
                  ); 
                  return;
                }

                // Cambia branch (tab) preservando lo stack del branch selezionato.
                // `initialLocation: true` forza il ritorno alla root di quel branch
                // quando si seleziona la tab già attiva (comportamento “classico”).
                navShell.goBranch(
                  index,
                  initialLocation: index == navShell.currentIndex,
                ); // goBranch per switch stateful 
              },

              // Definisce le destinazioni (tab) mostrate nella NavigationBar.
              destinations: const [
                NavigationDestination(icon: Icon(Icons.tune), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.quiz), label: 'Quiz'),
                NavigationDestination(icon: Icon(Icons.emoji_events), label: 'Esiti'),
              ], // destinazioni NavigationBar 
            ),
          );
        },

        /// Definisce i branch (uno per tab), ognuno con un proprio Navigator.
        branches: [
          StatefulShellBranch(
            // Imposta la chiave del navigator di questo branch.
            navigatorKey: _homeKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _quizKey,
            routes: [
              GoRoute(
                path: '/quiz',
                builder: (_, __) => const QuizPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _resultsKey,
            routes: [
              GoRoute(
                path: '/results',
                builder: (_, __) => const ResultsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
