# ABUS (Asynchronous Business Unified System) Documentation

## Overview

ABUS is a Flutter package that provides a unified architecture for handling asynchronous interactions with optimistic updates, automatic rollback capabilities, and flexible state management integration. It abstracts the complexity of coordinating UI updates with API calls while providing reliable error handling and recovery mechanisms.

## Core Concepts

### What Problem Does ABUS Solve?

In modern Flutter applications, developers frequently face challenges with:

1. **Optimistic Updates**: Updating the UI immediately while API calls execute in the background
2. **Error Recovery**: Rolling back UI changes when API calls fail
3. **State Coordination**: Managing multiple state management solutions (BLoC, Provider, etc.) consistently
4. **Timeout Handling**: Gracefully handling long-running operations
5. **Interaction Prioritization**: Managing the execution order of multiple concurrent operations

ABUS provides a centralized system that handles these concerns automatically while remaining agnostic to your chosen state management approach.

## Architecture Components

### 1. InteractionDefinition

The foundation of ABUS is the `InteractionDefinition` abstract class, which represents any business operation that might require state updates and API calls.

```dart
abstract class InteractionDefinition {
  String get id;                          // Unique identifier
  Map<String, dynamic> toJson();         // Serialization
  InteractionDefinition? createRollback(); // Optional rollback definition
  Duration? get timeout;                  // Operation timeout
  bool get supportsOptimistic;           // Optimistic update support
  int get priority;                      // Execution priority
  Set<String> get tags;                  // Categorization tags
  bool validate();                       // Validation logic
  List<String> getValidationErrors();    // Validation error details
}
```

**Key Features:**
- **Immutable Design**: Interactions are defined once and executed multiple times
- **Validation**: Built-in validation with detailed error reporting
- **Rollback Support**: Optional rollback definitions for complex operations
- **Prioritization**: Priority-based execution ordering
- **Tagging**: Flexible categorization system for filtering and organization

### 2. GenericInteraction

A concrete implementation of `InteractionDefinition` for common use cases:

```dart
final interaction = GenericInteraction(
  id: 'update_user_profile',
  data: {
    'userId': '123',
    'name': 'John Doe',
    'email': 'john@example.com'
  },
  timeout: Duration(seconds: 10),
  supportsOptimistic: true,
  priority: 1,
  tags: {'user', 'profile', 'update'}
);
```

### 3. InteractionBuilder

A fluent builder pattern for creating interactions:

```dart
final interaction = InteractionBuilder()
  .withId('create_post')
  .addData('title', 'My New Post')
  .addData('content', 'Post content here')
  .withTimeout(Duration(seconds: 15))
  .withOptimistic(true)
  .addTag('post')
  .addTag('create')
  .build();
```

### 4. AbusHandler Interface

The `AbusHandler` interface defines how different components of your application can participate in the ABUS system:

```dart
abstract class AbusHandler {
  String get handlerId;                   // Unique handler identifier

  // Lifecycle methods
  Future<void> handleOptimistic(String interactionId, InteractionDefinition interaction);
  Future<void> handleRollback(String interactionId, InteractionDefinition interaction);
  Future<void> handleCommit(String interactionId, InteractionDefinition interaction);

  // API execution
  Future<InteractionResult>? executeAPI(InteractionDefinition interaction);

  // Handler capabilities
  bool canHandle(InteractionDefinition interaction);
  Map<String, dynamic>? getCurrentState(InteractionDefinition interaction);
}
```

**Handler Types:**

- **AbusBloc**: Mixin for BLoC pattern integration
- **AbusProvider**: Mixin for Provider pattern integration
- **CustomAbusHandler**: Base class for custom implementations

### 5. ABUSManager

The central orchestrator that coordinates all interactions:

```dart
class ABUSManager {
  // Singleton instance
  static ABUSManager get instance;

  // Core execution method
  Future<InteractionResult> execute(
    InteractionDefinition interaction, {
    bool? optimistic,
    Duration? timeout,
    bool autoRollback = true,
    BuildContext? context,
  });

  // Handler management
  void registerHandler(AbusHandler handler);
  void registerApiHandler(Future<InteractionResult> Function(InteractionDefinition) handler);
  void discoverHandlers(BuildContext? context);

  // Rollback control
  Future<void> rollback(String interactionId);
  void confirmSuccess(String interactionId);

  // Status monitoring
  List<String> get pendingInteractions;
  bool isPending(String interactionId);
  Stream<InteractionResult> get resultStream;
}
```



## Execution Flow

### Standard Execution Flow

1. **Handler Discovery**: ABUS discovers compatible handlers for the interaction
2. **State Snapshot**: Current state is captured for potential rollback
3. **Optimistic Update** (if enabled): UI is updated immediately
4. **API Execution**: Actual API call is made
5. **Result Processing**:
   - **Success**: Changes are committed, rollback timer is set/cancelled
   - **Failure**: Optimistic changes are rolled back

### Rollback Mechanisms

ABUS provides multiple rollback triggers:

1. **Automatic Rollback**: Based on timeout configuration
2. **Manual Rollback**: Explicit rollback calls
3. **Error Rollback**: Automatic rollback on API failures

```dart
// Manual rollback
manager.rollback(interactionId);

// Confirm success to prevent auto-rollback
manager.confirmSuccess(interactionId);
```

## State Management Integration

### BLoC Integration

```dart
class UserBloc extends Bloc with AbusBloc {
  @override
  bool canHandle(InteractionDefinition interaction) {
    return interaction.tags.contains('user');
  }

  @override
  Future<void> handleOptimistic(String interactionId, InteractionDefinition interaction) async {
    if (interaction.id.startsWith('update_user')) {
      // Apply optimistic update to state
      emit(state.copyWith(user: updatedUser));
    }
  }

  @override
  Future<void> handleRollback(String interactionId, InteractionDefinition interaction) async {
    // Revert to previous state
    emit(previousState);
  }

  @override
  Future<InteractionResult> executeAPI(InteractionDefinition interaction) async {
    // Make actual API call
    final result = await userRepository.updateUser(interaction.data);
    return InteractionResult.success(data: result);
  }
}
```

### Provider Integration

```dart
class UserProvider extends ChangeNotifier with AbusProvider {
  User? _user;
  User? _previousUser;

  @override
  Future<void> handleOptimistic(String interactionId, InteractionDefinition interaction) async {
    _previousUser = _user;
    _user = User.fromJson(interaction.data);
    notifyListeners();
  }

  @override
  Future<void> handleRollback(String interactionId, InteractionDefinition interaction) async {
    _user = _previousUser;
    notifyListeners();
  }
}
```

## Advanced Features

### Handler Discovery

ABUS can automatically discover handlers from the Flutter widget tree:

```dart
// Automatic discovery
final result = await ABUS.executeWith(interaction, context);

// Manual discovery
manager.discoverHandlers(context);
```

### Priority-Based Execution

Interactions with higher priority values execute first:

```dart
final highPriorityInteraction = InteractionBuilder()
  .withId('critical_update')
  .withPriority(10)  // Higher priority
  .build();

final lowPriorityInteraction = InteractionBuilder()
  .withId('background_sync')
  .withPriority(1)   // Lower priority
  .build();
```

### Result Streaming

Monitor all interaction results:

```dart
manager.resultStream.listen((result) {
  if (result.isSuccess) {
    // Handle success
  } else {
    // Handle error
  }
});
```

### Custom Discovery Strategies

Implement custom handler discovery logic:

```dart
class CustomDiscoveryStrategy implements HandlerDiscoveryStrategy {
  @override
  List<AbusHandler> discoverHandlers(BuildContext? context) {
    // Custom discovery logic
    return foundHandlers;
  }
}

manager.setDiscoveryStrategy(CustomDiscoveryStrategy());
```

## Error Handling

ABUS provides comprehensive error handling:

### Validation Errors

```dart
final interaction = InteractionBuilder()
  .withData({}) // Empty data will fail validation
  .build(); // Throws ArgumentError with validation details
```

### Execution Errors

```dart
final result = await ABUS.execute(interaction);
if (!result.isSuccess) {
  print('Error: ${result.error}');
  // Optimistic updates are automatically rolled back
}
```

### Timeout Handling

```dart
final interaction = InteractionBuilder()
  .withId('long_operation')
  .withTimeout(Duration(seconds: 5))
  .build();

// Will timeout after 5 seconds and rollback optimistic changes
```

## Best Practices

### 1. Interaction Design

- Use descriptive, unique IDs that include context
- Include relevant tags for filtering and organization
- Set appropriate timeouts based on operation complexity
- Design rollback interactions for complex operations

### 2. Handler Implementation

- Implement `canHandle()` to filter relevant interactions
- Keep optimistic updates lightweight and fast
- Store previous state for reliable rollback
- Handle errors gracefully in all lifecycle methods

### 3. State Management

- Capture complete state snapshots for rollback
- Use immutable state patterns where possible
- Coordinate between multiple handlers carefully
- Validate state consistency after rollbacks

### 4. Performance Optimization

- Limit the number of registered handlers
- Use efficient state snapshot strategies
- Implement selective handler discovery
- Monitor pending interactions to prevent memory leaks

## Common Use Cases

### 1. User Profile Updates

```dart
final updateProfile = InteractionTypes.crud(
  action: InteractionTypes.update,
  resourceType: 'user',
  resourceId: userId,
  payload: {'name': newName, 'email': newEmail},
  optimistic: true,
);

final result = await ABUS.executeWith(updateProfile, context);
```

### 2. Real-time Data Synchronization

```dart
final syncData = InteractionBuilder()
  .withId('sync_messages')
  .addData('lastSyncTimestamp', lastSync.toIso8601String())
  .withOptimistic(false) // Don't update UI until confirmed
  .addTag('sync')
  .build();
```

### 3. Complex Multi-Step Operations

```dart
final createPost = InteractionBuilder()
  .withId('create_post_with_images')
  .addData('post', postData)
  .addData('images', imageList)
  .withTimeout(Duration(minutes: 2))
  .withRollback(deletePostInteraction) // Custom rollback
  .build();
```

## Testing

ABUS is designed to be testable:

```dart
// Reset manager between tests
ABUSManager.reset();

// Mock handlers for testing
class MockUserHandler extends CustomAbusHandler {
  @override
  Future<InteractionResult> executeAPI(InteractionDefinition interaction) async {
    return InteractionResult.success(data: {'userId': '123'});
  }
}

// Register mock handler
ABUS.registerHandler(MockUserHandler());
```

## Migration and Integration

ABUS can be gradually integrated into existing applications:

1. **Start with API-only handlers** - No state management changes required
2. **Add optimistic updates gradually** - Implement `AbusHandler` mixins on existing classes
3. **Leverage automatic discovery** - Pass `BuildContext` to enable automatic handler detection
4. **Extend with custom interactions** - Create domain-specific interaction types

The package is designed to coexist with existing patterns and can be adopted incrementally without requiring a complete architectural overhaul.