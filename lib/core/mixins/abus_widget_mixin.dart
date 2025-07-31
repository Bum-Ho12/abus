// lib/core/mixins/abus_widget_mixin.dart
import 'dart:async';
import 'package:abus/abus.dart';
import 'package:abus/core/abus_result.dart';
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
    this.customFilter,
    this.debounceDelay,
    this.onlyWhenVisible = false,
  });

  /// Check if this result should trigger an update
  bool shouldUpdate(ABUSResult result) {
    // Apply custom filter first
    if (customFilter != null && !customFilter!(result)) {
      return false;
    }

    // Special handling for rollback
    final isRollback = result.metadata?['rollback'] == true;

    if (isRollback && !rebuildOnError) return false;
    if (!isRollback) {
      // Check success/error preferences
      if (result.isSuccess && !rebuildOnSuccess) return false;
      if (!result.isSuccess && !rebuildOnError) return false;
    }

    // Check interaction ID filter
    if (interactionIds != null && result.interactionId != null) {
      if (!interactionIds!.contains(result.interactionId)) return false;
    }

    // Check tags filter (assuming tags are in metadata)
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
    _subscription?.cancel();
    _debounceTimer?.cancel();
    _unregisterWidgetId();
    super.dispose();
  }

  void _subscribeToResults() {
    _subscription = ABUS.manager.resultStream.listen((result) {
      if (!mounted) return;

      if (abusConfig.onlyWhenVisible && !_isVisible) return;
      if (!abusConfig.shouldUpdate(result)) return;

      if (abusConfig.debounceDelay != null) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(abusConfig.debounceDelay!, () {
          if (mounted) _handleResult(result);
        });
      } else {
        _handleResult(result);
      }
    });
  }

  void _handleResult(ABUSResult result) {
    onAbusResult(result);
    if (shouldRebuild(result)) {
      setState(() {}); // Rebuild this widget
    }
  }

  /// Override to perform custom handling on result
  void onAbusResult(ABUSResult result) {}

  /// Override to prevent rebuilds
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
