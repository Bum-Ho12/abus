// lib/core/mixins/abus_widget_mixin.dart
import 'dart:async';
import 'package:abus/abus.dart';
import 'package:flutter/material.dart';

/// Configuration for ABUS widget updates
class AbusUpdateConfig {
  /// Specific interaction IDs to listen for
  final Set<String>? interactionIds;

  /// Interaction tags to listen for
  final Set<String>? tags;

  /// Whether to rebuild on success results
  final bool rebuildOnSuccess;

  /// Whether to rebuild on error results
  final bool rebuildOnError;

  /// Whether to rebuild on rollback results
  final bool rebuildOnRollback;

  /// Custom filter function for fine-grained control
  final bool Function(ABUSResult)? customFilter;

  /// Debounce duration to prevent excessive rebuilds
  final Duration? debounceDelay;

  /// Whether to only listen while widget is visible
  final bool onlyWhenVisible;

  const AbusUpdateConfig({
    this.interactionIds,
    this.tags,
    this.rebuildOnSuccess = true,
    this.rebuildOnError = true,
    this.rebuildOnRollback = true,
    this.customFilter,
    this.debounceDelay,
    this.onlyWhenVisible = false,
  });

  /// Default config for minimal rebuilds
  static const AbusUpdateConfig minimal = AbusUpdateConfig(
    rebuildOnSuccess: false,
    rebuildOnError: false,
    rebuildOnRollback: false,
    debounceDelay: Duration(milliseconds: 500),
  );

  /// Config for error-only updates
  static const AbusUpdateConfig errorsOnly = AbusUpdateConfig(
    rebuildOnSuccess: false,
    rebuildOnError: true,
    rebuildOnRollback: true,
    debounceDelay: Duration(milliseconds: 200),
  );

  /// Check if this result should trigger an update
  bool shouldUpdate(ABUSResult result) {
    // Apply custom filter first
    if (customFilter != null && !customFilter!(result)) {
      return false;
    }

    // Special handling for rollback
    final isRollback = result.metadata?['rollback'] == true;

    if (isRollback && !rebuildOnRollback) return false;
    if (!isRollback) {
      // Check success/error preferences
      if (result.isSuccess && !rebuildOnSuccess) return false;
      if (!result.isSuccess && !rebuildOnError) return false;
    }

    // Check interaction ID filter
    if (interactionIds != null && result.interactionId != null) {
      if (!interactionIds!.contains(result.interactionId)) return false;
    }

    // Check tags filter
    if (tags != null && result.metadata?['tags'] is List) {
      final resultTags = Set<String>.from(result.metadata!['tags'] as List);
      if (!tags!.any((tag) => resultTags.contains(tag))) return false;
    }

    return true;
  }
}

/// Mixin for widgets that need to react to ABUS interactions
mixin AbusWidgetMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<ABUSResult>? _subscription;
  Timer? _debounceTimer;
  bool _disposed = false;
  bool _isVisible = true;

  /// Unique ID for this widget (optional)
  String? get widgetId => null;

  /// Configuration for filtering interaction results
  AbusUpdateConfig get abusConfig => const AbusUpdateConfig();

  @override
  void initState() {
    super.initState();
    _subscribeToResults();
    _registerWidgetId();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _unregisterWidgetId();
    super.dispose();
  }

  void _subscribeToResults() {
    try {
      _subscription = ABUS.manager.resultStream.listen(
        _handleResult,
        onError: (error) {
          debugPrint('ABUS Widget Mixin error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Failed to subscribe to ABUS results: $e');
    }
  }

  void _handleResult(ABUSResult result) {
    if (_disposed || !mounted) return;

    try {
      // Check visibility filter
      if (abusConfig.onlyWhenVisible && !_isVisible) return;

      // Filter check
      if (!abusConfig.shouldUpdate(result)) return;

      // Debounce check
      if (abusConfig.debounceDelay != null) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(abusConfig.debounceDelay!, () {
          if (!_disposed && mounted) {
            _processResult(result);
          }
        });
      } else {
        _processResult(result);
      }
    } catch (e) {
      debugPrint('Error handling ABUS result in ${widget.runtimeType}: $e');
    }
  }

  void _processResult(ABUSResult result) {
    try {
      onAbusResult(result);

      if (shouldRebuild(result)) {
        if (mounted && !_disposed) {
          setState(() {}); // Rebuild this widget
        }
      }
    } catch (e) {
      debugPrint('Error processing ABUS result in ${widget.runtimeType}: $e');
    }
  }

  /// Override to perform custom handling on result
  void onAbusResult(ABUSResult result) {}

  /// Override to control rebuilds per result
  bool shouldRebuild(ABUSResult result) => true;

  /// Visibility tracking
  void setVisible(bool visible) {
    _isVisible = visible;
  }

  /// Manual update trigger
  void triggerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _registerWidgetId() {
    if (widgetId != null) {
      _WidgetRegistry.instance.register(widgetId!, this);
    }
  }

  void _unregisterWidgetId() {
    if (widgetId != null) {
      _WidgetRegistry.instance.unregister(widgetId!);
    }
  }

  /// Execute interaction with context automatically
  Future<ABUSResult> executeInteraction(
    InteractionDefinition interaction, {
    bool? optimistic,
    Duration? timeout,
    bool autoRollback = true,
  }) {
    return ABUS.executeWith(interaction, context);
  }

  /// Quick interaction builder helper
  InteractionBuilder interactionBuilder() => ABUS.builder();
}

class _WidgetRegistry {
  static final _WidgetRegistry instance = _WidgetRegistry._();
  _WidgetRegistry._();

  final Map<String, AbusWidgetMixin> _registered = {};

  void register(String id, AbusWidgetMixin widget) {
    _registered[id] = widget;
  }

  void unregister(String id) {
    _registered.remove(id);
  }

  void trigger(String id) {
    _registered[id]?.triggerUpdate();
  }
}
