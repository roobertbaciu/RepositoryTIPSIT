/// Raccolta di etichette “focus” predefinite e dei relativi colori.
///
/// Struttura:
/// - `defaults`: lista dei nomi suggeriti
/// - `defaultColorValues`: associazione nome -> colore (int ARGB)
/// - `palette`: tavolozza di colori disponibili (int ARGB)
///
/// Nota: i colori sono salvati come interi nel formato ARGB atteso da `Color(int)`,
/// ad esempio `Color(0xFF42A5F5)` dove `0xFF` è l'alpha (opacità) e il resto è RGB.
class FocusLabels {
  /// Etichette di default mostrate all'utente.
  static const List<String> defaults = [
    'Study',
    'Reading',
    'Workout',
    'Meditation',
    'Deep Work',
  ];

  /// Colori di default per ciascuna etichetta.
  ///
  /// Valori in int ARGB (0xAARRGGBB):
  /// - AA = alpha (0xFF = completamente opaco)
  /// - RR = rosso, GG = verde, BB = blu
  static const Map<String, int> defaultColorValues = {
    'Study': 0xFF1E847F,
    'Reading': 0xFF2364AA,
    'Workout': 0xFFC14953,
    'Meditation': 0xFF6B8E23,
    'Deep Work': 0xFF8257E6,
  };

  /// Palette di colori “selezionabili”.
  static const List<int> palette = [
    0xFF1E847F,
    0xFF2364AA,
    0xFFC14953,
    0xFF6B8E23,
    0xFF8257E6,
    0xFFB86B00,
    0xFF007A8A,
    0xFF4A5A68,
  ];
}