// lib/cross_app/app_communication_manager.dart

import 'dart:async';
import 'package:abus/abus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Permission system for cross-app communication
class AppPermission {
  final String permission;
  final String description;
  final bool required;

  const AppPermission(this.permission, this.description,
      {this.required = false});

  static const send =
      AppPermission('cross_app.send', 'Send events to other apps');
  static const receive =
      AppPermission('cross_app.receive', 'Receive events from other apps');
  static const dataShare =
      AppPermission('cross_app.data_share', 'Share data with other apps');
  static const urlHandle =
      AppPermission('cross_app.url_handle', 'Handle URL schemes');
}

/// Main manager for cross-application communication
class AppCommunicationManager extends CustomAbusHandler {
  static AppCommunicationManager? _instance;
  static AppCommunicationManager get instance =>
      _instance ??= AppCommunicationManager._();

  AppCommunicationManager._();

  // Platform channels
  static const _methodChannel = MethodChannel('abus/cross_app');
  static const _eventChannel = EventChannel('abus/cross_app/events');

  // Configuration
  String? _appId;
  final Set<String> _grantedPermissions = {};
  final Map<String, bool Function(AppEvent)> _eventFilters = {};
  final Map<String, String> _sharedStoragePaths = {};

  // State
  StreamSubscription? _eventSubscription;
  bool _initialized = false;

  @override
  String get handlerId => 'AppCommunicationManager';

  @override
  bool canHandle(InteractionDefinition interaction) {
    return interaction.id == 'send_app_event' ||
        interaction.id == 'receive_app_event';
  }

  /// Initialize the cross-app communication system
  Future<void> initialize({
    required String appId,
    Set<String> permissions = const {},
    Map<String, String>? sharedStoragePaths,
  }) async {
    if (_initialized) return;

    _appId = appId;
    _grantedPermissions.addAll(permissions);
    if (sharedStoragePaths != null) {
      _sharedStoragePaths.addAll(sharedStoragePaths);
    }

    try {
      // Initialize platform channel
      await _methodChannel.invokeMethod('initialize', {
        'appId': appId,
        'permissions': permissions.toList(),
        'sharedPaths': _sharedStoragePaths,
      });

      // Listen for incoming events
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
            _handleIncomingEvent,
            onError: (error) => debugPrint('Cross-app event error: $error'),
          );

      _initialized = true;
    } catch (e) {
      debugPrint('Failed to initialize cross-app communication: $e');
    }
  }

  @override
  Future<ABUSResult> executeAPI(InteractionDefinition interaction) async {
    if (!_initialized) {
      return ABUSResult.error('Cross-app communication not initialized');
    }

    if (interaction is SendAppEventInteraction) {
      return _sendAppEvent(interaction.event);
    }

    return ABUSResult.error(
        'Unsupported cross-app interaction: ${interaction.id}');
  }

  Future<ABUSResult> _sendAppEvent(AppEvent event) async {
    try {
      // Check permissions
      if (!_hasPermission(AppPermission.send.permission)) {
        return ABUSResult.error('Missing send permission');
      }

      // Validate event permissions
      for (final permission in event.permissions) {
        if (!_hasPermission(permission)) {
          return ABUSResult.error('Missing required permission: $permission');
        }
      }

      final result = await _methodChannel.invokeMethod('sendEvent', {
        'event': event.toJson(),
      });

      return ABUSResult.success(
        data: {'sent': true, 'result': result},
        interactionId: 'send_app_event',
      );
    } catch (e) {
      return ABUSResult.error('Failed to send app event: $e');
    }
  }

  void _handleIncomingEvent(dynamic eventData) {
    try {
      final eventJson = Map<String, dynamic>.from(eventData);
      final appEvent = AppEvent.fromJson(eventJson);

      // Check permissions and filters
      if (!_canReceiveEvent(appEvent)) {
        return;
      }

      // Create ABUS interaction for the received event
      final interaction = ReceiveAppEventInteraction(event: appEvent);

      // Execute through ABUS system
      ABUS.execute(interaction);
    } catch (e) {
      debugPrint('Failed to handle incoming app event: $e');
    }
  }

  bool _canReceiveEvent(AppEvent event) {
    // Check basic receive permission
    if (!_hasPermission(AppPermission.receive.permission)) {
      return false;
    }

    // Check event-specific permissions
    for (final permission in event.permissions) {
      if (!_hasPermission(permission)) {
        return false;
      }
    }

    // Apply custom filters
    for (final filter in _eventFilters.values) {
      if (!filter(event)) {
        return false;
      }
    }

    return true;
  }

  bool _hasPermission(String permission) =>
      _grantedPermissions.contains(permission);

  /// Register a custom event filter
  void addEventFilter(String filterId, bool Function(AppEvent) filter) {
    _eventFilters[filterId] = filter;
  }

  void removeEventFilter(String filterId) {
    _eventFilters.remove(filterId);
  }

  /// Helper methods for common operations
  Future<ABUSResult> sendIntent({
    required String action,
    String? targetApp,
    String? category,
    Map<String, dynamic> extras = const {},
    Set<String> permissions = const {},
  }) async {
    final event = IntentEvent(
      id: 'intent_${DateTime.now().millisecondsSinceEpoch}',
      sourceApp: _appId!,
      action: action,
      category: category,
      extras: extras,
      targetApp: targetApp,
      permissions: permissions,
    );

    return ABUS.execute(SendAppEventInteraction(event: event));
  }

  Future<ABUSResult> openUrl({
    required String scheme,
    required String path,
    Map<String, String> queryParams = const {},
    String? targetApp,
    Set<String> permissions = const {},
  }) async {
    final event = UrlEvent(
      id: 'url_${DateTime.now().millisecondsSinceEpoch}',
      sourceApp: _appId!,
      scheme: scheme,
      path: path,
      queryParams: queryParams,
      targetApp: targetApp,
      permissions: permissions,
    );

    return ABUS.execute(SendAppEventInteraction(event: event));
  }

  Future<ABUSResult> shareData({
    required String dataType,
    required Map<String, dynamic> payload,
    String? targetApp,
    String? filePath,
    Set<String> permissions = const {},
  }) async {
    final event = DataShareEvent(
      id: 'share_${DateTime.now().millisecondsSinceEpoch}',
      sourceApp: _appId!,
      dataType: dataType,
      payload: payload,
      filePath: filePath,
      targetApp: targetApp,
      permissions: {...permissions, AppPermission.dataShare.permission},
    );

    return ABUS.execute(SendAppEventInteraction(event: event));
  }

  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _initialized = false;
  }
}
