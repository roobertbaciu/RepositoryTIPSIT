/// Stato finale di una sessione di focus.
///
/// - completed: la sessione è arrivata fino alla fine prevista
/// - interrupted: la sessione è stata interrotta prima del completamento
enum SessionStatus {
  completed,
  interrupted,
}

/// Record (immutabile) che rappresenta una singola sessione salvata nello storico.
///
/// Contiene:
/// - metadati (label)
/// - durata pianificata (minuti) e durata reale (secondi)
/// - stato finale (enum)
/// - timestamp di inizio/fine (DateTime)
class SessionRecord {
  SessionRecord({
    required this.label,
    required this.plannedMinutes,
    required this.actualSeconds,
    required this.status,
    required this.startedAt,
    required this.endedAt,
  });

  /// Etichetta associata alla sessione (es. "Study", "Deep Work").
  final String label;

  /// Durata pianificata in minuti (quella impostata dall'utente).
  final int plannedMinutes;

  /// Durata effettiva in secondi (utile se interrompi a metà).
  final int actualSeconds;

  /// Esito della sessione.
  final SessionStatus status;

  /// Momento di avvio della sessione.
  final DateTime startedAt;

  /// Momento di fine sessione (fine naturale o interruzione).
  final DateTime endedAt;

  /// Serializza il record in una Map pronta per essere convertita in JSON.
  ///
  /// Scelte di serializzazione:
  /// - enum: salva `status.name` (stringa stabile e leggibile) 
  /// - DateTime: salva ISO 8601 con `toIso8601String()` per avere un formato standard 
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'plannedMinutes': plannedMinutes,
      'actualSeconds': actualSeconds,
      'status': status.name, 
      'startedAt': startedAt.toIso8601String(), 
      'endedAt': endedAt.toIso8601String(), 
    };
  }

  /// Deserializza un record da JSON.
  ///
  /// Robustezza:
  /// - fallback su valori di default se chiavi mancanti/null
  /// - per l'enum, prova a trovare il valore con lo stesso `name`,
  ///   altrimenti usa `interrupted` come default (più “sicuro” di completed) 
  /// - per le date, usa `DateTime.tryParse` e fallback a `DateTime.now()`
  ///   se la stringa non è valida
  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    return SessionRecord(
      label: json['label'] as String? ?? 'Focus',
      plannedMinutes: json['plannedMinutes'] as int? ?? 0,
      actualSeconds: json['actualSeconds'] as int? ?? 0,

      /// Cerca un enum con lo stesso nome salvato nel JSON.
      /// `firstWhere(..., orElse: ...)` evita eccezioni se non trova match. 
      status: SessionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SessionStatus.interrupted,
      ),

      /// Parsing ISO 8601 (o simili) in DateTime; se fallisce, usa "adesso".
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      endedAt: DateTime.tryParse(json['endedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
