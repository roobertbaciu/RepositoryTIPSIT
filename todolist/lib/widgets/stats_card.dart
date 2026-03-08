import 'package:flutter/material.dart';

/// Widget riutilizzabile per mostrare statistiche.
///
/// È uno StatelessWidget: l’UI dipende solo dai parametri in input e non ha
/// stato interno mutabile; eventuali cambiamenti arrivano “da fuori” tramite
/// rebuild.
class StatsCard extends StatelessWidget {
  /// Crea una card di statistiche.
  ///
  /// Parametri:
  /// - [title]: titolo mostrato nella card (es. "Globale", "Università")
  /// - [completed], [pending], [total]: contatori principali da visualizzare
  /// - [efficiency]: percentuale (tipicamente 0–100) calcolata altrove
  /// - [deleted]: opzionale, per mostrare quanti task sono in soft delete
  /// - [highlighted]: opzionale, per evidenziare graficamente la card (UI/tema)
  const StatsCard({
    super.key,
    required this.title,
    required this.completed,
    required this.pending,
    required this.total,
    required this.efficiency,
    this.deleted = 0,
    this.highlighted = false,
  });

  /// Titolo descrittivo della card.
  final String title;

  /// Numero di task completati.
  final int completed;

  /// Numero di task ancora da fare.
  final int pending;

  /// Numero totale di task considerati (di solito attivi/non eliminati).
  final int total;

  /// Percentuale di completamento (0–100).
  final double efficiency;

  /// Numero di task eliminati logicamente (soft delete).
  /// Default 0 per poter usare StatsCard anche dove non mostri/elabori questo dato.
  final int deleted;

  /// Se true, la card dovrebbe risultare “messa in risalto”
  /// (es. colore diverso, bordo, elevazione, ecc.).
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = highlighted ? const Color(0xFFDCEDEA) : Colors.white;

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2E4D2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${efficiency.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _chip('Completati', completed, Icons.task_alt_rounded),
                _chip('Avviati', pending, Icons.hourglass_bottom_rounded),
                _chip('Totali', total, Icons.format_list_bulleted_rounded),
                _chip('Eliminati', deleted, Icons.delete_outline_rounded),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Efficienza'),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: total == 0 ? 0 : (efficiency / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFE4EAEE),
              color: scheme.primary,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, int value, IconData icon) {
    return Chip(
      backgroundColor: const Color(0xFFF6F9FB),
      side: const BorderSide(color: Color(0xFFDDE5EA)),
      avatar: Icon(icon, size: 16),
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}
