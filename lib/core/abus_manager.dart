// lib/core/abus_manager.dart
import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:abus/core/abus_definition.dart';
import 'package:abus/core/abus_result.dart';

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

/// Custom handler for projects not using BLoC or Provider
abstract class CustomAbusHandler implements AbusHandler {
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

  /// Check if this can handle the interaction
  @override
  bool canHandle(InteractionDefinition interaction) => true;

  /// Get current state for rollback capability
  @override
  Map<String, dynamic>? getCurrentState(InteractionDefinition interaction) =>
      null;
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

/// Internal interaction execution queue to prevent race conditions
class _InteractionQueue {
  final Queue<_QueuedInteraction> _queue = Queue();
  bool _isProcessing = false;
  final Set<String> _processingIds = {};

  Future<ABUSResult> enqueue(_QueuedInteraction interaction) async {
    // Check if interaction with same ID is already processing
    if (_processingIds.contains(interaction.definition.id)) {
      return ABUSResult.error(
        'Interaction ${interaction.definition.id} is already processing',
        interactionId: interaction.definition.id,
      );
    }

    final completer = Completer<ABUSResult>();
    interaction.completer = completer;
    _queue.add(interaction);

    // Don't wait for _processQueue to complete - just start it
    unawaited(_processQueue());
    return completer.future;
  }

  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final interaction = _queue.removeFirst();
      _processingIds.add(interaction.definition.id);

      try {
        final result = await interaction.execute();
        interaction.completer?.complete(result);
      } catch (e) {
        interaction.completer?.complete(
          ABUSResult.error(e.toString(),
              interactionId: interaction.definition.id),
        );
      } finally {
        _processingIds.remove(interaction.definition.id);
      }
    }

    _isProcessing = false;
  }

  void clear() {
    _queue.clear();
    _processingIds.clear();
  }
}

class _QueuedInteraction {
  final InteractionDefinition definition;
  final Future<ABUSResult> Function() execute;
  Completer<ABUSResult>? completer;

  _QueuedInteraction({
    required this.definition,
    required this.execute,
  });
}

/// Interaction manager
class ABUSManager {
  static ABUSManager? _instance;
  static ABUSManager get instance => _instance ??= ABUSManager._();

  ABUSManager._();

  // Configuration for memory management
  static const int _maxSnapshots = 100;
  static const Duration _defaultTimeout = Duration(seconds: 30);

  // Core components
  final List<AbusHandler> _handlers = [];
  final List<Future<ABUSResult> Function(InteractionDefinition)> _apiHandlers =
      [];
  final _InteractionQueue _queue = _InteractionQueue();

  // State management with size limits using LinkedHashMap for LRU(Least Recently Used) behavior
  final LinkedHashMap<String, StateSnapshot> _snapshots = LinkedHashMap();
  final Map<String, Timer> _rollbackTimers = {};

  // Streams with proper cleanup - initialize immediately
  late final StreamController<ABUSResult> _resultController =
      StreamController<ABUSResult>.broadcast();
  bool _disposed = false;

  Stream<ABUSResult> get resultStream => _resultController.stream;

  /// Register a global API handler
  void registerApiHandler(
      Future<ABUSResult> Function(InteractionDefinition) handler) {
    if (_disposed) return;
    _apiHandlers.add(handler);
  }

  /// Register any type of handler
  void registerHandler(AbusHandler handler) {
    if (_disposed) return;
    _handlers.removeWhere((h) => h.handlerId == handler.handlerId);
    _handlers.add(handler);
  }

  /// Execute an interaction with proper queuing and safety
  Future<ABUSResult> execute(
    InteractionDefinition interaction, {
    bool? optimistic,
    Duration? timeout,
    bool autoRollback = true,
    BuildContext? context,
  }) async {
    if (_disposed) {
      return ABUSResult.error('Manager disposed',
          interactionId: interaction.id);
    }

    return _queue.enqueue(_QueuedInteraction(
      definition: interaction,
      execute: () => _executeInternal(
        interaction,
        optimistic: optimistic,
        timeout: timeout,
        autoRollback: autoRollback,
        context: context,
      ),
    ));
  }

  Future<ABUSResult> _executeInternal(
    InteractionDefinition interaction, {
    bool? optimistic,
    Duration? timeout,
    bool autoRollback = true,
    BuildContext? context,
  }) async {
    final useOptimistic = optimistic ?? interaction.supportsOptimistic;
    final timeoutDuration = timeout ?? interaction.timeout ?? _defaultTimeout;

    final interactionId =
        '${interaction.id}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Auto-discover handlers if context provided
      if (context != null) {
        _discoverHandlers(context);
      }

      // Find compatible handlers
      final compatibleHandlers =
          _handlers.where((h) => h.canHandle(interaction)).toList();

      if (compatibleHandlers.isEmpty) {
        final result = await _executeApiOnly(interaction, timeoutDuration);
        _emitResult(result);
        return result;
      }

      // Create snapshot for rollback with memory management
      final previousState = _getPreviousState(interaction, compatibleHandlers);
      final snapshot = StateSnapshot(
        interactionId: interactionId,
        interaction: interaction,
        previousState: previousState,
        timestamp: DateTime.now(),
        affectedHandlers: compatibleHandlers.map((h) => h.handlerId).toList(),
      );

      _addSnapshot(interactionId, snapshot);

      ABUSResult result;

      if (useOptimistic) {
        await _executeOptimistic(
            interactionId, interaction, compatibleHandlers);
        result =
            await _executeAPI(interaction, compatibleHandlers, timeoutDuration);

        if (!result.isSuccess) {
          await rollback(interactionId);
        } else {
          await _commit(interactionId, interaction, compatibleHandlers);
        }
      } else {
        result =
            await _executeAPI(interaction, compatibleHandlers, timeoutDuration);
        if (result.isSuccess) {
          await _commit(interactionId, interaction, compatibleHandlers);
        }
      }

      // Setup auto-rollback
      if (autoRollback && useOptimistic && result.isSuccess) {
        _setupAutoRollback(interactionId, timeoutDuration);
      }

      _emitResult(result);
      return result;
    } catch (e) {
      final errorResult =
          ABUSResult.error(e.toString(), interactionId: interactionId);

      if (useOptimistic) {
        await rollback(interactionId);
      }

      _emitResult(errorResult);
      return errorResult;
    }
  }

  /// Add snapshot with memory management
  void _addSnapshot(String interactionId, StateSnapshot snapshot) {
    // Remove oldest snapshots if at limit
    while (_snapshots.length >= _maxSnapshots) {
      final oldId = _snapshots.keys.first;
      _snapshots.remove(oldId);
      _rollbackTimers[oldId]?.cancel();
      _rollbackTimers.remove(oldId);
    }

    _snapshots[interactionId] = snapshot;
  }

  /// handler discovery
  void _discoverHandlers(BuildContext context) {
    try {
      context.visitAncestorElements((element) {
        final widget = element.widget;

        if (widget is StatefulWidget) {
          final state = (element as StatefulElement).state;
          if (state is AbusHandler) {
            registerHandler(state as AbusHandler);
          }
        }

        return true;
      });
    } catch (e) {
      debugPrint('Handler discovery failed: $e');
    }
  }

  Future<ABUSResult> _executeApiOnly(
      InteractionDefinition interaction, Duration timeout) async {
    for (final handler in _apiHandlers) {
      try {
        final result =
            await handler(interaction).timeout(timeout, onTimeout: () {
          return ABUSResult.error('Timeout', interactionId: interaction.id);
        });

        // If successful and interaction has payload, preserve it
        if (result.isSuccess && interaction.payload != null) {
          return result.copyWith(payload: interaction.payload);
        }

        return result;
      } catch (e) {
        continue;
      }
    }

    // Error message for debugging
    final errorMsg = _apiHandlers.isEmpty
        ? 'No API handler registered for interaction: ${interaction.id}'
        : 'No API handler found for interaction: ${interaction.id}';
    return ABUSResult.error(errorMsg, interactionId: interaction.id);
  }

  Map<String, dynamic>? _getPreviousState(
    InteractionDefinition interaction,
    List<AbusHandler> handlers,
  ) {
    final states = <String, dynamic>{};

    for (final handler in handlers) {
      try {
        final state = handler.getCurrentState(interaction);
        if (state != null) {
          states[handler.handlerId] = state;
        }
      } catch (e) {
        debugPrint('Failed to get state from ${handler.handlerId}: $e');
      }
    }

    return states.isNotEmpty ? states : null;
  }

  Future<void> _executeOptimistic(
    String interactionId,
    InteractionDefinition interaction,
    List<AbusHandler> handlers,
  ) async {
    final futures = handlers.map((handler) async {
      try {
        await handler.handleOptimistic(interactionId, interaction);
      } catch (e) {
        debugPrint('Optimistic update failed for ${handler.handlerId}: $e');
      }
    });

    await Future.wait(futures);
  }

  Future<ABUSResult> _executeAPI(
    InteractionDefinition interaction,
    List<AbusHandler> handlers,
    Duration timeout,
  ) async {
    // Try handlers first
    for (final handler in handlers) {
      try {
        final apiResult = handler.executeAPI(interaction);
        if (apiResult != null) {
          return await apiResult.timeout(timeout, onTimeout: () {
            return ABUSResult.error('Timeout', interactionId: interaction.id);
          });
        }
      } catch (e) {
        debugPrint('Handler API execution failed for ${handler.handlerId}: $e');
        continue;
      }
    }

    // Try global API handlers
    for (final handler in _apiHandlers) {
      try {
        return await handler(interaction).timeout(timeout, onTimeout: () {
          return ABUSResult.error('Timeout', interactionId: interaction.id);
        });
      } catch (e) {
        continue;
      }
    }

    return ABUSResult.error(
        'No API handler found for interaction: ${interaction.id}',
        interactionId: interaction.id);
  }

  Future<void> _commit(
    String interactionId,
    InteractionDefinition interaction,
    List<AbusHandler> handlers,
  ) async {
    final futures = handlers.map((handler) async {
      try {
        await handler.handleCommit(interactionId, interaction);
      } catch (e) {
        debugPrint('Commit failed for ${handler.handlerId}: $e');
      }
    });

    await Future.wait(futures);
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
  Future<bool> rollback(String interactionId) async {
    final snapshot = _snapshots[interactionId];
    if (snapshot == null) return false;

    bool rollbackSuccess = true;

    // Rollback all affected handlers
    final futures = _handlers
        .where((h) => snapshot.affectedHandlers.contains(h.handlerId))
        .map((handler) async {
      try {
        await handler.handleRollback(interactionId, snapshot.interaction);
      } catch (e) {
        debugPrint('Rollback failed for ${handler.handlerId}: $e');
        rollbackSuccess = false;
      }
    });

    await Future.wait(futures);

    // Emit rollback result
    final rollbackResult = ABUSResult.rollback(
      interactionId: interactionId,
      metadata: {
        'tags': snapshot.interaction.tags.toList(),
        'rollbackSuccess': rollbackSuccess,
      },
    );

    _emitResult(rollbackResult);
    _cleanupInteraction(interactionId);

    return rollbackSuccess;
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

  void _emitResult(ABUSResult result) {
    if (!_disposed && !_resultController.isClosed) {
      _resultController.add(result);
    }
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
    _queue.clear();
  }

  /// Get registered handlers count
  int get handlerCount => _handlers.length;

  /// Get API handlers count
  int get apiHandlerCount => _apiHandlers.length;

  /// Get pending snapshots count
  int get pendingCount => _snapshots.length;

  void dispose() {
    if (_disposed) return;
    _disposed = true;

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

// Helper function for unawaited futures
void unawaited(Future<void> future) {
  // Intentionally empty - just prevents analyzer warnings
}
