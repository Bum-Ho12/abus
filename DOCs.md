# ABUS - Asynchronous Business Logic Unification System

## Overview

ABUS (Asynchronous Business Logic Unification System) is a comprehensive Flutter package that provides a unified approach to handling asynchronous operations, state management, and API interactions with built-in optimistic updates, rollback capabilities, and error handling.

## Core Concept

ABUS implements an **optimistic-first architecture** where:
1. UI updates happen immediately (optimistic updates)
2. API calls execute in the background
3. Changes are automatically rolled back if the API fails
4. Success confirmations prevent rollbacks

This approach provides excellent user experience while maintaining data consistency.

## Key Features

### 🚀 Optimistic Updates
- Immediate UI feedback without waiting for API responses
- Automatic rollback on API failures
- Configurable rollback timeouts

### 🔄 State Management Integration
- Works with BLoC, Provider, and custom state management solutions
- Mixin-based approach for easy integration
- Automatic widget rebuilds on interaction results

### ⚡ Interaction Queue
- Prevents race conditions with automatic queuing
- Priority-based execution
- Duplicate interaction prevention

### 🎯 Flexible Handler System
- Multiple handler types (BLoC, Provider, Custom)
- Global and local API handlers
- Handler-specific validation and execution

### 📊 Result Streaming
- Real-time interaction result broadcasting
- Filterable result streams
- Debounced widget updates

## Core Architecture

### 1. Interaction Definitions (`InteractionDefinition`)
The foundation of ABUS - defines what operation should be performed.

```dart
abstract class InteractionDefinition {
  String get id;                    // Unique identifier
  Map<String, dynamic> toJson();    // Serialization
  InteractionDefinition? createRollback();  // Optional rollback definition
  Duration? get timeout;            // Operation timeout
  bool get supportsOptimistic;      // Optimistic update support
  int get priority;                 // Execution priority
  Set<String> get tags;             // Categorization tags
}
```

**Key Features:**
- **Immutable Operations**: Each interaction is a complete description of an operation
- **Self-Contained**: Includes all necessary data and metadata
- **Rollback Support**: Optional rollback definitions for complex operations
- **Priority System**: High-priority operations execute first
- **Tagging**: Categorize operations for filtering and handling

### 2. Handler System (`AbusHandler`)
Handles the actual execution of interactions across different state management patterns.

```dart
abstract class AbusHandler {
  String get handlerId;
  bool canHandle(InteractionDefinition interaction);
  Future<void> handleOptimistic(String interactionId, InteractionDefinition interaction);
  Future<void> handleRollback(String interactionId, InteractionDefinition interaction);
  Future<void> handleCommit(String interactionId, InteractionDefinition interaction);
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction);
  Map<String, dynamic>? getCurrentState(InteractionDefinition interaction);
}
```

**Handler Types:**
- **AbusBloc**: Mixin for BLoC pattern integration
- **AbusProvider**: Mixin for Provider pattern integration
- **CustomAbusHandler**: For custom state management solutions

### 3. Manager (`ABUSManager`)
The central orchestrator that coordinates all operations.

**Core Responsibilities:**
- **Handler Registration**: Manages all registered handlers
- **Operation Queuing**: Prevents race conditions through intelligent queuing
- **State Snapshots**: Captures state before operations for rollback capability
- **Memory Management**: Automatic cleanup of old snapshots and timers
- **Result Broadcasting**: Streams results to interested components

## Execution Flow

### Standard Flow
1. **Define Interaction**: Create an `InteractionDefinition` describing the operation
2. **Handler Discovery**: Manager finds compatible handlers
3. **State Snapshot**: Current state captured for potential rollback
4. **Optimistic Update**: UI updated immediately (if enabled)
5. **API Execution**: Actual API call performed
6. **Success/Failure Handling**:
   - **Success**: Changes committed, snapshot cleaned up
   - **Failure**: Automatic rollback to previous state

### Optimistic Updates Flow
```dart
// 1. User triggers action
final interaction = InteractionTypes.crud(
  action: 'update',
  resourceType: 'user',
  resourceId: '123',
  payload: {'name': 'New Name'},
);

// 2. Immediate UI update
await ABUS.execute(interaction);
// UI shows "New Name" immediately

// 3. If API fails, automatic rollback
// UI reverts to previous state
```

## Key Features

### 🚀 Optimistic Updates
- **Immediate UI Response**: Users see changes instantly
- **Automatic Rollback**: Failed operations automatically revert
- **State Preservation**: Previous state captured and restored perfectly
- **Configurable**: Can be disabled per interaction or globally

### 🔒 Race Condition Prevention
- **Operation Queuing**: Prevents concurrent operations with same ID
- **Priority System**: Important operations execute first
- **Timeout Handling**: Operations that take too long are automatically handled

### 🎯 Flexible Handler System
- **Multi-Pattern Support**: Works with BLoC, Provider, setState, or custom patterns
- **Handler Discovery**: Automatic discovery of handlers in widget tree
- **Manual Registration**: Explicit handler registration for better control

### 📊 Memory Management
- **Snapshot Limits**: Automatic cleanup of old state snapshots
- **Timer Management**: Automatic cleanup of rollback timers
- **Resource Cleanup**: Proper disposal prevents memory leaks

### 🔍 Comprehensive Result System
```dart
class ABUSResult {
  final bool isSuccess;
  final Map<String, dynamic>? data;
  final String? error;
  final DateTime timestamp;
  final String? interactionId;
  final Map<String, dynamic>? metadata;
}
```

## Usage Examples

### Basic CRUD Operations
```dart
// Create
final createUser = InteractionTypes.crud(
  action: 'create',
  resourceType: 'user',
  payload: {'name': 'John', 'email': 'john@example.com'},
);

// Update with optimistic updates
final updateUser = InteractionTypes.crud(
  action: 'update',
  resourceType: 'user',
  resourceId: '123',
  payload: {'name': 'Jane'},
  optimistic: true,
);

// Execute
final result = await ABUS.execute(updateUser);
```

### Custom Interactions
```dart
final customInteraction = ABUS.builder()
  .withId('sync_user_data')
  .addData('userId', '123')
  .addData('includePreferences', true)
  .withTimeout(Duration(seconds: 30))
  .withPriority(1)
  .addTag('sync')
  .addTag('critical')
  .build();

final result = await ABUS.execute(customInteraction);
```

### Widget Integration
```dart
class UserProfile extends StatefulWidget {
  @override
  _UserProfileState createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> with AbusWidgetMixin {
  @override
  AbusUpdateConfig get abusConfig => AbusUpdateConfig(
    tags: {'user', 'profile'},
    debounceDelay: Duration(milliseconds: 300),
    rebuildOnSuccess: true,
  );

  @override
  void onAbusResult(ABUSResult result) {
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${result.error}')),
      );
    }
  }

  void updateUser() {
    final interaction = InteractionTypes.crud(
      action: 'update',
      resourceType: 'user',
      payload: {'name': newName},
    );

    executeInteraction(interaction);
  }
}
```

### Handler Implementation
```dart
class UserBloc extends Bloc<UserEvent, UserState> with AbusBloc {
  @override
  bool canHandle(InteractionDefinition interaction) {
    return interaction.toJson()['data']?['resourceType'] == 'user';
  }

  @override
  Future<void> handleOptimistic(String interactionId, InteractionDefinition interaction) async {
    final data = interaction.toJson()['data'] as Map<String, dynamic>;

    if (data['action'] == 'update') {
      // Update state optimistically
      final updatedUser = state.user.copyWith(name: data['payload']['name']);
      emit(state.copyWith(user: updatedUser));
    }
  }

  @override
  Future<ABUSResult> executeAPI(InteractionDefinition interaction) async {
    final data = interaction.toJson()['data'] as Map<String, dynamic>;

    try {
      final response = await userRepository.updateUser(
        data['resourceId'],
        data['payload'],
      );

      return ABUSResult.success(data: response);
    } catch (e) {
      return ABUSResult.error(e.toString());
    }
  }

  @override
  Future<void> handleRollback(String interactionId, InteractionDefinition interaction) async {
    // Revert to previous state
    emit(previousState);
  }
}
```

## Configuration Options

### Global Configuration
```dart
void main() {
  // Register global API handlers
  ABUS.registerApiHandler((interaction) async {
    // Global API handling logic
    return await apiService.execute(interaction);
  });

  runApp(MyApp());
}
```

### Per-Widget Configuration
```dart
@override
AbusUpdateConfig get abusConfig => AbusUpdateConfig(
  interactionIds: {'user_update', 'profile_sync'},
  tags: {'critical'},
  rebuildOnSuccess: true,
  rebuildOnError: true,
  rebuildOnRollback: true,
  debounceDelay: Duration(milliseconds: 200),
  onlyWhenVisible: true,
  customFilter: (result) => result.metadata?['priority'] == 'high',
);
```

## Advanced Features

### Manual Rollback Control
```dart
// Execute with manual rollback control
final result = await ABUS.execute(interaction, autoRollback: false);

if (result.isSuccess) {
  // Confirm success to prevent auto-rollback
  ABUS.manager.confirmSuccess(result.interactionId!);
} else {
  // Manual rollback if needed
  await ABUS.manager.rollback(result.interactionId!);
}
```

### Priority-Based Execution
```dart
final highPriorityInteraction = ABUS.builder()
  .withId('critical_update')
  .withPriority(10)  // Higher priority
  .build();

final lowPriorityInteraction = ABUS.builder()
  .withId('background_sync')
  .withPriority(1)   // Lower priority
  .build();

// High priority executes first even if queued later
```

### Result Stream Monitoring
```dart
ABUS.manager.resultStream.listen((result) {
  if (!result.isSuccess) {
    analyticsService.recordError(result.error);
  }

  if (result.metadata?['tags']?.contains('critical') == true) {
    notificationService.show('Critical operation completed');
  }
});
```

## Best Practices

### 1. Interaction Design
- Use descriptive IDs that indicate the operation
- Include all necessary data in the interaction
- Use tags for categorization and filtering
- Set appropriate timeouts for operations

### 2. Handler Implementation
- Implement specific `canHandle` logic to avoid conflicts
- Handle errors gracefully in optimistic updates
- Provide meaningful rollback implementations
- Use proper error handling in API execution

### 3. Widget Integration
- Configure update filters to prevent unnecessary rebuilds
- Use debouncing for frequently changing data
- Handle errors in `onAbusResult` for user feedback
- Implement proper loading states

### 4. Memory Management
- Dispose managers properly when no longer needed
- Use appropriate snapshot limits for your use case
- Clean up handlers when components are destroyed

## Error Handling

### Automatic Error Handling
- Failed API calls trigger automatic rollback
- Timeout operations are handled gracefully
- Invalid interactions are caught during validation

### Manual Error Handling
```dart
final result = await ABUS.execute(interaction);

if (!result.isSuccess) {
  switch (result.error) {
    case 'Timeout':
      showRetryDialog();
      break;
    case 'Network Error':
      showOfflineMessage();
      break;
    default:
      showGenericError(result.error);
  }
}
```

## Testing

### Unit Testing Handlers
```dart
test('should handle user update optimistically', () async {
  final handler = UserBloc();
  final interaction = InteractionTypes.crud(
    action: 'update',
    resourceType: 'user',
    payload: {'name': 'Test'},
  );

  await handler.handleOptimistic('test_id', interaction);

  expect(handler.state.user.name, equals('Test'));
});
```

### Integration Testing
```dart
testWidgets('should update UI optimistically', (tester) async {
  await tester.pumpWidget(MyApp());

  await tester.tap(find.byKey(Key('update_button')));
  await tester.pump(); // Don't wait for API

  expect(find.text('Updated Name'), findsOneWidget);
});
```

## Migration Guide

### From Manual State Management
1. Wrap existing API calls in interaction definitions
2. Implement handlers for your current state management pattern
3. Replace direct state updates with ABUS execution
4. Add optimistic update logic gradually

### From Other Async Libraries
1. Map existing operations to interaction definitions
2. Replace callback-based APIs with ABUS handlers
3. Utilize built-in error handling and rollback capabilities
4. Migrate widgets to use AbusWidgetMixin for automatic updates

## Conclusion

ABUS provides a comprehensive solution for handling asynchronous operations in Flutter applications. By unifying different state management patterns under a single interface, providing built-in optimistic updates and rollback capabilities, and offering sophisticated error handling, ABUS significantly reduces complexity while improving user experience.

The system is designed to be incrementally adoptable, allowing teams to migrate existing code gradually while immediately benefiting from improved async operation handling. Whether you're building a simple app or a complex enterprise application, ABUS provides the tools and patterns needed for robust, responsive user interfaces.
