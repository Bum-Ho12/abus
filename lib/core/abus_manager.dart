// lib/core/abus_manager.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'abus_definition.dart';
import 'abus_result.dart';

/// Base interface for any state handler
abstract class AbusHandler {
  /// Handle optimistic update for interaction
  Future<void> handleOptimistic(
      String interactionId, InteractionDefinition interaction) async {}

  /// Handle rollback for interaction
  Future<void> handleRollback(
      String interactionId, InteractionDefinition interaction) async {}

  /// Handle commit after successful API call
  Future<void> handleCommit(
      String interactionId, InteractionDefinition interaction) async {}

  /// Execute API call
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) => null;

  /// Check if this handler can handle the interaction
  bool canHandle(InteractionDefinition interaction) => true;

  /// Get current state for rollback capability
  Map<String, dynamic>? getCurrentState(InteractionDefinition interaction) =>
      null;

  /// Get handler identifier for tracking
  String get handlerId;
}

/// Mixin for BLoCs to support ABUS interactions
mixin AbusBloc<State> on Object implements AbusHandler {
  @override
  String get handlerId => runtimeType.toString();

  /// Handle optimistic update for interaction
  @override
  Future<void> handleOptimistic(
      String interactionId, InteractionDefinition interaction) async {}

  /// Handle rollback for interaction
  @override
  Future<void> handleRollback(
      String interactionId, InteractionDefinition interaction) async {}

  /// Handle commit after successful API call
  @override
  Future<void> handleCommit(
      String interactionId, InteractionDefinition interaction) async {}

  /// Execute API call
  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) => null;

  /// Check if this BLoC can handle the interaction
  @override
  bool canHandle(InteractionDefinition interaction) => true;

  /// Get current state for rollback capability
  @override
  Map<String, dynamic>? getCurrentState(InteractionDefinition interaction) =>
      null;
}

/// Mixin for ChangeNotifiers to support ABUS interactions
mixin AbusProvider on ChangeNotifier implements AbusHandler {
  @override
  String get handlerId => runtimeType.toString();

  /// Handle optimistic update for interaction
  @override
  Future<void> handleOptimistic(
      String interactionId, InteractionDefinition interaction) async {}

  /// Handle rollback for interaction
  @override
  Future<void> handleRollback(
      String interactionId, InteractionDefinition interaction) async {}

  /// Handle commit after successful API call
  @override
  Future<void> handleCommit(
      String interactionId, InteractionDefinition interaction) async {}

  /// Execute API call
  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) => null;

  /// Check if this provider can handle the interaction
  @override
  bool canHandle(InteractionDefinition interaction) => true;

  /// Get current state for rollback capability
  @override
  Map<String, dynamic>? getCurrentState(InteractionDefinition interaction) =>
      null;
}

/// Custom handler for projects not using BLoC or Provider
abstract class CustomAbusHandler implements AbusHandler {
  @override
  String get handlerId => runtimeType.toString();
}

/// State change snapshot for rollback capability
class StateSnapshot {
  final String interactionId;
  final InteractionDefinition interaction;
  final Map<String, dynamic>? previousState;
  final DateTime timestamp;
  final List<String> affectedHandlers;

  StateSnapshot({
    required this.interactionId,
    required this.interaction,
    this.previousState,
    required this.timestamp,
    required this.affectedHandlers,
  });
}

/// Handler discovery strategy
abstract class HandlerDiscoveryStrategy {
  List<AbusHandler> discoverHandlers(BuildContext? context);
}

/// Default discovery strategy that works without external dependencies
class DefaultDiscoveryStrategy implements HandlerDiscoveryStrategy {
  @override
  List<AbusHandler> discoverHandlers(BuildContext? context) {
    final handlers = <AbusHandler>[];

    if (context == null) return handlers;

    // Try to discover handlers from widget tree without depending on specific packages
    _tryDiscoverFromContext(context, handlers);

    return handlers;
  }

  void _tryDiscoverFromContext(
      BuildContext context, List<AbusHandler> handlers) {
    // Walk up the widget tree to find handlers
    context.visitAncestorElements((element) {
      final widget = element.widget;

      // Check if widget implements or contains handlers
      if (widget is StatefulWidget) {
        final state = (element as StatefulElement).state;
        if (state is AbusHandler) {
          handlers.add(state as AbusHandler);
        }
      }

      // Continue walking up the tree
      return true;
    });
  }
}

/// Interaction manager with flexible dependency handling
class ABUSManager {
  static ABUSManager? _instance;
  static ABUSManager get instance => _instance ??= ABUSManager._();

  ABUSManager._() : _discoveryStrategy = DefaultDiscoveryStrategy();

  // Unified handler list
  final List<AbusHandler> _handlers = [];
  final List<Future<ABUSResult> Function(InteractionDefinition)> _apiHandlers =
      [];

  final Map<String, StateSnapshot> _snapshots = {};
  final Map<String, Timer> _rollbackTimers = {};
  final StreamController<ABUSResult> _resultController =
      StreamController<ABUSResult>.broadcast();

  HandlerDiscoveryStrategy _discoveryStrategy;

  Stream<ABUSResult> get resultStream => _resultController.stream;

  /// Set custom discovery strategy
  void setDiscoveryStrategy(HandlerDiscoveryStrategy strategy) {
    _discoveryStrategy = strategy;
  }

  /// Register a global API handler
  void registerApiHandler(
      Future<ABUSResult> Function(InteractionDefinition) handler) {
    _apiHandlers.add(handler);
  }

  /// Register any type of handler
  void registerHandler(AbusHandler handler) {
    _handlers.removeWhere((h) => h.handlerId == handler.handlerId);
    _handlers.add(handler);
  }

  /// Auto-discover handlers using current strategy
  void discoverHandlers(BuildContext? context) {
    final discoveredHandlers = _discoveryStrategy.discoverHandlers(context);
    for (final handler in discoveredHandlers) {
      registerHandler(handler);
    }
  }

  /// Execute an interaction with automatic handler discovery
  Future<ABUSResult> execute(
    InteractionDefinition interaction, {
    bool? optimistic,
    Duration? timeout,
    bool autoRollback = true,
    BuildContext? context,
  }) async {
    final useOptimistic = optimistic ?? interaction.supportsOptimistic;
    final timeoutDuration =
        timeout ?? interaction.timeout ?? const Duration(seconds: 30);

    final interactionId =
        '${interaction.id}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Auto-discover handlers if context provided
      if (context != null) {
        discoverHandlers(context);
      }

      // Find compatible handlers
      final compatibleHandlers =
          _handlers.where((h) => h.canHandle(interaction)).toList();

      if (compatibleHandlers.isEmpty) {
        // Try API-only execution if no state handlers found
        return await _executeApiOnly(interaction, timeoutDuration);
      }

      // Create snapshot for rollback
      final previousState = _getPreviousState(interaction, compatibleHandlers);
      final snapshot = StateSnapshot(
        interactionId: interactionId,
        interaction: interaction,
        previousState: previousState,
        timestamp: DateTime.now(),
        affectedHandlers: compatibleHandlers.map((h) => h.handlerId).toList(),
      );
      _snapshots[interactionId] = snapshot;

      ABUSResult result;

      if (useOptimistic) {
        // Execute optimistic updates first
        await _executeOptimistic(
            interactionId, interaction, compatibleHandlers);

        // Then execute actual API call
        result =
            await _executeAPI(interaction, compatibleHandlers, timeoutDuration);

        if (!result.isSuccess) {
          // Rollback on failure
          await rollback(interactionId);
        } else {
          // Commit on success
          await _commit(interactionId, interaction, compatibleHandlers);
        }
      } else {
        // Execute API call directly
        result =
            await _executeAPI(interaction, compatibleHandlers, timeoutDuration);

        if (result.isSuccess) {
          await _commit(interactionId, interaction, compatibleHandlers);
        }
      }

      // Setup auto-rollback if enabled and optimistic
      if (autoRollback && useOptimistic && result.isSuccess) {
        _setupAutoRollback(interactionId, timeoutDuration);
      }

      _resultController.add(result);
      return result;
    } catch (e) {
      final errorResult =
          ABUSResult.error(e.toString(), interactionId: interactionId);

      // Rollback on error if optimistic was used
      if (useOptimistic) {
        await rollback(interactionId);
      }

      _resultController.add(errorResult);
      return errorResult;
    }
  }

  Future<ABUSResult> _executeApiOnly(
      InteractionDefinition interaction, Duration timeout) async {
    for (final handler in _apiHandlers) {
      try {
        return await handler(interaction).timeout(timeout, onTimeout: () {
          return ABUSResult.error('Timeout', interactionId: interaction.id);
        });
      } catch (e) {
        continue; // Try next handler
      }
    }
    throw Exception('No API handler found for interaction: ${interaction.id}');
  }

  Map<String, dynamic>? _getPreviousState(
    InteractionDefinition interaction,
    List<AbusHandler> handlers,
  ) {
    final states = <String, dynamic>{};

    for (final handler in handlers) {
      final state = handler.getCurrentState(interaction);
      if (state != null) {
        states[handler.handlerId] = state;
      }
    }

    return states.isNotEmpty ? states : null;
  }

  Future<void> _executeOptimistic(
    String interactionId,
    InteractionDefinition interaction,
    List<AbusHandler> handlers,
  ) async {
    for (final handler in handlers) {
      try {
        await handler.handleOptimistic(interactionId, interaction);
      } catch (e) {
        debugPrint('Optimistic update failed for ${handler.handlerId}: $e');
      }
    }
  }

  Future<ABUSResult> _executeAPI(
    InteractionDefinition interaction,
    List<AbusHandler> handlers,
    Duration timeout,
  ) async {
    // Try handlers first
    for (final handler in handlers) {
      final apiResult = handler.executeAPI(interaction);
      if (apiResult != null) {
        return await apiResult.timeout(timeout, onTimeout: () {
          return ABUSResult.error('Timeout', interactionId: interaction.id);
        });
      }
    }

    // Try global API handlers
    for (final handler in _apiHandlers) {
      try {
        return await handler(interaction).timeout(timeout, onTimeout: () {
          return ABUSResult.error('Timeout', interactionId: interaction.id);
        });
      } catch (e) {
        continue; // Try next handler
      }
    }

    throw Exception('No API handler found for interaction: ${interaction.id}');
  }

  Future<void> _commit(
    String interactionId,
    InteractionDefinition interaction,
    List<AbusHandler> handlers,
  ) async {
    for (final handler in handlers) {
      try {
        await handler.handleCommit(interactionId, interaction);
      } catch (e) {
        debugPrint('Commit failed for ${handler.handlerId}: $e');
      }
    }

    _cleanupInteraction(interactionId);
  }

  void _setupAutoRollback(String interactionId, Duration timeout) {
    _rollbackTimers[interactionId] = Timer(timeout, () async {
      if (_snapshots.containsKey(interactionId)) {
        debugPrint('Auto-rolling back interaction: $interactionId');
        await rollback(interactionId);
      }
    });
  }

  /// Manually rollback a specific interaction
  Future<void> rollback(String interactionId) async {
    final snapshot = _snapshots[interactionId];
    if (snapshot == null) return;

    // Rollback all affected handlers
    for (final handler in _handlers) {
      if (snapshot.affectedHandlers.contains(handler.handlerId)) {
        try {
          await handler.handleRollback(interactionId, snapshot.interaction);
        } catch (e) {
          debugPrint('Rollback failed for ${handler.handlerId}: $e');
        }
      }
    }
    // Emit rollback result so that widgets can respond
    _resultController.add(ABUSResult.rollback(
      interactionId: interactionId,
      metadata: {
        'tags': snapshot.interaction.tags.toList(),
      },
    ));

    _cleanupInteraction(interactionId);
  }

  /// Confirm success and prevent auto-rollback
  void confirmSuccess(String interactionId) {
    _rollbackTimers[interactionId]?.cancel();
    _rollbackTimers.remove(interactionId);
    _cleanupInteraction(interactionId);
  }

  void _cleanupInteraction(String interactionId) {
    _snapshots.remove(interactionId);
    _rollbackTimers[interactionId]?.cancel();
    _rollbackTimers.remove(interactionId);
  }

  /// Get pending interactions
  List<String> get pendingInteractions => _snapshots.keys.toList();

  /// Check if interaction is pending
  bool isPending(String interactionId) => _snapshots.containsKey(interactionId);

  /// Clear all pending operations
  void clearPending() {
    for (final timer in _rollbackTimers.values) {
      timer.cancel();
    }
    _snapshots.clear();
    _rollbackTimers.clear();
  }

  /// Get registered handlers count
  int get handlerCount => _handlers.length;

  /// Get API handlers count
  int get apiHandlerCount => _apiHandlers.length;

  void dispose() {
    clearPending();
    _handlers.clear();
    _apiHandlers.clear();
    _resultController.close();
  }

  /// Reset to new instance (useful for testing)
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}
