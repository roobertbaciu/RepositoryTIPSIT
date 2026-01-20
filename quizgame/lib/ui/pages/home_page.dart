import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../logic/quiz_controller.dart';
import '../../../logic/quiz_scope.dart';
import '../../data/opentdb_models.dart';

/// Pagina Home/Setup del quiz.
///
/// Scopo:
/// - Permette di scegliere i parametri (numero domande, categoria, difficoltà, tipo, token).
/// - Avvia una nuova partita tramite [QuizController.startNewGame].
/// - Naviga alla pagina Quiz se il caricamento va a buon fine.
class HomePage extends StatefulWidget {
  /// Crea la pagina Home.
  const HomePage({super.key});

  /// Crea lo State associato.
  @override
  State<HomePage> createState() => _HomePageState();
}

/// State della Home.
///
/// Qui vengono gestiti:
/// - controller del campo numero domande
/// - stato UI dei dropdown/switch
/// - validazione form
class _HomePageState extends State<HomePage> {
  /// Controller del TextField del numero domande.
  ///
  /// Viene creato una volta e poi rilasciato in dispose().
  final _amountCtrl = TextEditingController(text: '10');

  /// Chiave della form per eseguire validate() su tutti i campi.
  final _formKey = GlobalKey<FormState>();

  /// Difficoltà selezionata (null = qualsiasi).
  String? _difficulty;

  /// Tipo selezionato (multiple/boolean).
  String _type = 'multiple';

  /// Abilita token (evita ripetizioni).
  bool _useToken = true;

  /// Categoria selezionata (null = qualsiasi).
  int? _categoryId;

  /// Inizializza lo state.
  ///
  /// Dopo il primo frame, avvia il caricamento delle categorie.
  /// L’uso di `addPostFrameCallback` evita di eseguire logica “dipendente dal context”
  /// durante il build iniziale. 
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Recupera il controller globale (esposto da QuizScope).
      final quiz = QuizScope.of(context);

      // Carica le categorie (se non già in cache nel controller).
      quiz.loadCategories();
    });
  }

  /// Rilascia risorse allocate dallo State.
  ///
  /// Qui viene chiuso il TextEditingController per evitare leak e warning.
  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  /// Crea una InputDecoration coerente per i campi del form.
  ///
  /// Parametri:
  /// - [label]: testo label (sempre visibile quando il campo è compilato)
  /// - [hint]: placeholder (opzionale)
  /// - [icon]: icona a sinistra (opzionale)
  InputDecoration _dec(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  /// Costruisce la UI della Home.
  ///
  /// Legge lo stato del quiz dal controller tramite QuizScope, quindi la pagina
  /// si aggiorna automaticamente quando cambia:
  /// - loading
  /// - lista categorie
  /// - status gioco
  @override
  Widget build(BuildContext context) {
    final quiz = QuizScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Setup'),
      ),
      body: SafeArea(
        // Form permette la validazione centralizzata (validate()) tramite _formKey. 
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // HEADER (card introduttiva)
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.quiz,
                        size: 34,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Imposta la partita',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Scegli categoria, difficoltà e tipo di domande.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // CARD PARAMETRI
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Numero domande (validato)
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _dec(
                          'Numero domande',
                          hint: 'es. 10',
                          icon: Icons.format_list_numbered,
                        ),
                        validator: (v) {
                          // Valida l’input: deve essere un intero positivo.
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null) return 'Inserisci un numero valido';
                          if (n <= 0) return 'Deve essere maggiore di 0';
                          if (n > 50) return 'Consigliato max 50';
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Categoria: se in caricamento mostra una progress bar,
                      // altrimenti mostra il dropdown con “Qualsiasi” + lista categorie.
                      if (quiz.categoriesLoading)
                        const LinearProgressIndicator()
                      else
                        DropdownButtonFormField<int?>(
                          value: _categoryId,
                          isExpanded: true,
                          decoration: _dec(
                            'Categoria',
                            hint: 'Qualsiasi',
                            icon: Icons.category,
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Qualsiasi'),
                            ),
                            ...quiz.categories.map((TriviaCategory c) {
                              return DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(c.name),
                              );
                            }),
                          ],
                          onChanged: (v) => setState(() => _categoryId = v),
                        ),

                      const SizedBox(height: 16),

                      // Difficoltà (null = qualsiasi)
                      DropdownButtonFormField<String?>(
                        value: _difficulty,
                        isExpanded: true,
                        decoration: _dec(
                          'Difficoltà',
                          hint: 'Qualsiasi',
                          icon: Icons.speed,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Qualsiasi')),
                          DropdownMenuItem(value: 'easy', child: Text('Easy')),
                          DropdownMenuItem(value: 'medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'hard', child: Text('Hard')),
                        ],
                        onChanged: (v) => setState(() => _difficulty = v),
                      ),

                      const SizedBox(height: 16),

                      // Tipo (multiple/boolean)
                      DropdownButtonFormField<String>(
                        value: _type,
                        isExpanded: true,
                        decoration: _dec(
                          'Tipo domande',
                          icon: Icons.tune,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'multiple',
                            child: Text('Multiple choice'),
                          ),
                          DropdownMenuItem(
                            value: 'boolean',
                            child: Text('Vero/Falso'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? 'multiple'),
                      ),

                      const SizedBox(height: 8),

                      // Toggle token
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Usa token (evita ripetizioni)'),
                        subtitle: const Text('Consigliato per sessioni più lunghe'),
                        value: _useToken,
                        onChanged: (v) => setState(() => _useToken = v),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // BOTTONE AVVIO
              FilledButton.tonalIcon(
                // Se il quiz è in loading, il bottone viene disabilitato.
                onPressed: (quiz.status == QuizStatus.loading)
                    ? null
                    : () async {
                        // Valida la form prima di partire.
                        if (!_formKey.currentState!.validate()) return;

                        // Legge il numero domande; in caso di null fallback a 10.
                        final amount = int.tryParse(_amountCtrl.text.trim()) ?? 10;

                        // Avvia una nuova partita nel controller.
                        await quiz.startNewGame(
                          amount: amount,
                          category: _categoryId,
                          difficulty: _difficulty,
                          type: _type,
                          useToken: _useToken,
                        );

                        // Evita di usare context se la pagina è stata “smontata”.
                        if (!context.mounted) return;

                        // Se tutto ok, porta alla pagina Quiz.
                        if (quiz.status == QuizStatus.playing) {
                          context.go('/quiz');
                        } else if (quiz.status == QuizStatus.error) {
                          // In caso di errore mostra una SnackBar.
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(quiz.errorMessage ?? 'Errore')),
                          );
                        }
                      },
                icon: (quiz.status == QuizStatus.loading)
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  quiz.status == QuizStatus.loading ? 'Caricamento...' : 'Avvia quiz',
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
