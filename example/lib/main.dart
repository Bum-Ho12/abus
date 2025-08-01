// main.dart
import 'package:flutter/material.dart';
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
      title: 'ABUS Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const TodoListPage(),
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
}

// Custom State Handler using CustomAbusHandler
class TodoStateHandler extends CustomAbusHandler {
  List<Todo> _todos = [];
  bool _isLoading = false;
  String? _error;

  // Callback for notifying UI of state changes
  void Function()? onStateChanged;

  List<Todo> get todos => List.unmodifiable(_todos);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Store previous states for rollback
  final Map<String, Map<String, dynamic>> _stateSnapshots = {};

  @override
  bool canHandle(InteractionDefinition interaction) {
    return interaction.tags.contains('todo');
  }

  @override
  Map<String, dynamic>? getCurrentState(InteractionDefinition interaction) {
    return {
      'todos': _todos.map((t) => t.toJson()).toList(),
      'isLoading': _isLoading,
      'error': _error,
    };
  }

  @override
  Future<void> handleOptimistic(
      String interactionId, InteractionDefinition interaction) async {
    // Store current state for rollback
    _stateSnapshots[interactionId] = {
      'todos': _todos.map((t) => t.toJson()).toList(),
      'isLoading': _isLoading,
      'error': _error,
    };

    final data = interaction.toJson()['data'] as Map<String, dynamic>;
    final action = data['action'] as String;

    _error = null;
    _isLoading = true;

    switch (action) {
      case 'create':
        final payload = data['payload'] as Map<String, dynamic>;
        final todo = Todo.fromJson(payload);
        _todos.add(todo);
        break;

      case 'update':
        final todoId = data['resourceId'] as String;
        final payload = data['payload'] as Map<String, dynamic>;
        final index = _todos.indexWhere((t) => t.id == todoId);
        if (index != -1) {
          _todos[index] = _todos[index].copyWith(
            title: payload['title'],
            completed: payload['completed'],
          );
        }
        break;

      case 'delete':
        final todoId = data['resourceId'] as String;
        _todos.removeWhere((t) => t.id == todoId);
        break;
    }

    _notifyStateChanged();
  }

  @override
  Future<void> handleCommit(
      String interactionId, InteractionDefinition interaction) async {
    _isLoading = false;
    _stateSnapshots.remove(interactionId);
    _notifyStateChanged();
  }

  @override
  Future<void> handleRollback(
      String interactionId, InteractionDefinition interaction) async {
    final previousState = _stateSnapshots[interactionId];
    if (previousState != null) {
      // Restore previous state
      final todosList = previousState['todos'] as List<dynamic>;
      _todos = todosList
          .map((json) => Todo.fromJson(json as Map<String, dynamic>))
          .toList();
      _isLoading = previousState['isLoading'] as bool;
      _error = 'Operation failed - changes reverted';
      _stateSnapshots.remove(interactionId);
      _notifyStateChanged();
    }
  }

  // If not required, it can be omitted
  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) {
    // This handler doesn't handle API calls directly - we use the global handler
    return null;
  }

  void clearError() {
    _error = null;
    _notifyStateChanged();
  }

  void _notifyStateChanged() {
    onStateChanged?.call();
  }

  // Clean up method
  void dispose() {
    _stateSnapshots.clear();
    onStateChanged = null;
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
    if (_random.nextDouble() < 0.2) {
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
  late TodoStateHandler _todoHandler;
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
    _todoHandler = TodoStateHandler();

    // Set up state change callback to trigger UI rebuilds
    _todoHandler.onStateChanged = () {
      if (mounted) {
        setState(() {});
      }
    };

    // Register the handler
    ABUS.registerHandler(_todoHandler);

    // Register the API handler
    ABUS.registerApiHandler(TodoApiService.handleTodoInteraction);
  }

  @override
  void dispose() {
    _textController.dispose();
    _todoHandler.dispose();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('ABUS Todo Demo'),
        actions: [
          if (_todoHandler.isLoading)
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
          if (_todoHandler.error != null)
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
                      _todoHandler.error!,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ),
                  TextButton(
                    onPressed: _todoHandler.clearError,
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

          // Todo list
          Expanded(
            child: _todoHandler.todos.isEmpty
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
                    itemCount: _todoHandler.todos.length,
                    itemBuilder: (context, index) {
                      final todo = _todoHandler.todos[index];
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
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ABUS Demo Features'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoItem('✨ Optimistic Updates', 'Changes appear instantly'),
            _buildInfoItem(
                '🔄 Auto Rollback', 'Failed operations revert automatically'),
            _buildInfoItem(
                '⚡ Error Simulation', '~20% of operations fail randomly'),
            _buildInfoItem(
                '📱 Real-time UI', 'Live updates via custom state handler'),
            _buildInfoItem(
                '🎯 Smart Filtering', 'Only relevant updates trigger rebuilds'),
            _buildInfoItem(
                '🛠️ CustomAbusHandler', 'No ChangeNotifier dependency'),
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
