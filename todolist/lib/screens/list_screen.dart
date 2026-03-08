import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo_lists_app/providers/app_state.dart';

/// Schermata principale che mostra/gestisce:
/// - creazione di nuove liste
/// - rinomina della lista selezionata
/// - creazione di task nella lista selezionata
///
/// Usa Provider per accedere ad AppState (state globale) tramite `context.read`.
class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  /// Controller per l'input del titolo di un task.
  final TextEditingController _taskController = TextEditingController();

  /// Controller per l'input del nome di una nuova lista.
  final TextEditingController _listController = TextEditingController();

  /// Controller per l'input del nuovo nome durante la rinomina.
  final TextEditingController _renameController = TextEditingController();

  /// Flag UI: true quando stai mostrando la modalità "rinomina".
  bool _isRenaming = false;

  @override
  void dispose() {
    /// È buona pratica fare dispose dei controller quando lo State viene rimosso
    /// dall'albero, per evitare leak e listener attivi inutilmente. 
    _taskController.dispose();
    _listController.dispose();
    _renameController.dispose();
    super.dispose();
  }

  /// Entra in modalità rinomina e precompila il campo con il nome corrente.
  void _startRename(String currentName) {
    setState(() {
      _isRenaming = true;
      _renameController.text = currentName;
    });
  }

  /// Esce dalla modalità rinomina e pulisce il campo.
  void _cancelRename() {
    setState(() {
      _isRenaming = false;
      _renameController.clear();
    });
  }

  /// Tenta di salvare la rinomina della lista.
  ///
  /// - legge il testo dal controller
  /// - chiama AppState.renameList (operazione async + persistenza)
  /// - dopo await, controlla `context.mounted` prima di usare il context
  ///   (SnackBar / setState) perché il widget potrebbe essere stato smontato.
  Future<void> _saveRename(BuildContext context, String listId) async {
    final newName = _renameController.text.trim();
    final success = await context.read<AppState>().renameList(listId, newName);

    /// Dopo un'operazione asincrona, usare `context` è valido solo se lo State
    /// è ancora montato; altrimenti si rischiano errori/assert. 
    if (!context.mounted) return;

    if (success) {
      _cancelRename();
      _showSnack(context, 'Lista rinominata.');
    } else {
      _showSnack(context, 'Il nome della lista e obbligatorio.');
    }
  }

  /// Crea una nuova lista usando AppState.
  ///
  /// Se va a buon fine:
  /// - pulisce il campo di input
  /// - chiude la tastiera (unfocus)
  Future<void> _addList(BuildContext context) async {
    final name = _listController.text.trim();
    final success = await context.read<AppState>().addList(name);

    /// Check fondamentale dopo await prima di usare context (SnackBar/focus). 
    if (!context.mounted) return;

    if (success) {
      _listController.clear();
      FocusScope.of(context).unfocus();
    } else {
      _showSnack(context, 'Il nome della lista e obbligatorio.');
    }
  }

  /// Aggiunge un task nella lista indicata.
  ///
  /// Nota: qui non fai trim prima di passarlo; la validazione vera avviene
  /// lato AppState.addTask (che fa trim e controlla vuoto).
  Future<void> _addTask(BuildContext context, String listId) async {
    final title = _taskController.text;
    final success = await context.read<AppState>().addTask(
          listId: listId,
          title: title,
        );

    /// Anche qui: dopo await verifica che il context sia ancora montato. 
    if (!context.mounted) return;

    if (success) {
      _taskController.clear();
      FocusScope.of(context).unfocus();
    } else {
      _showSnack(context, 'Il titolo del task non puo essere vuoto.');
    }
  }

  /// Elimina la lista selezionata.
  ///
  /// Se stavi rinominando quella lista, annulla la modalità rinomina per evitare
  /// UI incoerente (campo di rinomina aperto su una lista che non esiste più).
  Future<void> _deleteSelectedList(BuildContext context, String listId) async {
    final deleted = await context.read<AppState>().deleteList(listId);

    /// Check mounted dopo await prima di usare il context. 
    if (!context.mounted) return;

    if (deleted) {
      if (_isRenaming) {
        _cancelRename();
      }
      _showSnack(context, 'Lista eliminata.');
    }
  }

  /// Utility per mostrare messaggi rapidi all'utente.
  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final lists = appState.lists;
    final selectedList = appState.selectedList;
    final selectedListId = selectedList?.id;
    final hasValidSelection =
        selectedListId != null && lists.any((list) => list.id == selectedListId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista Attivita'),
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEAF1F4), Color(0xFFF7FAFC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gestisci liste e task',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Seleziona una lista, poi aggiungi o completa le attivita.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: lists.isEmpty
                                ? const Text('Nessuna lista disponibile')
                                : InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Lista selezionata',
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: hasValidSelection ? selectedListId : null,
                                        items: lists
                                            .map(
                                              (list) => DropdownMenuItem<String>(
                                                value: list.id,
                                                child: Text(list.name),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (listId) {
                                          if (listId == null) return;
                                          if (_isRenaming) {
                                            _cancelRename();
                                          }
                                          context.read<AppState>().selectList(listId);
                                        },
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            tooltip: 'Opzioni lista',
                            enabled: selectedList != null,
                            onSelected: (action) {
                              if (selectedList == null) return;
                              if (action == 'rename') {
                                _startRename(selectedList.name);
                              }
                              if (action == 'delete') {
                                _deleteSelectedList(context, selectedList.id);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem<String>(
                                value: 'rename',
                                child: Text('Rinomina'),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Elimina'),
                              ),
                            ],
                            icon: const Icon(Icons.more_vert_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_isRenaming && selectedList != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _renameController,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) =>
                                    _saveRename(context, selectedList.id),
                                decoration: const InputDecoration(
                                  hintText: 'Nuovo nome lista',
                                ),
                              ),
                            ),
                            IconButton.filled(
                              onPressed: () =>
                                  _saveRename(context, selectedList.id),
                              tooltip: 'Salva',
                              icon: const Icon(Icons.check_rounded),
                            ),
                            IconButton(
                              onPressed: _cancelRename,
                              tooltip: 'Annulla',
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _listController,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _addList(context),
                              decoration: const InputDecoration(
                                hintText: 'Nuova lista (es. Spesa)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _addList(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Crea'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (selectedList == null) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.playlist_add_check_rounded, size: 42),
                            SizedBox(height: 10),
                            Text('Crea una lista per iniziare.'),
                          ],
                        ),
                      );
                    }

                    final visibleTasks = selectedList.activeTasks;

                    if (visibleTasks.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_rounded, size: 42),
                            SizedBox(height: 10),
                            Text('Nessun task. Aggiungi il primo qui sotto.'),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
                      itemCount: visibleTasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final task = visibleTasks[index];

                        return Dismissible(
                          key: ValueKey(task.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_outline_rounded),
                          ),
                          confirmDismiss: (_) async {
                            final shouldDelete = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Eliminare task?'),
                                content: const Text(
                                  'Questa azione sposta il task tra gli eliminati.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(false),
                                    child: const Text('Annulla'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(true),
                                    child: const Text('Elimina'),
                                  ),
                                ],
                              ),
                            );
                            return shouldDelete ?? false;
                          },
                          onDismissed: (_) {
                            context.read<AppState>().deleteTask(
                                  listId: selectedList.id,
                                  taskId: task.id,
                                );
                          },
                          child: Card(
                            margin: EdgeInsets.zero,
                              child: CheckboxListTile(
                                value: task.isDone,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                activeColor: Theme.of(context).colorScheme.primary,
                                onChanged: (value) {
                                  if (value == null) return;
                                context.read<AppState>().toggleTaskDone(
                                      listId: selectedList.id,
                                      taskId: task.id,
                                      isDone: value,
                                    );
                              },
                              title: Text(
                                task.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  decoration: task.isDone
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                              subtitle: Text(
                                task.isDone ? 'Completata' : 'Avviata',
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: selectedList == null
          ? null
          : Material(
              elevation: 8,
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _taskController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addTask(context, selectedList.id),
                          decoration: const InputDecoration(
                            hintText: 'Aggiungi un task',
                            prefixIcon: Icon(Icons.edit_note_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _addTask(context, selectedList.id),
                        child: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
