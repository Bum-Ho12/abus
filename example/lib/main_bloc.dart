// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:abus/abus.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ABUS BLoC Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: BlocProvider(
        create: (context) => TodoBloc(),
        child: const TodoListPage(),
      ),
    );
  }
}

// Data Models
class Todo {
  final String id;
  final String title;
  final bool completed;
  final DateTime createdAt;

  Todo({
    required this.id,
    required this.title,
    this.completed = false,
    required this.createdAt,
  });

  Todo copyWith({
    String? id,
    String? title,
    bool? completed,
    DateTime? createdAt,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
        id: json['id'],
        title: json['title'],
        completed: json['completed'],
        createdAt: DateTime.parse(json['createdAt']),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Todo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// BLoC Events
abstract class TodoEvent {}

class LoadTodos extends TodoEvent {}

class AddTodo extends TodoEvent {
  final Todo todo;
  AddTodo(this.todo);
}

class UpdateTodo extends TodoEvent {
  final Todo todo;
  UpdateTodo(this.todo);
}

class DeleteTodo extends TodoEvent {
  final String todoId;
  DeleteTodo(this.todoId);
}

class ClearError extends TodoEvent {}

// Internal events for ABUS integration
class _OptimisticAdd extends TodoEvent {
  final Todo todo;
  _OptimisticAdd(this.todo);
}

class _OptimisticUpdate extends TodoEvent {
  final Todo todo;
  _OptimisticUpdate(this.todo);
}

class _OptimisticDelete extends TodoEvent {
  final String todoId;
  _OptimisticDelete(this.todoId);
}

class _CommitChanges extends TodoEvent {}

class _RollbackChanges extends TodoEvent {
  final List<Todo> previousTodos;
  final String error;
  _RollbackChanges(this.previousTodos, this.error);
}

class _SetLoading extends TodoEvent {
  final bool isLoading;
  _SetLoading(this.isLoading);
}

class _SetError extends TodoEvent {
  final String? error;
  _SetError(this.error);
}

// BLoC State
class TodoState {
  final List<Todo> todos;
  final bool isLoading;
  final String? error;

  const TodoState({
    this.todos = const [],
    this.isLoading = false,
    this.error,
  });

  TodoState copyWith({
    List<Todo>? todos,
    bool? isLoading,
    String? error,
  }) {
    return TodoState(
      todos: todos ?? this.todos,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoState &&
          runtimeType == other.runtimeType &&
          todos.length == other.todos.length &&
          todos.every((todo) => other.todos.contains(todo)) &&
          isLoading == other.isLoading &&
          error == other.error;

  @override
  int get hashCode => todos.hashCode ^ isLoading.hashCode ^ error.hashCode;
}

// BLoC with ABUS integration
class TodoBloc extends Bloc<TodoEvent, TodoState> with AbusBloc<TodoState> {
  // Store snapshots for rollback
  final Map<String, List<Todo>> _stateSnapshots = {};

  TodoBloc() : super(const TodoState()) {
    // Register standard event handlers
    on<LoadTodos>(_onLoadTodos);
    on<AddTodo>(_onAddTodo);
    on<UpdateTodo>(_onUpdateTodo);
    on<DeleteTodo>(_onDeleteTodo);
    on<ClearError>(_onClearError);

    // Register ABUS internal event handlers
    on<_OptimisticAdd>(_onOptimisticAdd);
    on<_OptimisticUpdate>(_onOptimisticUpdate);
    on<_OptimisticDelete>(_onOptimisticDelete);
    on<_CommitChanges>(_onCommitChanges);
    on<_RollbackChanges>(_onRollbackChanges);
    on<_SetLoading>(_onSetLoading);
    on<_SetError>(_onSetError);
  }

  // Standard BLoC event handlers
  void _onLoadTodos(LoadTodos event, Emitter<TodoState> emit) {
    // Initialize with some sample data
    final sampleTodos = [
      Todo(
        id: '1',
        title: 'Welcome to ABUS BLoC Demo',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Todo(
        id: '2',
        title: 'Try adding a new todo',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];
    emit(state.copyWith(todos: sampleTodos));
  }

  void _onAddTodo(AddTodo event, Emitter<TodoState> emit) {
    // This will be handled by ABUS optimistic updates
  }

  void _onUpdateTodo(UpdateTodo event, Emitter<TodoState> emit) {
    // This will be handled by ABUS optimistic updates
  }

  void _onDeleteTodo(DeleteTodo event, Emitter<TodoState> emit) {
    // This will be handled by ABUS optimistic updates
  }

  void _onClearError(ClearError event, Emitter<TodoState> emit) {
    emit(state.copyWith(error: null));
  }

  // ABUS internal event handlers
  void _onOptimisticAdd(_OptimisticAdd event, Emitter<TodoState> emit) {
    final updatedTodos = List<Todo>.from(state.todos)..add(event.todo);
    emit(state.copyWith(todos: updatedTodos, isLoading: true, error: null));
  }

  void _onOptimisticUpdate(_OptimisticUpdate event, Emitter<TodoState> emit) {
    final updatedTodos = state.todos.map((todo) {
      return todo.id == event.todo.id ? event.todo : todo;
    }).toList();
    emit(state.copyWith(todos: updatedTodos, isLoading: true, error: null));
  }

  void _onOptimisticDelete(_OptimisticDelete event, Emitter<TodoState> emit) {
    final updatedTodos =
        state.todos.where((todo) => todo.id != event.todoId).toList();
    emit(state.copyWith(todos: updatedTodos, isLoading: true, error: null));
  }

  void _onCommitChanges(_CommitChanges event, Emitter<TodoState> emit) {
    emit(state.copyWith(isLoading: false));
  }

  void _onRollbackChanges(_RollbackChanges event, Emitter<TodoState> emit) {
    emit(state.copyWith(
      todos: event.previousTodos,
      isLoading: false,
      error: event.error,
    ));
  }

  void _onSetLoading(_SetLoading event, Emitter<TodoState> emit) {
    emit(state.copyWith(isLoading: event.isLoading));
  }

  void _onSetError(_SetError event, Emitter<TodoState> emit) {
    emit(state.copyWith(error: event.error));
  }

  // ABUS Handler Implementation
  @override
  bool canHandle(InteractionDefinition interaction) {
    return interaction.tags.contains('todo');
  }

  @override
  Map<String, dynamic>? getCurrentState(InteractionDefinition interaction) {
    return {
      'todos': state.todos.map((t) => t.toJson()).toList(),
      'isLoading': state.isLoading,
      'error': state.error,
    };
  }

  @override
  Future<void> handleOptimistic(
      String interactionId, InteractionDefinition interaction) async {
    // Store current state for rollback
    _stateSnapshots[interactionId] = List.from(state.todos);

    final data = interaction.toJson()['data'] as Map<String, dynamic>;
    final action = data['action'] as String;

    add(_SetError(null));
    add(_SetLoading(true));

    switch (action) {
      case 'create':
        final payload = data['payload'] as Map<String, dynamic>;
        final todo = Todo.fromJson(payload);
        add(_OptimisticAdd(todo));
        break;

      case 'update':
        final todoId = data['resourceId'] as String;
        final payload = data['payload'] as Map<String, dynamic>;
        final existingTodo = state.todos.firstWhere((t) => t.id == todoId);
        final updatedTodo = existingTodo.copyWith(
          title: payload['title'],
          completed: payload['completed'],
        );
        add(_OptimisticUpdate(updatedTodo));
        break;

      case 'delete':
        final todoId = data['resourceId'] as String;
        add(_OptimisticDelete(todoId));
        break;
    }
  }

  @override
  Future<void> handleCommit(
      String interactionId, InteractionDefinition interaction) async {
    add(_CommitChanges());
    _stateSnapshots.remove(interactionId);
  }

  @override
  Future<void> handleRollback(
      String interactionId, InteractionDefinition interaction) async {
    final previousTodos = _stateSnapshots[interactionId];
    if (previousTodos != null) {
      add(_RollbackChanges(
          previousTodos, 'Operation failed - changes reverted'));
      _stateSnapshots.remove(interactionId);
    }
  }

  // If not required by the Bloc, it can be omitted
  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) {
    // This BLoC doesn't handle API calls directly - they're handled by the service
    return null;
  }

  @override
  Future<void> close() {
    _stateSnapshots.clear();
    return super.close();
  }
}

// Mock API Service
class TodoApiService {
  static final Random _random = Random();

  static Future<ABUSResult> handleTodoInteraction(
      InteractionDefinition interaction) async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 800 + _random.nextInt(400)));

    final data = interaction.toJson()['data'] as Map<String, dynamic>;
    final action = data['action'] as String;

    // Simulate occasional failures
    if (_random.nextDouble() < 0.25) {
      return ABUSResult.error(
        'Network error: Failed to $action todo',
        interactionId: interaction.id,
        metadata: {'action': action},
      );
    }

    switch (action) {
      case 'create':
        return ABUSResult.success(
          data: {'message': 'Todo created successfully'},
          interactionId: interaction.id,
          metadata: {'action': action},
        );

      case 'update':
        return ABUSResult.success(
          data: {'message': 'Todo updated successfully'},
          interactionId: interaction.id,
          metadata: {'action': action},
        );

      case 'delete':
        return ABUSResult.success(
          data: {'message': 'Todo deleted successfully'},
          interactionId: interaction.id,
          metadata: {'action': action},
        );

      default:
        return ABUSResult.error(
          'Unknown action: $action',
          interactionId: interaction.id,
        );
    }
  }
}

// Main Todo List Page
class TodoListPage extends StatefulWidget {
  const TodoListPage({super.key});

  @override
  _TodoListPageState createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> with AbusWidgetMixin {
  final TextEditingController _textController = TextEditingController();

  @override
  AbusUpdateConfig get abusConfig => const AbusUpdateConfig(
        tags: {'todo'},
        rebuildOnSuccess: true,
        rebuildOnError: true,
        rebuildOnRollback: true,
        debounceDelay: Duration(milliseconds: 100),
      );

  @override
  void initState() {
    super.initState();

    // Register the BLoC as a handler
    ABUS.registerHandler(context.read<TodoBloc>());

    // Register the API handler
    ABUS.registerApiHandler(TodoApiService.handleTodoInteraction);

    // Load initial todos
    context.read<TodoBloc>().add(LoadTodos());
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  void onAbusResult(ABUSResult result) {
    // Handle specific results
    if (result.isSuccess && result.metadata?['action'] != null) {
      _showSnackBar(
        result.data?['message'] ?? 'Operation completed',
        Colors.green,
      );
    } else if (!result.isSuccess && result.error != null) {
      final isRollback = result.metadata?['rollback'] == true;
      _showSnackBar(
        isRollback ? 'Changes reverted due to error' : result.error!,
        Colors.red,
      );
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _addTodo() async {
    final title = _textController.text.trim();
    if (title.isEmpty) return;

    final todo = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      createdAt: DateTime.now(),
    );

    final interaction = InteractionTypes.crud(
      action: 'create',
      resourceType: 'todo',
      payload: todo.toJson(),
    ).copyWith(tags: {'todo'});

    _textController.clear();

    try {
      await executeInteraction(interaction);
    } catch (e) {
      _showSnackBar('Failed to add todo: $e', Colors.red);
    }
  }

  Future<void> _toggleTodo(Todo todo) async {
    final interaction = InteractionTypes.crud(
      action: 'update',
      resourceType: 'todo',
      resourceId: todo.id,
      payload: {'completed': !todo.completed, 'title': todo.title},
    ).copyWith(tags: {'todo'});

    try {
      await executeInteraction(interaction);
    } catch (e) {
      _showSnackBar('Failed to update todo: $e', Colors.red);
    }
  }

  Future<void> _deleteTodo(Todo todo) async {
    final interaction = InteractionTypes.crud(
      action: 'delete',
      resourceType: 'todo',
      resourceId: todo.id,
    ).copyWith(tags: {'todo'});

    try {
      await executeInteraction(interaction);
    } catch (e) {
      _showSnackBar('Failed to delete todo: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TodoBloc, TodoState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('ABUS BLoC Demo'),
            actions: [
              if (state.isLoading)
                Container(
                  margin: const EdgeInsets.all(16),
                  width: 20,
                  height: 20,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showInfoDialog(),
              ),
            ],
          ),
          body: Column(
            children: [
              // Error banner
              if (state.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.red.shade100,
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.read<TodoBloc>().add(ClearError()),
                        child: const Text('DISMISS'),
                      ),
                    ],
                  ),
                ),

              // Add todo input
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'Enter a new todo...',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _addTodo(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addTodo,
                      child: const Text('ADD'),
                    ),
                  ],
                ),
              ),

              // Pending interactions info
              if (ABUS.manager.pendingCount > 0)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.sync, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${ABUS.manager.pendingCount} operation(s) in progress...',
                        style: TextStyle(
                            color: Colors.blue.shade700, fontSize: 12),
                      ),
                    ],
                  ),
                ),

              // Todo list
              Expanded(
                child: state.todos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.list_alt,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No todos yet',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const Text('Add one above to get started'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: state.todos.length,
                        itemBuilder: (context, index) {
                          final todo = state.todos[index];
                          return TodoListItem(
                            todo: todo,
                            onToggle: () => _toggleTodo(todo),
                            onDelete: () => _deleteTodo(todo),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ABUS BLoC Demo Features'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoItem(
                '🧱 BLoC Integration', 'Full BLoC pattern with ABUS'),
            _buildInfoItem('✨ Optimistic Updates', 'Changes appear instantly'),
            _buildInfoItem(
                '🔄 Auto Rollback', 'Failed operations revert automatically'),
            _buildInfoItem(
                '⚡ Error Simulation', '~25% of operations fail randomly'),
            _buildInfoItem('📱 BlocBuilder UI', 'Reactive UI updates via BLoC'),
            _buildInfoItem(
                '🎯 Smart Filtering', 'Only relevant updates trigger rebuilds'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// Todo List Item Widget
class TodoListItem extends StatelessWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const TodoListItem({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: todo.completed,
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration: todo.completed ? TextDecoration.lineThrough : null,
            color: todo.completed ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          'Created: ${_formatDate(todo.createdAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _showDeleteConfirmation(context),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Todo'),
        content: Text('Are you sure you want to delete "${todo.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// Extension for copyWith on InteractionDefinition
extension InteractionDefinitionExtension on InteractionDefinition {
  GenericInteraction copyWith({
    String? id,
    Map<String, dynamic>? data,
    InteractionDefinition? rollback,
    Duration? timeout,
    bool? supportsOptimistic,
    int? priority,
    Set<String>? tags,
  }) {
    if (this is GenericInteraction) {
      final generic = this as GenericInteraction;
      return GenericInteraction(
        id: id ?? generic.id,
        data: data ?? generic.toJson()['data'],
        rollback: rollback ?? generic.createRollback(),
        timeout: timeout ?? generic.timeout,
        supportsOptimistic: supportsOptimistic ?? generic.supportsOptimistic,
        priority: priority ?? generic.priority,
        tags: tags ?? generic.tags,
      );
    }

    // Fallback for other implementations
    return GenericInteraction(
      id: id ?? this.id,
      data: data ?? toJson(),
      rollback: rollback ?? createRollback(),
      timeout: timeout ?? this.timeout,
      supportsOptimistic: supportsOptimistic ?? this.supportsOptimistic,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
    );
  }
}
