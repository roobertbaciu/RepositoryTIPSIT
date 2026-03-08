import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/session_record.dart';
import '../state/app_state.dart';
import '../widgets/stats_cards.dart';

/// Intervallo temporale selezionabile nella UI per filtrare le sessioni.
enum StatsRange { today, week, all }

/// Schermata delle statistiche:
/// - riepilogo "Today" e "All-time"
/// - filtro con SegmentedButton (oggi / ultimi 7 giorni / sempre)
/// - lista delle sessioni recenti nel range selezionato
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  /// Range selezionato dall'utente (di default: oggi).
  StatsRange _range = StatsRange.today;

  @override
  Widget build(BuildContext context) {
    /// Legge AppState e si registra per rebuild automatico quando cambia:
    /// `context.watch<T>()` fa rebuild di questo widget se AppState notifica. 
    final app = context.watch<AppState>(); 
    final now = DateTime.now();

    /// Filtri pronti all'uso:
    /// - today: subset di sessioni che terminano oggi
    /// - all: tutte le sessioni (senza filtro)
    /// - ranged: subset in base al filtro scelto (_range)
    final today = _filter(app.sessions, now, StatsRange.today);
    final all = app.sessions;
    final ranged = _filter(app.sessions, now, _range);

    /// Conteggi "completed" (oggi vs all-time).
    final todayCompleted =
        today.where((s) => s.status == SessionStatus.completed).length;
    final allCompleted =
        all.where((s) => s.status == SessionStatus.completed).length;

    /// Somma dei minuti totali.
    /// `actualSeconds / 60` produce double; usi `.round()` per avere minuti interi.
    final todayMinutes =
        today.fold<int>(0, (sum, s) => sum + (s.actualSeconds / 60).round());
    final allMinutes =
        all.fold<int>(0, (sum, s) => sum + (s.actualSeconds / 60).round());

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          Text('Stats', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),

          /// Card riepilogo di oggi.
          StatsSummaryCard(
            title: 'Today',
            primary: '$todayMinutes min',
            secondary: '$todayCompleted completed - ${today.length} sessions',
            icon: Icons.today_rounded,
          ),

          /// Card riepilogo globale (tutte le sessioni).
          StatsSummaryCard(
            title: 'All-time',
            primary: '$allMinutes min',
            secondary: '$allCompleted completed - ${all.length} sessions',
            icon: Icons.insights_rounded,
          ),

          const SizedBox(height: 12),

          /// SegmentedButton: selezione singola (set con 1 elemento).
          ///
          /// - `segments`: definisce le opzioni
          /// - `selected`: è un Set, ma in modalità single-selection conterrà un solo valore
          /// - `onSelectionChanged`: riceve il nuovo Set selezionato 
          SegmentedButton<StatsRange>(
            segments: const [
              ButtonSegment(value: StatsRange.today, label: Text('Today')),
              ButtonSegment(value: StatsRange.week, label: Text('7 days')),
              ButtonSegment(value: StatsRange.all, label: Text('All time')),
            ],
            selected: {_range},
            onSelectionChanged: (set) => setState(() => _range = set.first),
          ),

          const SizedBox(height: 12),
          Text('Recent sessions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),

          /// Empty-state: nessuna sessione nel range selezionato.
          if (ranged.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No recent sessions in selected range.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            /// Lista (massimo 12) di sessioni recenti.
            ...ranged.take(12).map((s) {
              final done = s.status == SessionStatus.completed;
              final mins = (s.actualSeconds / 60).round();

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  /// Icona e colore dipendono dallo stato della sessione.
                  leading: Icon(
                    done ? Icons.check_circle : Icons.remove_circle,
                    color: done ? Colors.green : Colors.orange,
                  ),

                  /// Titolo: label + durata in minuti.
                  title: Text('${s.label} - $mins min'),

                  /// Sottotitolo: data/ora di fine formattata.
                  subtitle: Text(_fmtDateTime(s.endedAt)),

                  /// A destra mostri una stringa leggibile dello stato.
                  trailing: Text(done ? 'Completed' : 'Interrupted'),
                ),
              );
            }),
        ],
      ),
    );
  }

  /// Filtra e ordina le sessioni in base al range.
  ///
  /// - Today: confronta anno/mese/giorno con `now`
  /// - Week: include quelle con differenza < 7 giorni
  /// - All: include tutto
  List<SessionRecord> _filter(
    List<SessionRecord> all,
    DateTime now,
    StatsRange range,
  ) {
    bool within(SessionRecord s) {
      final d = s.endedAt;
      switch (range) {
        case StatsRange.today:
          /// Stesso giorno di calendario.
          return d.year == now.year && d.month == now.month && d.day == now.day;
        case StatsRange.week:
          /// Ultimi 7 giorni (non include future dates; qui assumiamo endedAt <= now).
          return now.difference(d).inDays < 7; 
        case StatsRange.all:
          return true;
      }
    }

    /// Applica filtro, poi ordina decrescente per endedAt (più recenti prima).
    final result = all.where(within).toList()
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return result;
  }

  /// Format minimale per DateTime: YYYY-MM-DD  HH:MM
  ///
  /// `two()` forza due cifre per mese/giorno/ora/minuti.
  String _fmtDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');

    final y = dt.year;
    final m = two(dt.month);
    final d = two(dt.day);
    final hh = two(dt.hour);
    final mm = two(dt.minute);

    return '$y-$m-$d  $hh:$mm';
  }
}
