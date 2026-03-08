import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo_lists_app/models/todo_list_model.dart';
import 'package:todo_lists_app/providers/app_state.dart';
import 'package:todo_lists_app/widgets/stats_card.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final lists = appState.lists;

    if (lists.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Statistiche')),
        body: const Center(
          child: Text('Nessuna lista. Crea una lista per vedere le statistiche.'),
        ),
      );
    }

    final selected = appState.selectedList;
    final global = _buildGlobalStats(lists);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistiche')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEAF1F4), Color(0xFFF7FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (selected != null) ...[
              StatsCard(
                title: 'Lista selezionata: ${selected.name}',
                completed: selected.completedCount,
                pending: selected.pendingCount,
              total: selected.totalCount,
              efficiency: selected.efficiency,
              deleted: selected.deletedCount,
              highlighted: true,
            ),
              const SizedBox(height: 12),
            ],
            StatsCard(
              title: 'Riepilogo globale',
              completed: global.completed,
              pending: global.pending,
              total: global.total,
              efficiency: global.efficiency,
              deleted: global.deleted,
            ),
            const SizedBox(height: 16),
            Text(
              'Tutte le liste',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...lists.map(
              (list) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: StatsCard(
                  title: list.name,
                  completed: list.completedCount,
                  pending: list.pendingCount,
                  total: list.totalCount,
                  efficiency: list.efficiency,
                  deleted: list.deletedCount,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Calcola statistiche globali aggregando tutte le TodoListModel.
  ///
  /// Somma i contatori di ogni lista e poi deriva:
  /// - pending = total - completed
  /// - efficiency = percentuale completati sul totale (0–100)
  _GlobalStats _buildGlobalStats(List<TodoListModel> lists) {
    // Contatori aggregati (sommati su tutte le liste).
    var completed = 0;
    var total = 0;
    var deleted = 0;

    /// Cicla su tutte le liste e accumula i rispettivi contatori.
    /// Qui usa le proprietà calcolate del model:
    /// - completedCount: completati tra gli attivi
    /// - totalCount: totale attivi (non eliminati)
    /// - deletedCount: task in soft delete
    for (final list in lists) {
      completed += list.completedCount;
      total += list.totalCount;
      deleted += list.deletedCount;
    }

    /// Task ancora da fare = totale attivi - completati.
    final pending = total - completed;

    /// Efficienza come percentuale.
    /// Se total == 0, evita divisione per zero e ritorna 0.0.
    final efficiency = total == 0 ? 0.0 : (completed / total) * 100;

    /// Ritorna un “value object” con i valori già pronti per la UI.
    return _GlobalStats(
      completed: completed,
      pending: pending,
      total: total,
      efficiency: efficiency,
      deleted: deleted,
    );
  }
}

/// Contenitore immutabile per le statistiche globali.
///
/// È una classe privata (underscore) per indicare che è un dettaglio interno
/// della schermata/file e non fa parte delle API pubbliche. 
class _GlobalStats {
  _GlobalStats({
    required this.completed,
    required this.pending,
    required this.total,
    required this.efficiency,
    required this.deleted,
  });

  /// Numero totale di task completati (tra quelli attivi) su tutte le liste.
  final int completed;

  /// Numero totale di task pendenti (attivi ma non completati) su tutte le liste.
  final int pending;

  /// Numero totale di task attivi (non eliminati) su tutte le liste.
  final int total;

  /// Percentuale completati sul totale, valore 0–100.
  final double efficiency;

  /// Numero totale di task marcati come eliminati (soft delete) su tutte le liste.
  final int deleted;
}
