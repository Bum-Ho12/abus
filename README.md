# ABUS - A-synchronous Business Unified System
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue.svg)](https://flutter.dev)

A unified Flutter package for handling asynchronous operations with built-in optimistic updates, automatic rollback, and seamlessly integrated feedback and storage capabilities.

![ABUS Flow](doc/ABUS_flow.svg)

## Key Features

- 🚀 **Optimistic Updates** - Instant UI responses with automatic rollback on failure
- 💬 **Core Feedback System** - Built-in, persistent managed feedback queue (Toasts, Snobars, Banners)
- 💾 **Cross-App Communication** - Synchronize state and events across apps using shared storage
- 🔄 **Universal Integration** - Works with BLoC, Provider, setState, or any state management
- 🛡️ **Race Condition Prevention** - Intelligent operation queuing
- 🎯 **Type-Safe Operations** - Define operations once, use everywhere
- 🔧 **Zero Boilerplate** - Minimal setup, maximum functionality

## Quick Start

### Installation

```yaml
dependencies:
  abus: ^0.0.7
```

### 1. Unified Setup

Initialize ABUS with the integrated Storage and Feedback systems for the full experience.

```dart
void main() async {
  // 1. Configure shared storage (optional but recommended for persistence/cross-app)
  final storage = AndroidSharedStorage(
    Directory('/sdcard/Android/data/com.example/files'),
    syncInterval: Duration(seconds: 5),
  );

  // 2. Initialize ABUS components
  ABUS.setStorage(storage);
  await FeedbackBus.initialize(storage: storage);

  runApp(MyApp());
}
```

### 2. Core Usage Flow

Execute operations that update the UI instantly and automatically handle feedback.

```dart
// Define an operation
final interaction = InteractionTypes.crud(
  action: 'create',
  resourceType: 'user',
  payload: {'name': 'John'},
);

// Execute: Optimistic update -> API Call -> Feedback
final result = await ABUS.execute(interaction);

if (result.isSuccess) {
  // Show persistent feedback automatically managed by the system
  FeedbackBus.showSnackbar(
    message: 'User created successfully',
    type: SnackbarType.success,
    actionLabel: 'UNDO',
    onAction: () => undoCreate(),
  );
}
```

### 3. Widget Integration

React to both data changes and feedback events in one place using `AbusWidgetMixin` and `FeedbackWidgetMixin`.

```dart
class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> with AbusWidgetMixin, FeedbackWidgetMixin {
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Your main content
          ListView(children: [/*...*/]),
          
          // Render persistent banners from the feedback queue
          Column(
             children: bannerEvents.map((e) => MaterialBanner(/*...*/)).toList(),
          ),
        ],
      ),
    );
  }

  @override
  void onFeedbackQueueChanged(List<FeedbackEvent> queue) {
    // Check for new snackbars in the queue
    final latest = snackbarEvents.lastOrNull;
    if (latest != null && !isShown(latest.id)) {
      ScaffoldMessenger.of(context).showSnackBar(/*...*/);
      markAsShown(latest.id);
    }
  }
}
```

## Deep Integration

### State Management (BLoC Example)

ABUS handlers integrate deeply with your state management to handle optimistic updates and rollbacks.

```dart
class UserBloc extends Bloc<UserEvent, UserState> with AbusBloc<UserState> {
  // ... configuration ...

  @override
  Future<void> handleOptimistic(String id, InteractionDefinition interaction) async {
    // 1. Update state immediately
    emit(state.copyWith(loading: true, tempUser: interaction.payload));
  }

  @override
  Future<ABUSResult> executeAPI(InteractionDefinition interaction) async {
    try {
      // 2. Perform actual API call
      return await api.createUser(interaction.payload);
    } catch (e) {
      // 3. System automatically triggers handleRollback on failure
      return ABUSResult.error(e.toString());
    }
  }
}
```

### Storage & Cross-App Sync

Enable powerful multi-app workflows where events in one app (e.g., a background service) are instantly reflected in another.

```dart
// App A (Background Service)
await FeedbackBus.showBanner(
  message: 'Background Sync Complete',
  priority: 10
);

// App B (Foreground UI)
// Automatically receives the banner event via AndroidSharedStorage 
// and updates the UI through FeedbackWidgetMixin.
```
[Read full documentation on Cross-App Communication](DOCs.md#storage--cross-app-communication)

## Documentation

- 📖 [Full Documentation](DOCs.md)
  - [Feedback System Details](DOCs.md#feedback-system)
  - [Storage Internals](DOCs.md#storage--cross-app-communication)
- 🎯 [API Reference](https://pub.dev/documentation/abus/latest/)
- 💡 [Example App](https://github.com/Bum-Ho12/abus/tree/main/example)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
