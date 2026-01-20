import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../logic/quiz_controller.dart';
import '../../logic/quiz_scope.dart';

/// Pagina principale di gioco.
///
/// Scopo:
/// - Mostra la domanda corrente e le possibili risposte.
/// - Gestisce feedback grafico (corretto/errato) quando una risposta è selezionata.
/// - Permette di avanzare alla domanda successiva.
/// - Reindirizza ai risultati quando la partita termina.
class QuizPage extends StatelessWidget {
  /// Crea la pagina Quiz.
  const QuizPage({super.key});

  /// Costruisce la UI della pagina Quiz.
  ///
  /// La UI legge lo stato dal [QuizController] tramite [QuizScope.of(context)].
  /// Quando il controller chiama `notifyListeners()`, questa pagina si ricostruisce
  /// automaticamente perché dipende da QuizScope.
  @override
  Widget build(BuildContext context) {
    // Recupera il controller globale del quiz.
    final quiz = QuizScope.of(context);

    // Recupera la domanda corrente (può essere null se non ci sono domande).
    final q = quiz.currentQuestion;

    // Calcola il progresso (0..1) per una LinearProgressIndicator determinata.
    final progress = (quiz.totalQuestions == 0)
        ? 0.0
        : (quiz.currentIndex + 1) / quiz.totalQuestions;

    /// Determina il colore di sfondo di un’opzione.
    ///
    /// Logica:
    /// - Se non è locked, lascia null (usa i colori di default del tema).
    /// - Se è locked:
    ///   - evidenzia la corretta
    ///   - evidenzia l’errata selezionata
    Color? optionBgColor({
      required bool locked,
      required bool isSelected,
      required bool isCorrect,
      required ColorScheme cs,
    }) {
      if (!locked) return null;

      // Evidenzia la risposta corretta.
      if (isCorrect) return cs.tertiaryContainer;

      // Evidenzia in rosso solo l’opzione errata che l’utente ha selezionato.
      if (isSelected && !isCorrect) return cs.errorContainer;

      return null;
    }

    /// Determina il colore del bordo di un’opzione.
    ///
    /// Logica:
    /// - Se non è locked:
    ///   - opzione selezionata -> primary
    ///   - altrimenti -> outlineVariant
    /// - Se è locked:
    ///   - corretta -> tertiary
    ///   - errata selezionata -> error
    ///   - altre -> outlineVariant
    Color optionBorderColor({
      required bool locked,
      required bool isSelected,
      required bool isCorrect,
      required ColorScheme cs,
    }) {
      if (!locked) {
        return isSelected ? cs.primary : cs.outlineVariant;
      }
      if (isCorrect) return cs.tertiary;
      if (isSelected && !isCorrect) return cs.error;
      return cs.outlineVariant;
    }

    /// Determina l’icona da mostrare vicino all’opzione.
    ///
    /// Logica:
    /// - Prima della risposta: “radio on/off”
    /// - Dopo la risposta:
    ///   - corretta -> check
    ///   - errata selezionata -> cancel
    ///   - altre -> nessuna icona (null)
    IconData? optionIcon({
      required bool locked,
      required bool isSelected,
      required bool isCorrect,
    }) {
      if (!locked) {
        if (isSelected) return Icons.radio_button_checked;
        return Icons.radio_button_off;
      }
      if (isCorrect) return Icons.check_circle;
      if (isSelected && !isCorrect) return Icons.cancel;
      return null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        actions: [
          // Pulsante per tornare alla Home.
          IconButton(
            tooltip: 'Torna a Home',
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),

          // Builder usato per avere un contesto locale per mostrare widget diversi
          // in base allo stato (idle/loading/error/finished/playing).
          child: Builder(
            builder: (context) {
              // Recupera color scheme (Material 3) per colori coerenti.
              final cs = Theme.of(context).colorScheme;

              // Stato: nessuna partita attiva.
              if (quiz.status == QuizStatus.idle) {
                return Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 48,
                            color: cs.primary,
                          ),
                          const SizedBox(height: 12),
                          const Text('Nessuna partita attiva.'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => context.go('/home'),
                            icon: const Icon(Icons.tune),
                            label: const Text('Vai al setup'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Stato: caricamento domande/token.
              if (quiz.status == QuizStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }

              // Stato: errore.
              if (quiz.status == QuizStatus.error) {
                return Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.error_outline, color: cs.error),
                              const SizedBox(width: 8),
                              Text(
                                'Errore',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(quiz.errorMessage ?? 'Errore sconosciuto'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => context.go('/home'),
                            child: const Text('Torna a Home'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Stato: partita terminata.
              if (quiz.status == QuizStatus.finished) {
                return Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events_outlined,
                            size: 48,
                            color: cs.primary,
                          ),
                          const SizedBox(height: 12),
                          const Text('Partita terminata.'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => context.go('/results'),
                            icon: const Icon(Icons.bar_chart),
                            label: const Text('Vai ai risultati'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Se si è in playing ma la domanda corrente è null, mostra messaggio.
              if (q == null) {
                return const Center(child: Text('Nessuna domanda disponibile.'));
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BARRA DI AVANZAMENTO + INDICATORE TESTUALE
                  Row(
                    children: [
                      Expanded(
                        // Determinate progress (value tra 0.0 e 1.0). 
                        child: LinearProgressIndicator(value: progress),
                      ),
                      const SizedBox(width: 12),
                      Text('${quiz.currentIndex + 1}/${quiz.totalQuestions}'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // CARD DOMANDA
                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                avatar: const Icon(Icons.category_outlined, size: 18),
                                label: Text(q.category),
                              ),
                              Chip(
                                avatar: const Icon(Icons.speed, size: 18),
                                label: Text(q.difficulty),
                              ),
                              Chip(
                                avatar: const Icon(Icons.tune, size: 18),
                                label: Text(q.type),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Testo domanda.
                          Text(
                            q.text,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Expanded per far scorrere la lista risposte quando lo schermo è piccolo.
                  Expanded(
                    child: ListView.separated(
                      // Numero opzioni.
                      itemCount: q.options.length,

                      // Separatore tra un’opzione e l’altra.
                      separatorBuilder: (_, __) => const SizedBox(height: 10),

                      // Builder di ogni riga opzione.
                      itemBuilder: (context, i) {
                        final opt = q.options[i];

                        // Stato corrente: domanda bloccata? opzione selezionata? corretta?
                        final locked = quiz.isAnswerLocked;
                        final isSelected = quiz.selectedAnswer == opt;
                        final isCorrect = opt == q.correctAnswer;

                        // Colori e icone calcolati dalle funzioni helper.
                        final bg = optionBgColor(
                          locked: locked,
                          isSelected: isSelected,
                          isCorrect: isCorrect,
                          cs: cs,
                        );

                        final border = optionBorderColor(
                          locked: locked,
                          isSelected: isSelected,
                          isCorrect: isCorrect,
                          cs: cs,
                        );

                        final icon = optionIcon(
                          locked: locked,
                          isSelected: isSelected,
                          isCorrect: isCorrect,
                        );

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: locked ? null : () => quiz.answer(opt),
                          child: Ink(
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: border),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    icon ?? Icons.circle_outlined,
                                    size: 22,
                                    color: border,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      opt,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // BARRA AZIONI (AVANTI / VEDI RISULTATI)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          // Abilita il pulsante solo se l’utente ha risposto.
                          onPressed: quiz.isAnswerLocked
                              ? () {
                                  // Calcola se la domanda corrente è l’ultima.
                                  final wasLast =
                                      quiz.currentIndex >= quiz.totalQuestions - 1;

                                  // Passa alla prossima domanda o termina partita.
                                  quiz.next();

                                  // Se era l’ultima, naviga ai risultati.
                                  if (wasLast && context.mounted) {
                                    context.go('/results');
                                  }
                                }
                              : null,
                          child: Text(
                            quiz.currentIndex >= quiz.totalQuestions - 1
                                ? 'Vedi risultati'
                                : 'Avanti',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
