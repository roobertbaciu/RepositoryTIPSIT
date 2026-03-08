/// Modello dati che rappresenta un singolo task.
/// Contiene campi per stato di completamento, "cancellazione logica"
/// e timestamp di creazione.
class TaskModel {
  TaskModel({
    required this.id,
    required this.title,
    this.isDone = false,
    this.isDeleted = false,
    required this.createdAtEpoch,
  });

  /// Identificatore univoco del task.
  final String id;

  /// Titolo/descrizione breve del task.
  String title;

  /// True se il task è stato completato.
  bool isDone;

  /// True se il task è stato "eliminato" in modo logico.
  bool isDeleted;

  /// Timestamp di creazione in formato epoch.
  final int createdAtEpoch;

  /// Crea un'istanza di TaskModel partendo da una mappa JSON.

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      isDone: json['isDone'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAtEpoch: json['createdAtEpoch'] as int? ?? 0,
    );
  }

  /// Converte l'oggetto in una mappa serializzabile in JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isDone': isDone,
      'isDeleted': isDeleted,
      'createdAtEpoch': createdAtEpoch,
    };
  }
}
