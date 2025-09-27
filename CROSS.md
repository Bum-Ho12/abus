# ABUS Cross-App Communication Setup Guide

The ABUS cross-app communication system enables secure communication between Flutter applications on the same device through various mechanisms like intents, URL schemes, and data sharing.

## Overview

The cross-app system consists of:
- **AppCommunicationManager**: Core handler for cross-app operations
- **AppEvent**: Base class for different types of cross-app events
- **CrossAppBus**: Main API for cross-app communication
- **Permission System**: Security layer for controlling app interactions

## Installation & Setup

### 1. Basic Initialization

Initialize the cross-app communication system in your app's main function:

```dart
import 'package:abus/abus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize cross-app communication
  await CrossAppBus.initialize(
    appId: 'com.yourcompany.yourapp',
    permissions: {
      AppPermission.send.permission,
      AppPermission.receive.permission,
      AppPermission.dataShare.permission,
    },
    sharedStoragePaths: {
      'documents': '/path/to/shared/documents',
      'images': '/path/to/shared/images',
    },
  );
  
  runApp(MyApp());
}
```

### 2. Required Permissions

The system uses a permission-based security model:

```dart
// Built-in permissions
AppPermission.send        // Send events to other apps
AppPermission.receive     // Receive events from other apps  
AppPermission.dataShare   // Share data with other apps
AppPermission.urlHandle   // Handle URL schemes

// Usage example
Set<String> permissions = {
  AppPermission.send.permission,
  AppPermission.receive.permission,
};
```

## Platform Configuration

### Android Configuration

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- For sending intents -->
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />

<!-- For URL schemes -->
<activity
    android:name=".MainActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="yourappscheme" />
    </intent-filter>
</activity>

<!-- For data sharing -->
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="com.yourcompany.yourapp.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

### iOS Configuration

Add to `ios/Runner/Info.plist`:

```xml
<!-- URL Schemes -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>yourappscheme</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yourappscheme</string>
        </array>
    </dict>
</array>

<!-- App Groups for data sharing -->
<key>com.apple.security.application-groups</key>
<array>
    <string>group.yourcompany.shared</string>
</array>
```

## Usage Examples

### 1. Sending Android-Style Intents

```dart
// Send a generic intent
final result = await CrossAppBus.sendIntent(
  action: 'com.example.ACTION_CUSTOM',
  targetApp: 'com.example.otherapp', // Optional - null for broadcast
  category: 'android.intent.category.DEFAULT',
  extras: {
    'message': 'Hello from ABUS!',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  },
  permissions: {'custom_permission'},
);

if (result.isSuccess) {
  print('Intent sent successfully');
} else {
  print('Failed to send intent: ${result.error}');
}
```

### 2. Opening URL Schemes / App Links

```dart
// Open a URL in another app
final result = await CrossAppBus.openUrl(
  scheme: 'myapp',
  path: 'user/profile',
  queryParams: {
    'userId': '123',
    'tab': 'settings',
  },
  targetApp: 'com.example.targetapp', // Optional
);

// This creates: myapp://user/profile?userId=123&tab=settings
```

### 3. Data Sharing Between Apps

```dart
// Share data with another app
final result = await CrossAppBus.shareData(
  dataType: 'user_profile',
  payload: {
    'id': 123,
    'name': 'John Doe',
    'email': 'john@example.com',
  },
  filePath: '/path/to/shared/file.json', // Optional
  targetApp: 'com.example.otherapp',
  permissions: {AppPermission.dataShare.permission},
);
```

### 4. Receiving Cross-App Events

Cross-app events are automatically received and processed through the ABUS system. Create handlers to process incoming events:

```dart
class CrossAppEventHandler extends CustomAbusHandler {
  @override
  String get handlerId => 'CrossAppEventHandler';

  @override
  bool canHandle(InteractionDefinition interaction) {
    return interaction.id == 'receive_app_event';
  }

  @override
  Future<void> handleOptimistic(
    String interactionId,
    InteractionDefinition interaction,
  ) async {
    if (interaction is ReceiveAppEventInteraction) {
      final event = interaction.event;
      
      switch (event.runtimeType) {
        case IntentEvent:
          await _handleIntent(event as IntentEvent);
          break;
        case UrlEvent:
          await _handleUrl(event as UrlEvent);
          break;
        case DataShareEvent:
          await _handleDataShare(event as DataShareEvent);
          break;
      }
    }
  }

  Future<void> _handleIntent(IntentEvent event) async {
    print('Received intent: ${event.action}');
    print('Extras: ${event.extras}');
    // Handle the intent...
  }

  Future<void> _handleUrl(UrlEvent event) async {
    print('Received URL: ${event.fullUrl}');
    print('Query params: ${event.queryParams}');
    // Navigate to appropriate screen...
  }

  Future<void> _handleDataShare(DataShareEvent event) async {
    print('Received data: ${event.dataType}');
    print('Payload: ${event.payload}');
    // Process shared data...
  }
}

// Register the handler
ABUS.registerHandler(CrossAppEventHandler());
```

## Event Filtering

Add custom filters to control which events your app receives:

```dart
// Filter by source app
CrossAppBus.addEventFilter('trusted_apps', (event) {
  final trustedApps = {
    'com.yourcompany.app1',
    'com.yourcompany.app2',
  };
  return trustedApps.contains(event.sourceApp);
});

// Filter by event type
CrossAppBus.addEventFilter('intent_only', (event) {
  return event is IntentEvent;
});

// Filter by data content
CrossAppBus.addEventFilter('profile_data', (event) {
  if (event is DataShareEvent) {
    return event.dataType == 'user_profile';
  }
  return false;
});

// Remove a filter
CrossAppBus.removeEventFilter('intent_only');
```

## Error Handling

All cross-app operations return `ABUSResult` objects:

```dart
final result = await CrossAppBus.sendIntent(
  action: 'com.example.ACTION',
  extras: {'key': 'value'},
);

if (result.isSuccess) {
  final data = result.data;
  print('Success: $data');
} else {
  print('Error: ${result.error}');
  
  // Check metadata for additional info
  final metadata = result.metadata;
  if (metadata != null) {
    print('Error details: $metadata');
  }
}
```

## Security Considerations

### 1. Permission Validation

Always validate permissions before sending sensitive data:

```dart
// Check if app has required permissions
final manager = AppCommunicationManager.instance;
if (!manager._hasPermission(AppPermission.dataShare.permission)) {
  // Handle missing permission
  return;
}
```

### 2. Event Validation

Implement strict event filtering for security:

```dart
CrossAppBus.addEventFilter('security_check', (event) {
  // Validate source app
  if (!isTrustedApp(event.sourceApp)) {
    return false;
  }
  
  // Validate required permissions
  for (final permission in event.permissions) {
    if (!hasPermission(permission)) {
      return false;
    }
  }
  
  return true;
});
```

### 3. Data Sanitization

Always sanitize incoming data:

```dart
Future<void> _handleDataShare(DataShareEvent event) async {
  // Sanitize payload
  final sanitized = sanitizeData(event.payload);
  
  // Validate file paths
  if (event.filePath != null) {
    if (!isValidFilePath(event.filePath!)) {
      return; // Reject invalid paths
    }
  }
  
  // Process sanitized data
  await processSharedData(sanitized);
}
```

## Advanced Usage

### Custom Event Types

Create custom event types by extending `AppEvent`:

```dart
class CustomSyncEvent extends AppEvent {
  final String syncType;
  final List<String> entityIds;

  CustomSyncEvent({
    required String id,
    required String sourceApp,
    required this.syncType,
    required this.entityIds,
    String? targetApp,
    Set<String> permissions = const {},
  }) : super(
    id: id,
    sourceApp: sourceApp,
    targetApp: targetApp,
    data: {
      'syncType': syncType,
      'entityIds': entityIds,
    },
    timestamp: DateTime.now(),
    permissions: permissions,
  );

  factory CustomSyncEvent.fromJson(Map<String, dynamic> json) {
    return CustomSyncEvent(
      id: json['id'],
      sourceApp: json['sourceApp'],
      syncType: json['data']['syncType'],
      entityIds: List<String>.from(json['data']['entityIds']),
      targetApp: json['targetApp'],
      permissions: Set<String>.from(json['permissions'] ?? []),
    );
  }
}
```

### Integration with State Management

The cross-app system integrates seamlessly with your existing state management:

```dart
class UserBloc extends Bloc<UserEvent, UserState> with BlocMixin {
  @override
  String get handlerId => 'UserBloc';

  @override
  bool canHandle(InteractionDefinition interaction) {
    return interaction.id == 'receive_app_event' ||
           interaction.id == 'sync_user_data';
  }

  @override
  Future<void> handleOptimistic(
    String interactionId,
    InteractionDefinition interaction,
  ) async {
    if (interaction is ReceiveAppEventInteraction) {
      final event = interaction.event;
      
      if (event is DataShareEvent && event.dataType == 'user_profile') {
        // Update user state optimistically
        final userData = event.payload;
        add(UserUpdated(userData));
      }
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **Events not received**: Check permissions and filters
2. **Platform channel errors**: Verify platform-specific configuration
3. **Permission denied**: Ensure all required permissions are granted
4. **Timeout errors**: Increase timeout duration for complex operations

### Debug Mode

Enable debug logging for development:

```dart
// Add debug filter to log all events
CrossAppBus.addEventFilter('debug_logger', (event) {
  print('Cross-app event: ${event.toJson()}');
  return true; // Always allow in debug mode
});
```

This documentation provides a comprehensive guide to setting up and using the ABUS cross-app communication system. The system provides secure, permission-based communication between Flutter applications while maintaining the familiar ABUS interaction pattern.