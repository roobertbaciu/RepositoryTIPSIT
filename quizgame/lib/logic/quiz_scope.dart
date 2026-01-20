import 'package:flutter/widgets.dart';

import 'quiz_controller.dart';

/// Espone un [QuizController] a tutte le pagine sotto questo widget.
///
/// La classe estende [InheritedNotifier] in modo che:
/// - Il controller (che estende ChangeNotifier/Listenable) venga ascoltato. 
/// - Ogni volta che il controller chiama `notifyListeners()`, i widget che hanno
///   richiesto il controller con `QuizScope.of(context)` vengano ricostruiti. 
class QuizScope extends InheritedNotifier<QuizController> {
  /// Crea lo scope e registra [controller] come `notifier`.
  ///
  /// Il parametro [child] è tutto l’albero widget che deve avere accesso
  /// al controller (tipicamente tutta l’app).
  const QuizScope({
    super.key,
    required QuizController controller,
    required Widget child,
  }) : super(
          // Imposta il notifier osservato dall'InheritedNotifier.
          notifier: controller,
          // Imposta il sotto-albero che potrà usare QuizScope.of(context).
          child: child,
        );

  /// Recupera il [QuizController] dal contesto.
  ///
  /// Comportamento:
  /// - Cerca il `QuizScope` più vicino nell’albero.
  /// - Registra una dipendenza tramite `dependOnInheritedWidgetOfExactType`,
  ///   così il widget chiamante verrà ricostruito quando il notifier cambia. 
  static QuizController of(BuildContext context) {
    // Cerca nell’albero il QuizScope più vicino e crea una dipendenza. 
    final scope = context.dependOnInheritedWidgetOfExactType<QuizScope>();

    // In debug, segnala un errore se QuizScope non è presente sopra questo widget.
    assert(scope != null, 'QuizScope non trovato sopra questo widget');

    // Ritorna il controller (notifier) associato allo scope.
    return scope!.notifier!;
  }
}
