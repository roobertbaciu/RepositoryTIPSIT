import 'package:todo_lists_app/models/task_model.dart';

/// Modello dati che rappresenta una lista di task.
/// Contiene un identificatore, un nome modificabile e la collezione dei task.
class TodoListModel {
  TodoListModel({
    required this.id,
    required this.name,
    List<TaskModel>? tasks,
  }) : tasks = tasks ?? <TaskModel>[]; // Se `tasks` è null, inizializza con lista vuota.

  /// Identificatore univoco della lista.
  final String id;

  /// Nome della lista (es. "Spesa", "Università"), modificabile.
  String name;

  /// Collezione completa dei task (include anche quelli marcati come eliminati).
  /// È `final` per evitare di riassegnare la lista, ma puoi comunque modificarne
  /// il contenuto (aggiungere/rimuovere TaskModel).
  final List<TaskModel> tasks;

  /// Ritorna solo i task "attivi", escludendo quelli in soft delete.
  /// `growable: false` crea una lista non espandibile, utile per comunicare
  /// che è una vista/risultato e non una lista da riutilizzare come storage.
  List<TaskModel> get activeTasks =>
      tasks.where((task) => !task.isDeleted).toList(growable: false);

  /// Numero di task marcati come eliminati (soft delete).
  int get deletedCount => tasks.where((task) => task.isDeleted).length;

  /// Numero totale di task considerati (solo attivi, non eliminati).
  int get totalCount => activeTasks.length;

  /// Numero di task completati tra quelli attivi.
  int get completedCount => activeTasks.where((task) => task.isDone).length;

  /// Numero di task ancora da completare tra quelli attivi.
  /// Calcolato come differenza tra totale attivi e completati.
  int get pendingCount => totalCount - completedCount;

  /// Percentuale di completamento della lista (0–100).
  /// Esempio: 3 completati su 5 totali => 60.0
  double get efficiency {
    if (totalCount == 0) return 0; // Evita divisione per zero.
    return (completedCount / totalCount) * 100;
  }

  /// Deserializza una TodoListModel da JSON.
  factory TodoListModel.fromJson(Map<String, dynamic> json) {
    final rawTasks = json['tasks'] as List<dynamic>? ?? <dynamic>[];
    return TodoListModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tasks: rawTasks
          .map((item) => TaskModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Serializza la lista in JSON.
  ///
  /// Converte anche ogni TaskModel in mappa tramite `task.toJson()`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tasks': tasks.map((task) => task.toJson()).toList(),
    };
  }
}
