import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../logic/quiz_controller.dart';
import '../../../logic/quiz_scope.dart';

/// Pagina risultati della partita.
///
/// Scopo:
/// - Mostra punteggio finale.
/// - Mostra l’elenco domande con esito (corretta/errata) e dettagli espandibili.
/// - Permette di avviare una nuova partita oppure rigiocare con gli stessi parametri.
class ResultsPage extends StatelessWidget {
  /// Crea la pagina risultati.
  const ResultsPage({super.key});

  /// Costruisce la UI della pagina risultati.
  ///
  /// La pagina legge lo stato dal [QuizController] tramite [QuizScope.of(context)].
  /// Quando cambia lo stato del controller (notifyListeners), la pagina si ricostruisce.
  @override
  Widget build(BuildContext context) {
    // Recupera il controller del quiz (stato globale dell’app).
    final quiz = QuizScope.of(context);

    // Recupera lo schema colori Material 3 per colorare icone/card coerentemente.
    final cs = Theme.of(context).colorScheme;

    // Cache locale (solo leggibilità) dei valori più usati.
    final total = quiz.totalQuestions;
    final score = quiz.score;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Risultati'),
        actions: [
          // Pulsante rapido per tornare alla Home.
          IconButton(
            tooltip: 'Home',
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: SafeArea(
        // ListView permette di far scorrere tutta la pagina (header + lista + bottoni).
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // HEADER CARD (PUNTEGGIO)
            Card(
              // Elevation 0 per effetto “flat” Material 3.
              elevation: 0,
              // Colore di background leggermente diverso dal surface.
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 36,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Punteggio',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$score / $total',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // LISTA DETTAGLI DOMANDE
            // Se non ci sono domande, mostra un messaggio.
            if (quiz.questions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Nessun risultato da mostrare (nessuna domanda caricata).',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              // Genera una Card per ogni domanda, usando ExpansionTile per mostrare dettagli.
              ...List.generate(quiz.questions.length, (i) {
                // Recupera domanda e risposta utente.
                final q = quiz.questions[i];
                final user = (i < quiz.userAnswers.length) ? quiz.userAnswers[i] : null;

                // Valuta se la risposta è corretta.
                final ok = user == q.correctAnswer;

                // Sceglie icona e colore in base all’esito.
                final icon = ok ? Icons.check_circle : Icons.cancel;
                final iconColor = ok ? cs.tertiary : cs.error;

                return Card(
                  child: ExpansionTile(
                    // Leading mostra l’esito (icona + colore).
                    leading: Icon(icon, color: iconColor),

                    // Titolo compatto: Q1, Q2, ...
                    title: Text(
                      'Q${i + 1}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),

                    // Sottotitolo: stato risposta (corretta/errata/nessuna).
                    subtitle: Text(
                      user == null
                          ? 'Nessuna risposta'
                          : (ok ? 'Risposta corretta' : 'Risposta errata'),
                      style: TextStyle(color: iconColor),
                    ),

                    // Padding applicato solo ai figli espansi (dettagli).
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

                    // Children: contenuto mostrato quando la tile è espansa. 
                    children: [
                      // Testo domanda.
                      Text(
                        q.text,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),

                      // Riga: risposta utente.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 18,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'La tua risposta: ${user ?? "-"}',
                              style: TextStyle(
                                color: ok ? cs.tertiary : cs.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Riga: risposta corretta.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 18,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Corretta: ${q.correctAnswer}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 16),

            // ACTIONS (NUOVA PARTITA / RIGIOCA)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    // Nuova partita: resetta lo stato e torna alla Home.
                    onPressed: () {
                      quiz.resetToIdle();
                      context.go('/home');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Nuova partita'),
                  ), 
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    // Rigioca: avvia una partita con gli ultimi parametri salvati.
                    onPressed: () async {
                      await quiz.startNewGame(
                        amount: quiz.lastAmount,
                        category: quiz.lastCategory,
                        difficulty: quiz.lastDifficulty,
                        type: quiz.lastType,
                        useToken: quiz.lastUseToken,
                      );

                      // Se il contesto è ancora valido e lo stato è playing, naviga al quiz.
                      if (context.mounted && quiz.status == QuizStatus.playing) {
                        context.go('/quiz');
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rigioca'),
                  ), 
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
