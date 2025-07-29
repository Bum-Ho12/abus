// lib/core/abus_manager.dart
import 'dart:async';
import 'package:abus/adapters/state_adapter.dart';
import 'package:abus/adapters/ui_notifier.dart';
import 'package:flutter/foundation.dart';
import 'abus_definition.dart';
import 'abus_result.dart';

/// State change snapshot for rollback capability
class StateSnapshot {
  final String interactionId;
  final InteractionDefinition interaction;
  final Map<String, dynamic>? previousState;
  final DateTime timestamp;
  final List<String> affectedAdapters;

  StateSnapshot({
    required this.interactionId,
    required this.interaction,
    this.previousState,
    required this.timestamp,
    required this.affectedAdapters,
  });
}

/// Main interaction manager
class InteractionManager {
  static InteractionManager? _instance;
  static InteractionManager get instance =>
      _instance ??= InteractionManager._();

  InteractionManager._();

  final List<StateAdapter> _adapters = [];
  final List<UINotifier> _uiNotifiers = [];
  final Map<String, StateSnapshot> _snapshots = {};
  final Map<String, Timer> _rollbackTimers = {};
  final StreamController<InteractionResult> _resultController =
      StreamController<InteractionResult>.broadcast();

  Stream<InteractionResult> get resultStream => _resultController.stream;

  /// Register a state management adapter
  void registerAdapter(StateAdapter adapter) {
    _adapters.removeWhere((a) => a.name == adapter.name);
    _adapters.add(adapter);
    // Sort by priority (higher first)
    _adapters.sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// Register multiple adapters at once
  void registerAdapters(List<StateAdapter> adapters) {
    for (final adapter in adapters) {
      registerAdapter(adapter);
    }
  }

  /// Register a UI notifier
  void registerUINotifier(UINotifier notifier) {
    _uiNotifiers.add(notifier);
  }

  /// Register multiple UI notifiers at once
  void registerUINotifiers(List<UINotifier> notifiers) {
    _uiNotifiers.addAll(notifiers);
  }

  /// Execute an interaction with optimistic updates and rollback capability
  Future<InteractionResult> execute(
    InteractionDefinition interaction, {
    bool? optimistic,
    Duration? timeout,
    bool autoRollback = true,
  }) async {
    final useOptimistic = optimistic ?? interaction.supportsOptimistic;
    final timeoutDuration =
        timeout ?? interaction.timeout ?? const Duration(seconds: 30);

    final interactionId =
        '${interaction.id}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Find compatible adapters
      final compatibleAdapters =
          _adapters.where((adapter) => adapter.canHandle(interaction)).toList();

      if (compatibleAdapters.isEmpty) {
        throw Exception(
            'No compatible adapter found for interaction: ${interaction.id}');
      }

      // Notify UI start
      _notifyUIStart(interactionId, interaction);

      // Create snapshot for rollback
      final previousState = _getPreviousState(interaction, compatibleAdapters);
      final snapshot = StateSnapshot(
        interactionId: interactionId,
        interaction: interaction,
        previousState: previousState,
        timestamp: DateTime.now(),
        affectedAdapters: compatibleAdapters.map((a) => a.name).toList(),
      );
      _snapshots[interactionId] = snapshot;

      InteractionResult result;

      if (useOptimistic) {
        // Execute optimistic updates first
        await _executeOptimistic(
            interactionId, interaction, compatibleAdapters);

        // Then execute actual API call
        result =
            await _executeAPI(interaction, compatibleAdapters, timeoutDuration);

        if (!result.isSuccess) {
          // Rollback on failure
          await rollback(interactionId);
        } else {
          // Commit on success
          await _commit(interactionId, interaction, compatibleAdapters);
        }
      } else {
        // Execute API call directly
        result =
            await _executeAPI(interaction, compatibleAdapters, timeoutDuration);

        if (result.isSuccess) {
          await _commit(interactionId, interaction, compatibleAdapters);
        }
      }

      // Setup auto-rollback if enabled and optimistic
      if (autoRollback && useOptimistic && result.isSuccess) {
        _setupAutoRollback(interactionId, timeoutDuration);
      }

      // Notify UI completion
      _notifyUIComplete(interactionId, result);
      _resultController.add(result);

      return result;
    } catch (e) {
      final errorResult =
          InteractionResult.error(e.toString(), interactionId: interactionId);

      // Rollback on error if optimistic was used
      if (useOptimistic) {
        await rollback(interactionId);
      }

      _notifyUIComplete(interactionId, errorResult);
      _resultController.add(errorResult);
      return errorResult;
    }
  }

  Map<String, dynamic>? _getPreviousState(
      InteractionDefinition interaction, List<StateAdapter> adapters) {
    final states = <String, dynamic>{};
    for (final adapter in adapters) {
      final state = adapter.getCurrentState(interaction);
      if (state != null) {
        states[adapter.name] = state;
      }
    }
    return states.isNotEmpty ? states : null;
  }

  Future<void> _executeOptimistic(
    String interactionId,
    InteractionDefinition interaction,
    List<StateAdapter> adapters,
  ) async {
    for (final adapter in adapters) {
      try {
        await adapter.updateOptimistic(interactionId, interaction);
      } catch (e) {
        debugPrint('Optimistic update failed for ${adapter.name}: $e');
      }
    }
  }

  Future<InteractionResult> _executeAPI(
    InteractionDefinition interaction,
    List<StateAdapter> adapters,
    Duration timeout,
  ) async {
    // Try to find an adapter that can execute the API call
    for (final adapter in adapters) {
      final apiResult = adapter.executeAPI(interaction);
      if (apiResult != null) {
        return await apiResult.timeout(timeout, onTimeout: () {
          return InteractionResult.error('Timeout',
              interactionId: interaction.id);
        });
      }
    }

    // If no adapter can execute API, simulate or throw error
    throw Exception(
        'No adapter can execute API for interaction: ${interaction.id}');
  }

  Future<void> _commit(
    String interactionId,
    InteractionDefinition interaction,
    List<StateAdapter> adapters,
  ) async {
    for (final adapter in adapters) {
      try {
        await adapter.commit(interactionId, interaction);
      } catch (e) {
        debugPrint('Commit failed for ${adapter.name}: $e');
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

    for (final adapterName in snapshot.affectedAdapters) {
      final adapter = _adapters.firstWhere(
        (a) => a.name == adapterName,
        orElse: () => throw Exception('Adapter $adapterName not found'),
      );

      try {
        await adapter.rollback(interactionId, snapshot.interaction);
      } catch (e) {
        debugPrint('Rollback failed for ${adapter.name}: $e');
      }
    }

    _notifyUIRollback(interactionId, snapshot.interaction);
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

  void _notifyUIStart(String interactionId, InteractionDefinition interaction) {
    for (final notifier in _uiNotifiers) {
      if (notifier.shouldHandle(interaction)) {
        try {
          notifier.onInteractionStarted(interactionId, interaction);
        } catch (e) {
          debugPrint('UI start notification failed: $e');
        }
      }
    }
  }

  void _notifyUIComplete(String interactionId, InteractionResult result) {
    for (final notifier in _uiNotifiers) {
      try {
        notifier.onInteractionCompleted(interactionId, result);
      } catch (e) {
        debugPrint('UI completion notification failed: $e');
      }
    }
  }

  void _notifyUIRollback(
      String interactionId, InteractionDefinition interaction) {
    for (final notifier in _uiNotifiers) {
      if (notifier.shouldHandle(interaction)) {
        try {
          notifier.onRollback(interactionId, interaction);
        } catch (e) {
          debugPrint('UI rollback notification failed: $e');
        }
      }
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
  }

  void dispose() {
    clearPending();
    _adapters.clear();
    _uiNotifiers.clear();
    _resultController.close();
  }

  /// Reset to new instance (useful for testing)
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}
