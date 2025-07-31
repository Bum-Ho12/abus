# ABUS 🚀

[![pub package](https://img.shields.io/pub/v/abus.svg)](https://pub.dev/packages/abus)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue.svg)](https://flutter.dev)

**Advanced Business User State** - A Flutter package for managing complex user interactions with optimistic updates, automatic rollbacks, and seamless API integration.

## ✨ Features

- 🚀 **Optimistic Updates** - Immediate UI feedback without waiting for API responses
- 🔄 **Automatic Rollbacks** - Smart recovery when API calls fail
- ⚡ **State Management Agnostic** - Works with BLoC, Provider, or custom solutions
- 🎯 **Interaction Queue** - Prevents race conditions with priority-based execution
- 📊 **Real-time Results** - Stream-based result broadcasting to widgets
- 🛡️ **Memory Efficient** - Built-in memory management and cleanup
- 🧪 **Testing Friendly** - Easy to mock and test interactions

## 🎯 Perfect For

- **Collaborative Apps** - Real-time editing with conflict resolution
- **Social Media** - Instant likes, comments, and posts
- **E-commerce** - Cart updates, wishlist management
- **Productivity Tools** - Document editing, task management
- **Any app requiring immediate feedback** with reliable backend sync

## 🚀 Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  abus: ^1.0.0
```

### Basic Usage

```dart
import 'package:abus/abus.dart';

// 1. Create an interaction
final interaction = ABUS.builder()
  .withId('update_profile')
  .withData({'name': 'John Doe', 'email': 'john@example.com'})
  .build();

// 2. Execute with optimistic updates
final result = await ABUS.execute(interaction);

if (result.isSuccess) {
  print('Profile updated successfully!');
} else {
  print('Error: ${result.error}');
}
```

### With BLoC Integration

```dart
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> 
    with AbusBloc<ProfileState> {
  
  @override
  Future<void> handleOptimistic(String interactionId, InteractionDefinition interaction) async {
    // Update UI immediately
    if (interaction.id == 'update_profile') {
      final data = interaction.toJson()['data'];
      add(UpdateProfileOptimistic(data['name']));
    }
  }

  @override
  Future<void> handleRollback(String interactionId, InteractionDefinition interaction) async {
    // Revert changes if API fails
    add(RollbackProfileUpdate());
  }

  @override
  Future<ABUSResult> executeAPI(InteractionDefinition interaction) async {
    // Make API call
    try {
      final result = await profileApi.update(interaction.toJson()['data']);
      return ABUSResult.success(data: result);
    } catch (e) {
      return ABUSResult.error(e.toString());
    }
  }
}

// Register the handler
ABUS.registerHandler(ProfileBloc());
```

### Widget Integration

```dart
class ProfileWidget extends StatefulWidget {
  @override
  _ProfileWidgetState createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget> 
    with AbusWidgetMixin {
  
  @override
  AbusUpdateConfig get abusConfig => AbusUpdateConfig(
    tags: {'profile'},
    rebuildOnError: true,
  );

  @override
  void onAbusResult(ABUSResult result) {
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${result.error}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final interaction = ABUS.builder()
          .withId('update_profile')
          .withData({'name': 'Updated Name'})
          .build();
          
        await executeInteraction(interaction);
      },
      child: Text('Update Profile'),
    );
  }
}
```

## 🔧 How It Works

1. **Optimistic Update**: UI updates immediately when interaction is triggered
2. **Background API**: API call executes asynchronously
3. **Smart Recovery**: If API fails, changes are automatically rolled back
4. **Confirmation**: Successful API calls confirm the optimistic changes

```
User Action → Optimistic Update → API Call → Success/Rollback
     ↓              ↓               ↓            ↓
   Instant       UI Updates    Background    Final State
  Feedback                                      
```

## 🎨 Advanced Features

### Custom Interactions

```dart
class CreatePostInteraction extends InteractionDefinition {
  final String title;
  final String content;

  CreatePostInteraction({required this.title, required this.content});

  @override
  String get id => 'create_post';
  
  @override
  Map<String, dynamic> toJson() => {'title': title, 'content': content};
  
  @override
  bool validate() => title.isNotEmpty && content.isNotEmpty;
}
```

### Priority-Based Execution

```dart
final urgentUpdate = ABUS.builder()
  .withId('emergency_save')
  .withPriority(100)  // Higher priority
  .withData(criticalData)
  .build();
```

### Global API Handler

```dart
ABUS.registerApiHandler((interaction) async {
  switch (interaction.id) {
    case 'sync_data':
      return await syncService.sync();
    case 'upload_file':
      return await fileService.upload(interaction.toJson()['data']);
    default:
      throw Exception('Unknown interaction: ${interaction.id}');
  }
});
```

## 📖 State Management Support

| Pattern      | Support  | Mixin               |
| ------------ | -------- | ------------------- |
| **BLoC**     | ✅ Full   | `AbusBloc<State>`   |
| **Provider** | ✅ Full   | `AbusProvider`      |
| **Riverpod** | ✅ Custom | `CustomAbusHandler` |
| **GetX**     | ✅ Custom | `CustomAbusHandler` |
| **Custom**   | ✅ Full   | `CustomAbusHandler` |

## 🧪 Testing

```dart
testWidgets('Profile update interaction', (tester) async {
  final mockHandler = MockProfileHandler();
  ABUS.registerHandler(mockHandler);
  
  final interaction = ABUS.builder()
    .withId('update_profile')
    .withData({'name': 'Test User'})
    .build();

  final result = await ABUS.execute(interaction);
  
  expect(result.isSuccess, isTrue);
  verify(mockHandler.handleOptimistic(any, any)).called(1);
});
```

## 📚 Documentation

- **[Complete Documentation](DOCS.md)** - Comprehensive guide with examples
- **[API Reference](https://pub.dev/documentation/abus)** - Detailed API documentation
- **[Migration Guide](DOCS.md#migration-guide)** - Migrate from existing solutions
- **[Best Practices](DOCS.md#best-practices)** - Recommended usage patterns

## 🤔 Why ABUS?

### Traditional Approach 😓
```dart
// User clicks button
showLoading();
try {
  final result = await api.updateProfile(data);
  hideLoading();
  updateUI(result);
} catch (e) {
  hideLoading();
  showError(e);
}
// User waits... and waits... 😴
```

### ABUS Approach 🚀
```dart
// User clicks button
final result = await ABUS.execute(updateInteraction);
// UI updates INSTANTLY! ⚡
// API handles in background
// Auto-rollback if needed
```

## 🔄 Migration

### From setState
```dart
// Before
setState(() {
  isLoading = true;
});
try {
  await api.update();
  setState(() {
    isLoading = false;
    // update state
  });
} catch (e) {
  setState(() {
    isLoading = false;
    error = e.toString();
  });
}

// After
await ABUS.execute(updateInteraction);
// That's it! 🎉
```

## 🏆 Examples

Check out our example apps:

- **[Todo App](example/todo_app)** - Simple task management with optimistic updates
- **[Chat App](example/chat_app)** - Real-time messaging with BLoC
- **[E-commerce](example/ecommerce)** - Shopping cart with Provider
- **[Collaborative Editor](example/editor)** - Document editing with conflict resolution

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Support

- 📖 [Documentation](DOCS.md)
- 🐛 [Issue Tracker](https://github.com/yourorg/abus/issues)
- 💬 [Discussions](https://github.com/yourorg/abus/discussions)
- 📧 Email: support@yourorg.com

## ⭐ Show Your Support

If ABUS helps you build better Flutter apps, please give it a star! ⭐

---

**Made with ❤️ for the Flutter community**