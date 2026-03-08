import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:todo_lists_app/models/task_model.dart';
import 'package:todo_lists_app/models/todo_list_model.dart';
import 'package:todo_lists_app/services/storage_service.dart';

/// Stato globale dell'app (state management) basato su ChangeNotifier.
///
/// Responsabilità principali:
/// - mantenere in memoria le liste e i task
/// - gestire selezione lista corrente
/// - esporre metodi per CRUD (create/rename/delete/toggle)
/// - caricare/salvare su persistenza tramite StorageService
///
/// Nota: usa `_notifySafely()` per evitare `notifyListeners()` durante la build frame.
class AppState extends ChangeNotifier {
  AppState(this._storageService);

  /// Servizio di persistenza.
  /// Incapsula i dettagli di lettura/scrittura dei dati dell'app.
  final StorageService _storageService;

  /// Contatore incrementale usato insieme al timestamp per creare ID unici.
  int _idCounter = 0;

  /// Flag per evitare notify dopo dispose (bug frequente con callback async/post-frame).
  bool _isDisposed = false;

  /// Lista interna mutabile; all'esterno esponiamo una view non modificabile.
  final List<TodoListModel> _lists = <TodoListModel>[];

  /// ID della lista attualmente selezionata (null se non ci sono liste).
  String? _selectedListId;

  /// View read-only delle liste (chi usa AppState non può modificare `_lists` direttamente).
  List<TodoListModel> get lists => List.unmodifiable(_lists);

  /// ID selezionato corrente (può essere null).
  String? get selectedListId => _selectedListId;

  /// Ritorna l'istanza di TodoListModel selezionata, se esiste.
  /// Fa una ricerca lineare nella lista (ok per piccoli dataset).
  TodoListModel? get selectedList {
    if (_selectedListId == null) return null;
    for (final list in _lists) {
      if (list.id == _selectedListId) return list;
    }
    return null;
  }

  /// Carica i dati persistiti e sincronizza lo stato in memoria.
  ///
  /// Flusso:
  /// 1) legge da storage
  /// 2) rimpiazza contenuto di `_lists`
  /// 3) ripristina selezione
  /// 4) garantisce che la selezione punti a una lista valida
  /// 5) notifica la UI
  Future<void> load() async {
    final data = await _storageService.loadAppData();

    _lists
      ..clear()
      ..addAll(data.lists);

    _selectedListId = data.selectedListId;
    _ensureValidSelectedList();

    _notifySafely();
  }

  /// Aggiunge una nuova lista se il nome non è vuoto.
  /// Ritorna `true` se creata, `false` se input non valido.
  Future<bool> addList(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return false;

    final newList = TodoListModel(
      id: _newId(),
      name: trimmedName,
      tasks: <TaskModel>[],
    );

    _lists.add(newList);

    /// Dopo creazione, seleziona automaticamente la nuova lista.
    _selectedListId = newList.id;

    _notifySafely();
    await _save();
    return true;
  }

  /// Rinomina una lista esistente.
  ///
  /// - Valida input
  /// - Cerca la lista
  /// - Evita salvataggi inutili se il nome è identico
  Future<bool> renameList(String listId, String newName) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) return false;

    final list = _findListById(listId);
    if (list == null) return false;

    /// Se non cambia nulla, consideriamo l'operazione riuscita.
    if (list.name == trimmedName) return true;

    list.name = trimmedName;
    _notifySafely();
    await _save();
    return true;
  }

  /// Elimina una lista (rimozione reale dalla collezione).
  /// Ritorna `true` se qualcosa è stato rimosso.
  Future<bool> deleteList(String listId) async {
    final before = _lists.length;
    _lists.removeWhere((list) => list.id == listId);

    /// Confronta la lunghezza per capire se l'ID esisteva.
    final removed = _lists.length < before;
    if (!removed) return false;

    /// Se la lista selezionata è stata rimossa, imposta una selezione valida.
    _ensureValidSelectedList();
    _notifySafely();
    await _save();
    return true;
  }

  /// Seleziona una lista esistente e salva la preferenza.
  Future<void> selectList(String listId) async {
    /// Ignora se l'ID non esiste.
    if (_findListById(listId) == null) return;

    /// Ignora se già selezionata (evita notify/save inutili).
    if (_selectedListId == listId) return;

    _selectedListId = listId;
    _notifySafely();
    await _save();
  }

  /// Aggiunge un task a una lista.
  /// Ritorna `true` se creato, `false` se input non valido o lista non trovata.
  Future<bool> addTask({
    required String listId,
    required String title,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return false;

    final list = _findListById(listId);
    if (list == null) return false;

    final newTask = TaskModel(
      id: _newId(),
      title: trimmedTitle,
      isDone: false,
      /// Timestamp usato per ordinamenti/filtri e per mostrare "creato il...".
      createdAtEpoch: DateTime.now().millisecondsSinceEpoch,
    );

    list.tasks.add(newTask);
    _notifySafely();
    await _save();
    return true;
  }

  /// Imposta lo stato "done" di un task.
  ///
  /// Protezioni:
  /// - non fa nulla se task non trovato
  /// - non modifica task eliminati (soft deleted)
  /// - evita scrittura se lo stato è già quello richiesto
  Future<void> toggleTaskDone({
    required String listId,
    required String taskId,
    required bool isDone,
  }) async {
    final task = _findTask(listId: listId, taskId: taskId);
    if (task == null) return;
    if (task.isDeleted) return;
    if (task.isDone == isDone) return;

    task.isDone = isDone;
    _notifySafely();
    await _save();
  }

  /// Elimina un task con soft delete (non lo rimuove dalla lista).
  ///
  /// Vantaggi: puoi mantenere storico, sincronizzare, ripristinare, ecc.
  Future<void> deleteTask({
    required String listId,
    required String taskId,
  }) async {
    final task = _findTask(listId: listId, taskId: taskId);
    if (task == null) return;
    if (task.isDeleted) return;

    task.isDeleted = true;

    _notifySafely();
    await _save();
  }

  /// Cerca una lista per ID (ricerca lineare).
  TodoListModel? _findListById(String id) {
    for (final list in _lists) {
      if (list.id == id) return list;
    }
    return null;
  }

  /// Cerca un task dentro una lista specifica.
  TaskModel? _findTask({
    required String listId,
    required String taskId,
  }) {
    final list = _findListById(listId);
    if (list == null) return null;

    for (final task in list.tasks) {
      if (task.id == taskId) return task;
    }
    return null;
  }

  /// Garantisce che `_selectedListId` sia coerente con lo stato attuale.
  ///
  /// Regole:
  /// - se non ci sono liste, selezione a null
  /// - se l'ID selezionato non esiste più, seleziona la prima lista disponibile
  void _ensureValidSelectedList() {
    if (_lists.isEmpty) {
      _selectedListId = null;
      return;
    }

    final hasCurrentSelection =
        _selectedListId != null && _findListById(_selectedListId!) != null;

    if (!hasCurrentSelection) {
      _selectedListId = _lists.first.id;
    }
  }

  /// Genera un ID "abbastanza unico" per uso locale:
  /// - timestamp in microsecondi (alta granularità)
  /// - contatore incrementale per distinguere più chiamate nello stesso microsecondo
  String _newId() {
    _idCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  /// Salva lo stato corrente su storage.
  /// Nota: salva la lista completa (include task soft-deleted).
  Future<void> _save() {
    return _storageService.saveAppData(
      lists: _lists,
      selectedListId: _selectedListId,
    );
  }

  /// Notifica i listener in modo sicuro.
  ///
  /// Problema che risolve:
  /// - chiamare `notifyListeners()` durante la fase di build può causare errori
  ///   (es. "setState or markNeedsBuild called during build").
  ///
  /// Strategia:
  /// - se siamo "durante build", rimanda la notifica al prossimo frame con post-frame callback
  /// - se l'oggetto è già disposed, non notifica
  void _notifySafely() {
    if (_isDisposed) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    final duringBuild = phase == SchedulerPhase.persistentCallbacks;

    if (duringBuild) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_isDisposed) return;
        notifyListeners();
      });
      return;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
