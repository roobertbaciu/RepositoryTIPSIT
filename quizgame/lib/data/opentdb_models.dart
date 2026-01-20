import 'dart:convert';

/// Rappresenta una singola domanda pronta per essere mostrata in UI.
///
/// Contiene:
/// - metadati (categoria, difficoltà, tipo)
/// - testo domanda
/// - lista opzioni (mischiate)
/// - risposta corretta
class Question {
  /// Categoria della domanda (es. "Science: Computers").
  final String category;

  /// Difficoltà (valori tipici: "easy" | "medium" | "hard").
  final String difficulty;

  /// Tipo domanda (valori tipici: "multiple" | "boolean").
  final String type;

  /// Testo della domanda.
  final String text;

  /// Lista di opzioni già “mischiate” (include sia corrette che errate).
  final List<String> options;

  /// Testo della risposta corretta (una delle voci in [options]).
  final String correctAnswer;

  /// Crea una domanda già pronta per la UI.
  Question({
    required this.category,
    required this.difficulty,
    required this.type,
    required this.text,
    required this.options,
    required this.correctAnswer,
  });

  // OpenTriviaDB può restituire testo codificato se nella request viene passato
  // `encode=base64`. In quel caso TUTTI i campi testuali arrivano base64-encoded. 
  static String _decodeB64(String s) => utf8.decode(base64.decode(s));

  /// Costruisce una [Question] partendo da un oggetto `result` dell’API
  /// quando viene usato `encode=base64`. 
  ///
  /// Il parametro [m] è una mappa che rappresenta un elemento della lista `results`
  /// restituita da OpenTriviaDB (dopo `jsonDecode`).
  factory Question.fromOtdbBase64(Map<String, dynamic> m) {
    // Decodifica la risposta corretta.
    final correct = _decodeB64(m['correct_answer'] as String);

    // Decodifica tutte le risposte errate.
    final incorrect = (m['incorrect_answers'] as List)
        .map((e) => _decodeB64(e as String))
        .toList();

    // Crea la lista opzioni includendo errate + corretta e poi la miscela.
    // Lo shuffle rende l’ordine non prevedibile (più “da quiz”).
    final allOptions = <String>[...incorrect, correct]..shuffle();

    // Costruisce l’oggetto Question finale decodificando anche i metadati.
    return Question(
      category: _decodeB64(m['category'] as String),
      difficulty: _decodeB64(m['difficulty'] as String),
      type: _decodeB64(m['type'] as String),
      text: _decodeB64(m['question'] as String),
      options: allOptions,
      correctAnswer: correct,
    );
  }
}

/// Rappresenta una categoria di OpenTriviaDB (es. id=18, name="Science: Computers").
///
/// Le categorie vengono scaricate dall’endpoint `/api_category.php` e sono utili
/// per filtrare le domande nella schermata Home.
class TriviaCategory {
  /// Identificativo numerico categoria (da passare come query param `category`).
  final int id;

  /// Nome categoria pronto da mostrare in UI.
  final String name;

  /// Crea una categoria.
  TriviaCategory({required this.id, required this.name});

  /// Alcuni nomi categoria possono includere entità come `&amp;` al posto di `&`.
  /// Questa funzione sostituisce i casi più frequenti senza introdurre dipendenze.
  static String _htmlUnescapeBasic(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  /// Costruisce una [TriviaCategory] a partire da una mappa JSON.
  ///
  /// Il parametro [m] è un elemento della lista `trivia_categories`.
  factory TriviaCategory.fromJson(Map<String, dynamic> m) {
    return TriviaCategory(
      id: m['id'] as int,
      name: _htmlUnescapeBasic(m['name'] as String),
    );
  }
}
