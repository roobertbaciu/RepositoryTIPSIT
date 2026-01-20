import 'package:flutter/foundation.dart';

import '../data/opentdb_api.dart';
import '../data/opentdb_models.dart';

/// Stati “macro” del gioco.
///
/// - idle: nessuna partita attiva
/// - loading: scaricamento token/domande in corso
/// - playing: partita in corso
/// - finished: partita terminata (tutte le domande completate)
/// - error: errore durante una fase (rete, response_code != 0, ecc.)
enum QuizStatus {
  idle,
  loading,
  playing,
  finished,
  error,
}

/// Controller principale della logica del quiz.
///
/// Estende [ChangeNotifier] per permettere alla UI di ascoltare i cambi di stato.
/// Quando lo stato cambia, viene chiamato `notifyListeners()` per aggiornare la UI. 
class QuizController extends ChangeNotifier {
  /// Client API (OpenTriviaDB).
  final OpenTdbApi api;

  /// Crea il controller e riceve le dipendenze necessarie (API).
  QuizController({required this.api});

  /// Stato corrente del quiz.
  QuizStatus status = QuizStatus.idle;

  /// Domande della partita corrente.
  List<Question> questions = [];

  /// Indice della domanda corrente (0-based).
  int currentIndex = 0;

  /// Punteggio corrente (qui: +1 per ogni risposta corretta).
  int score = 0;

  /// Risposta selezionata dall’utente per la domanda corrente.
  ///
  /// Serve per:
  /// - mostrare feedback (colore/icone)
  /// - impedire doppi tap sulla stessa domanda
  String? selectedAnswer;

  /// True quando la risposta è stata data e la domanda è “bloccata”.
  bool isAnswerLocked = false;

  /// Messaggio d’errore “tecnico” (poi renderizzabile in UI).
  String? errorMessage;

  /// Ultimo amount usato.
  int lastAmount = 10;

  /// Ultima categoria usata (id), null = qualsiasi.
  int? lastCategory;

  /// Ultima difficoltà usata, null = qualsiasi.
  String? lastDifficulty; // easy/medium/hard

  /// Ultimo tipo usato, null = qualsiasi (qui viene passato sempre).
  String? lastType; // multiple/boolean

  /// Indica se nell’ultima partita è stato usato il token.
  bool lastUseToken = true;

  /// Session token salvato in memoria (se usato).
  String? token;

  /// Numero totale domande caricate.
  int get totalQuestions => questions.length;

  /// Risposte dell’utente per ogni domanda (stessa lunghezza di [questions]).
  ///
  /// Ogni elemento è:
  /// - la risposta scelta
  /// - oppure null se non è stata data (in questa app normalmente non succede,
  ///   perché il pulsante “Avanti” è bloccato finché non si risponde).
  List<String?> userAnswers = [];

  /// Ritorna la domanda corrente, oppure null se non disponibile.
  Question? get currentQuestion {
    if (questions.isEmpty) return null;
    if (currentIndex < 0 || currentIndex >= questions.length) return null;
    return questions[currentIndex];
  }

  /// Lista categorie (cache in memoria).
  List<TriviaCategory> categories = [];

  /// True mentre le categorie sono in caricamento.
  bool categoriesLoading = false;

  /// Carica la lista categorie una sola volta (cache in memoria).
  ///
  /// - Se [categories] è già popolata, termina subito.
  /// - Imposta [categoriesLoading] per mostrare loader in UI.
  /// - Notifica la UI prima/dopo il caricamento. 
  Future<void> loadCategories() async {
    // Evita di riscaricare se già presenti (cache semplice).
    if (categories.isNotEmpty) return;

    // Imposta loading ON e notifica la UI.
    categoriesLoading = true;
    notifyListeners(); // notifica i listener (UI) che lo stato è cambiato 

    try {
      // Recupera le categorie dall’API.
      categories = await api.fetchCategories();
    } finally {
      // Spegne loading anche se accade un errore (finally garantisce l’esecuzione).
      categoriesLoading = false;
      notifyListeners(); // aggiorna la UI a fine caricamento 
    }
  }

  /// Avvia una nuova partita.
  ///
  /// Esegue questi passi:
  /// 1) Imposta lo stato a loading e resetta i dati di partita
  /// 2) (Opzionale) Richiede o riusa il Session Token
  /// 3) Scarica le domande
  /// 4) Inizializza la lista risposte utente
  /// 5) Imposta lo stato a playing
  ///
  /// In caso di errore:
  /// - Imposta [status] a error
  /// - Salva [errorMessage]
  /// - Notifica la UI
  Future<void> startNewGame({
    int amount = 10,
    int? category,
    String? difficulty,
    String? type,
    bool useToken = true,
  }) async {
    // Imposta lo stato: caricamento in corso.
    status = QuizStatus.loading;
    errorMessage = null;

    // Salva le impostazioni così “Rigioca” può riusarle.
    lastAmount = amount;
    lastCategory = category;
    lastDifficulty = difficulty;
    lastType = type;
    lastUseToken = useToken;

    // Reset dati partita.
    questions = [];
    userAnswers = [];
    currentIndex = 0;
    score = 0;
    selectedAnswer = null;
    isAnswerLocked = false;

    // Notifica la UI: mostra loader e reset schermate.
    notifyListeners(); 

    try {
      // Se richiesto, ottiene (o riusa) un token per evitare ripetizioni.
      if (useToken) {
        token ??= await api.requestToken();
      } else {
        token = null;
      }

      // Scarica le domande usando i parametri scelti in Home.
      questions = await api.fetchQuestions(
        amount: amount,
        category: category,
        difficulty: difficulty,
        type: type,
        token: token,
      );

      // Inizializza la lista delle risposte utente con null per ogni domanda.
      userAnswers = List<String?>.filled(questions.length, null);

      // Imposta lo stato: si può giocare.
      status = QuizStatus.playing;
      notifyListeners(); // aggiorna UI (mostra domanda) 
    } catch (e) {
      // In caso di errore: salva info e mostra schermata errore.
      status = QuizStatus.error;
      errorMessage = e.toString();
      notifyListeners(); // aggiorna UI (errore) 
    }
  }

  /// Registra la risposta dell’utente alla domanda corrente.
  ///
  /// Comportamento:
  /// - Se non si è nello stato playing, non fa nulla.
  /// - Se la domanda è già bloccata, ignora tap multipli.
  /// - Salva la risposta in [selectedAnswer] e in [userAnswers]
  /// - Aggiorna [score] se la risposta è corretta
  /// - Blocca la domanda per evitare doppie risposte
  /// - Notifica la UI
  void answer(String option) {
    // Permette di rispondere solo durante la partita.
    if (status != QuizStatus.playing) return;

    // Evita risposte multiple sulla stessa domanda.
    if (isAnswerLocked) return;

    // Memorizza la risposta selezionata e blocca la domanda.
    selectedAnswer = option;
    isAnswerLocked = true;

    // Salva la risposta utente nella lista parallela alle domande.
    if (currentIndex >= 0 && currentIndex < userAnswers.length) {
      userAnswers[currentIndex] = option;
    }

    // Verifica correttezza e aggiorna punteggio.
    final q = currentQuestion;
    if (q != null && option == q.correctAnswer) {
      score += 1;
    }

    // Notifica la UI: colori/icone risposta, abilita “Avanti”.
    notifyListeners(); 
  }

  /// Passa alla domanda successiva oppure termina la partita.
  ///
  /// Regole:
  /// - Permette di avanzare solo se è stata data una risposta (locked = true)
  /// - Se si è all’ultima domanda, imposta stato a finished
  /// - Altrimenti incrementa [currentIndex] e resetta lo stato di risposta
  void next() {
    // Permette di avanzare solo in partita.
    if (status != QuizStatus.playing) return;

    // Obbliga a rispondere prima di procedere.
    if (!isAnswerLocked) return;

    // Se si è all’ultima domanda, termina la partita.
    if (currentIndex >= questions.length - 1) {
      status = QuizStatus.finished;
      notifyListeners(); // aggiorna UI (risultati disponibili) 
      return;
    }

    // Passa alla domanda successiva.
    currentIndex += 1;

    // Reset stato risposta per la nuova domanda.
    selectedAnswer = null;
    isAnswerLocked = false;

    // Notifica la UI: mostra la domanda successiva.
    notifyListeners(); 
  }

  /// Riporta lo stato a “idle” (reset soft).
  ///
  /// Serve quando si vuole ripartire da Home con una nuova partita.
  void resetToIdle() {
    status = QuizStatus.idle;
    questions = [];
    userAnswers = [];
    currentIndex = 0;
    score = 0;
    selectedAnswer = null;
    isAnswerLocked = false;
    errorMessage = null;

    // Notifica la UI: torna allo stato iniziale.
    notifyListeners(); 
  }

  /// Esegue il reset del token lato server (se presente).
  ///
  /// Serve quando si vuole ripartire “da zero” anche lato OpenTriviaDB
  /// (così le domande possono ripresentarsi). 
  Future<void> resetToken() async {
    if (token == null) return;
    await api.resetToken(token!);
  }
}
