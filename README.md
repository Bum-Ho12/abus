
# ABus - Action Bus Interaction Manager

ABus (Action Bus) is a flexible interaction manager designed to orchestrate UI state changes, API interactions, optimistic updates, and rollback capabilities across BLoC, Provider, or any custom state management system.

## Features

- Define interactions with validation, priority, tags, and rollback logic.
- Auto-discover state handlers from context (BLoC, Provider, or custom).
- Supports optimistic updates and timed rollback.
- Register multiple API handlers.
- Lightweight and no external dependency requirements.

## Installation

1. Clone or copy the `abus` package folder into your `packages` directory or local project path.
2. In your `pubspec.yaml`:

```
dependencies:
  abus:
    path: ../relative/path/to/abus
```

## Usage

### 1. Define an interaction

```dart
final interaction = GenericInteraction(
  id: 'create_post',
  data: {'title': 'My post', 'content': 'Hello'},
);
```

Or use the builder:

```dart
final interaction = ABUS.builder()
  .withId('create_post')
  .addData('title', 'My post')
  .addData('content', 'Hello')
  .withOptimistic(true)
  .build();
```

### 2. Register API handler

```dart
ABUS.registerApiHandler((interaction) async {
  // Handle API call here
  return InteractionResult.success(data: {'status': 'ok'});
});
```

### 3. Register state handler (BLoC or Provider)

Your BLoC or ChangeNotifier must mix in `AbusBloc` or `AbusProvider`:

```dart
class PostBloc extends Cubit<PostState> with AbusBloc<PostState> {
  @override
  Future<void> handleOptimistic(String id, interaction) async {
    // Apply temporary state change
  }

  @override
  Future<void> handleRollback(String id, interaction) async {
    // Revert state
  }

  @override
  Future<void> handleCommit(String id, interaction) async {
    // Commit state permanently
  }
}
```

Then register it:

```dart
ABUS.registerHandler(postBloc);
```

### 4. Execute interaction

```dart
final result = await ABUS.execute(interaction);

if (result.isSuccess) {
  print('Success!');
} else {
  print('Failed: ${result.error}');
}
```

Or use context-based execution:

```dart
final result = await ABUS.executeWith(interaction, context);
```

## Use Cases

- Optimistic UI updates with rollback support.
- Centralized handling of all interaction types (create, update, delete, sync).
- Works with or without a state management library.

## License

MIT

---

Built for flexibility and power. Perfect for any app needing rich user interaction handling.
