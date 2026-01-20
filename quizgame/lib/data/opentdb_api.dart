import 'dart:convert';
import 'package:http/http.dart' as http;

import 'opentdb_models.dart';

/// Client minimale per OpenTriviaDB.
///
/// Caratteristiche principali:
/// - API JSON gratuita (nessuna API key richiesta). 
/// - Endpoint domande: `/api.php`. 
/// - Session Token per evitare ripetizioni (scade dopo 6 ore di inattività). 
/// - Supporto encoding (es. `base64`) per caratteri speciali. 
class OpenTdbApi {
  /// Host base del servizio.
  static const String _host = 'opentdb.com';

  /// Path endpoint per recupero domande.
  static const String _pathQuestions = '/api.php';

  /// Path endpoint per gestione Session Token.
  static const String _pathToken = '/api_token.php';

  /// Client HTTP riutilizzabile (migliore che crearne uno ad ogni chiamata).
  final http.Client _client;

  /// Crea il client API.
  ///
  /// Se viene passato un [client], usa quello.
  /// Altrimenti crea un `http.Client()` standard.
  OpenTdbApi({http.Client? client}) : _client = client ?? http.Client();

  /// Recupera una lista di domande dal database.
  ///
  /// Parametri:
  /// - [amount]: numero di domande (default 10).
  /// - [category]: id categoria (opzionale).
  /// - [difficulty]: `easy` | `medium` | `hard` (opzionale).
  /// - [type]: `multiple` | `boolean` (opzionale).
  /// - [token]: Session Token (opzionale ma consigliato per evitare ripetizioni). 
  ///
  /// Note:
  /// - Imposta `encode=base64` per evitare problemi con caratteri speciali/Unicode. 
  /// - Se `response_code != 0`, lancia [OpenTdbException]. 
  Future<List<Question>> fetchQuestions({
    int amount = 10,
    int? category,
    String? difficulty,
    String? type,
    String? token,
  }) async {
    // 1) Crea la mappa dei query parameters della request.
    // Vengono aggiunti solo quelli valorizzati (category/difficulty/type/token).
    final qp = <String, String>{
      'amount': '$amount',

      // 2) Imposta un encoding esplicito:
      // base64 è comodo perché rende la decodifica deterministica lato app. 
      'encode': 'base64',

      if (category != null) 'category': '$category',
      if (difficulty != null) 'difficulty': difficulty,
      if (type != null) 'type': type,
      if (token != null) 'token': token,
    };

    // 3) Crea la URI completa:
    // https://opentdb.com/api.php?amount=10&type=multiple&encode=base64...
    final uri = Uri.https(_host, _pathQuestions, qp);

    // 4) Esegue una chiamata GET.
    final res = await _client.get(uri);

    // 5) Gestisce errori HTTP (rete/server).
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    // 6) Converte il body JSON in Map.
    final body = jsonDecode(res.body) as Map<String, dynamic>;

    // 7) Legge response_code:
    // 0 = OK, altri valori = casi come "no results", problemi token, ecc. 
    final code = body['response_code'] as int;
    if (code != 0) {
      throw OpenTdbException(code);
    }

    // 8) Estrae la lista "results" e crea la lista di Question.
    final results = (body['results'] as List).cast<Map<String, dynamic>>();
    return results.map(Question.fromOtdbBase64).toList();
  }

  /// Scarica la lista delle categorie disponibili.
  ///
  /// Endpoint: `GET https://opentdb.com/api_category.php` (category lookup). 
  ///
  /// Ritorna una lista di [TriviaCategory] (id + name).
  Future<List<TriviaCategory>> fetchCategories() async {
    // 1) Crea la URI per il lookup categorie.
    final uri = Uri.https(_host, '/api_category.php');

    // 2) Esegue la GET.
    final res = await _client.get(uri);

    // 3) Gestisce errori HTTP.
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    // 4) Parse JSON.
    final body = jsonDecode(res.body) as Map<String, dynamic>;

    // 5) Estrae la lista sotto la chiave "trivia_categories".
    final list = (body['trivia_categories'] as List).cast<Map<String, dynamic>>();

    // 6) Converte ogni elemento in TriviaCategory.
    return list.map(TriviaCategory.fromJson).toList();
  }

  /// Richiede un Session Token (command=request).
  ///
  /// Il Session Token serve a non ricevere due volte la stessa domanda. 
  /// Il token viene eliminato dopo 6 ore di inattività. 
  ///
  /// Ritorna la stringa token se la richiesta va a buon fine.
  Future<String> requestToken() async {
    // 1) Crea URI: /api_token.php?command=request
    final uri = Uri.https(_host, _pathToken, {'command': 'request'});

    // 2) Esegue la GET.
    final res = await _client.get(uri);

    // 3) Gestisce errori HTTP.
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    // 4) Parse JSON.
    final body = jsonDecode(res.body) as Map<String, dynamic>;

    // 5) Controlla response_code: 0 = OK. 
    final code = body['response_code'] as int;
    if (code != 0) {
      throw OpenTdbException(code);
    }

    // 6) Ritorna il token.
    return body['token'] as String;
  }

  /// Esegue il reset di un Session Token (command=reset).
  ///
  /// Il reset azzera la “memoria” del token, quindi le domande possono ricomparire. 
  /// Endpoint: `/api_token.php?command=reset&token=...` 
  Future<void> resetToken(String token) async {
    // 1) Crea URI: /api_token.php?command=reset&token=XXXX
    final uri = Uri.https(_host, _pathToken, {
      'command': 'reset',
      'token': token,
    });

    // 2) Esegue la GET.
    final res = await _client.get(uri);

    // 3) Gestisce errori HTTP.
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    // 4) Parse JSON e controllo response_code.
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final code = body['response_code'] as int;

    if (code != 0) {
      throw OpenTdbException(code);
    }
  }

  /// Chiude il client HTTP.
  ///
  /// Buona pratica: chiamare `dispose()` quando il client non serve più,
  /// per rilasciare risorse e connessioni interne.
  void dispose() {
    _client.close();
  }
}

/// Eccezione custom per gestire i `response_code` restituiti da OpenTriviaDB. 
class OpenTdbException implements Exception {
  /// Codice restituito dal server in `response_code`.
  final int responseCode;

  /// Crea l'eccezione con il relativo [responseCode].
  OpenTdbException(this.responseCode);

  @override
  String toString() {
    // Mantiene un messaggio semplice e “tecnico”.
    // In UI, il codice può essere mappato a messaggi più chiari.
    return 'OpenTdbException(response_code=$responseCode)';
  }
}
