import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_lists_app/models/todo_list_model.dart';

/// Data container che rappresenta ciò che viene caricato dallo storage:
/// - tutte le liste salvate
/// - l'ID della lista selezionata l'ultima volta (può essere null)
class LoadedAppData {
  LoadedAppData({
    required this.lists,
    required this.selectedListId,
  });

  /// Liste deserializzate in memoria.
  final List<TodoListModel> lists;

  /// Ultima lista selezionata salvata su storage (null se non presente).
  final String? selectedListId;
}

/// Servizio di persistenza locale basato su SharedPreferences.
///
/// Strategia usata:
/// - salva tutte le liste in un'unica stringa JSON sotto una chiave (`_listsKey`)
/// - salva separatamente l'ID selezionato (`_selectedListIdKey`)
///
/// SharedPreferences è adatto per piccole quantità di dati key-value, e permette
/// set/get di String (oltre ad altri tipi) e remove di una chiave. 
class StorageService {
  /// Chiave usata per salvare la lista di TodoListModel come JSON.
  static const String _listsKey = 'todo_lists';

  /// Chiave usata per salvare l'ID della lista selezionata.
  static const String _selectedListIdKey = 'selected_list_id';

  /// Carica i dati dell'app da SharedPreferences.
  ///
  /// Flusso:
  /// 1) ottiene l'istanza di SharedPreferences 
  /// 2) legge la stringa JSON con `getString`
  /// 3) se mancante/vuota => ritorna stato "vuoto"
  /// 4) decodifica JSON e prova a trasformarlo in List<TodoListModel>
  /// 5) in caso di errore o formato inatteso => ritorna stato "vuoto"
  Future<LoadedAppData> loadAppData() async {
    final prefs = await SharedPreferences.getInstance(); 
    final listsJson = prefs.getString(_listsKey); // Se non esiste, ritorna null. 
    final selectedListId = prefs.getString(_selectedListIdKey); // Id selezionato, o null. 

    /// Nessun dato salvato: app "pulita".
    if (listsJson == null || listsJson.isEmpty) {
      return LoadedAppData(lists: <TodoListModel>[], selectedListId: null);
    }

    try {
      /// jsonDecode ritorna `dynamic`, quindi controlliamo il tipo runtime.
      final decoded = jsonDecode(listsJson);

      /// Ci aspettiamo una lista (array JSON) di oggetti lista.
      if (decoded is! List<dynamic>) {
        return LoadedAppData(lists: <TodoListModel>[], selectedListId: null);
      }

      /// Converte ogni elemento della lista in TodoListModel.
      /// Assunzione: ogni item è una Map<String, dynamic>.
      final lists = decoded
          .map((item) => TodoListModel.fromJson(item as Map<String, dynamic>))
          .toList();

      return LoadedAppData(lists: lists, selectedListId: selectedListId);
    } catch (_) {
      /// Se la stringa non è JSON valido o la struttura non corrisponde,
      /// fallback a stato vuoto per evitare crash all'avvio.
      return LoadedAppData(lists: <TodoListModel>[], selectedListId: null);
    }
  }

  /// Salva i dati dell'app su SharedPreferences.
  ///
  /// - serializza tutte le liste con `toJson()`
  /// - `jsonEncode` produce una stringa
  /// - salva la stringa con `setString`
  /// - salva l'ID selezionato separatamente; se null rimuove la chiave
  Future<void> saveAppData({
    required List<TodoListModel> lists,
    required String? selectedListId,
  }) async {
    final prefs = await SharedPreferences.getInstance(); 

    /// Serializzazione: List<TodoListModel> -> List<Map> -> JSON string.
    final listsString = jsonEncode(
      lists.map((list) => list.toJson()).toList(),
    );

    /// Persiste la stringa JSON sotto `_listsKey`. 
    await prefs.setString(_listsKey, listsString); 

    /// Se non c'è selezione, elimina la chiave per non lasciare un valore.
    if (selectedListId == null) {
      await prefs.remove(_selectedListIdKey); 
    } else {
      await prefs.setString(_selectedListIdKey, selectedListId); 
    }
  }
}
