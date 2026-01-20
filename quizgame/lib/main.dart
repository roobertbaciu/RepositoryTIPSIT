import 'package:flutter/material.dart';

import 'app/router.dart';
import 'data/opentdb_api.dart';
import 'logic/quiz_controller.dart';
import 'logic/quiz_scope.dart';

/// Entry point dell'app.
///
/// `runApp` prende un Widget e lo rende la radice dell'albero dei widget.
void main() {
  runApp(const AppRoot());
}

/// Widget radice dell'app.
///
/// È `StatefulWidget` perché crea e mantiene per tutta la vita dell'app:
/// - un client API (OpenTdbApi)
/// - un controller di stato (QuizController)
/// - il router (GoRouter)
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  /// Crea lo State associato ad AppRoot.
  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  /// Client che parla con OpenTriviaDB.
  /// `late final` = inizializzato una sola volta in initState.
  late final OpenTdbApi api;

  /// Controller con tutta la logica/stato del quiz (domande, punteggio, ecc.).
  late final QuizController quiz;

  /// Router dell'app (tab + rotte).
  /// Costruito una sola volta e riutilizzato.
  late final router = buildRouter();

  /// Viene chiamato una volta quando lo State entra nell'albero.
  @override
  void initState() {
    super.initState();

    // Crea il client API (usa internamente un http.Client).
    api = OpenTdbApi();

    // Crea il controller e gli passa l'API.
    // Il controller verrà poi esposto a tutta la UI tramite QuizScope.
    quiz = QuizController(api: api);
  }

  /// Viene chiamato quando lo State sta per essere rimosso definitivamente.
  ///
  /// Qui si liberano risorse (close/dispose) per evitare leak.
  @override
  void dispose() {
    // Chiude il client HTTP interno a OpenTdbApi.
    api.dispose();

    // Sempre chiamare super.dispose() alla fine.
    super.dispose();
  }

  /// Costruisce l'albero widget.
  ///
  /// - QuizScope rende disponibile `quiz` a tutte le pagine (Home/Quiz/Risultati).
  /// - MaterialApp.router usa la configurazione router (GoRouter).
  @override
  Widget build(BuildContext context) {
    return QuizScope(
      controller: quiz, // "iniezione" del controller a tutta l'app
      child: MaterialApp.router(
        // Disattiva il banner "DEBUG" in alto a destra.
        debugShowCheckedModeBanner: false,

        // Configurazione del router (rotte + shell a tab).
        routerConfig: router,

        // Tema Material 3 base (lo stai già usando nelle UI).
        theme: ThemeData(useMaterial3: true),
      ),
    );
  }
}
