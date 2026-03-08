import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_record.dart';

/// Persistenza locale (SharedPreferences) per:
/// - storico delle sessioni (`SessionRecord`)
/// - mappa colori associati alle label (String -> int ARGB)
class SessionStorage {
  /// Chiave per salvare/leggere la lista di sessioni come stringa JSON.
  static const _sessionsKey = 'flowfocus_sessions';

  /// Chiave per salvare/leggere la mappa label->colore come stringa JSON.
  static const _labelColorsKey = 'flowfocus_label_colors';

  /// Carica tutte le sessioni salvate.
  ///
  /// - legge una stringa JSON da SharedPreferences (`getString`) 
  /// - se non esiste o è vuota, ritorna lista vuota
  /// - decodifica con jsonDecode e converte ogni elemento in SessionRecord
  static Future<List<SessionRecord>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance(); 
    final raw = prefs.getString(_sessionsKey); 
    if (raw == null || raw.isEmpty) {
      return [];
    }

    /// `jsonDecode` ritorna dynamic; qui ti aspetti un array JSON => List<dynamic>.
    final data = jsonDecode(raw) as List<dynamic>;

    /// Per ogni elemento:
    /// - `Map<String, dynamic>.from(e)` forza una Map tipizzata (utile perché dal decode
    ///   spesso ottieni mappe con tipi dynamic) 
    /// - poi chiami `SessionRecord.fromJson(...)`
    return data
        .map((e) => SessionRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Salva l'elenco delle sessioni.
  ///
  /// - converte ogni SessionRecord in Map con `toJson()`
  /// - `jsonEncode` produce una stringa
  /// - `setString` salva su SharedPreferences 
  static Future<void> saveSessions(List<SessionRecord> sessions) async {
    final prefs = await SharedPreferences.getInstance(); 
    final payload = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_sessionsKey, payload); 
  }

  /// Carica la mappa colori associati alle label.
  ///
  /// Ritorna: Map<String, int> dove l'int è un colore ARGB (0xAARRGGBB)
  /// compatibile con `Color(value)`.
  static Future<Map<String, int>> loadLabelColors() async {
    final prefs = await SharedPreferences.getInstance(); 
    final raw = prefs.getString(_labelColorsKey); 
    if (raw == null || raw.isEmpty) {
      return {};
    }

    /// Qui ti aspetti un oggetto JSON => Map<String, dynamic>.
    final data = jsonDecode(raw) as Map<String, dynamic>;

    /// Converte la mappa in Map<String, int>.
    /// Assunzione: ogni value è già un int (perché lo hai salvato tu così).
    return data.map((key, value) => MapEntry(key, value as int));
  }

  /// Salva la mappa label -> colore.
  ///
  /// La mappa viene salvata come JSON string in SharedPreferences. 
  static Future<void> saveLabelColors(Map<String, int> labelColors) async {
    final prefs = await SharedPreferences.getInstance(); 
    await prefs.setString(_labelColorsKey, jsonEncode(labelColors)); 
  }
}
