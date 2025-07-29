// lib/adapters/state_adapter.dart

import 'package:abus/core/abus_definition.dart';
import 'package:abus/core/abus_result.dart';

/// Generic interface for state management adapters
abstract class StateAdapter {
  /// Unique name for this adapter
  String get name;

  /// Priority for adapter selection (higher = more priority)
  int get priority => 0;

  /// Check if this adapter can handle the interaction
  bool canHandle(InteractionDefinition interaction);

  /// Apply optimistic update
  Future<void> updateOptimistic(
    String interactionId,
    InteractionDefinition interaction,
  );

  /// Rollback changes
  Future<void> rollback(
    String interactionId,
    InteractionDefinition interaction,
  );

  /// Commit changes after successful API call
  Future<void> commit(
    String interactionId,
    InteractionDefinition interaction,
  );

  /// Optional: Execute the actual API call
  Future<InteractionResult>? executeAPI(InteractionDefinition interaction) =>
      null;

  /// Optional: Get current state for rollback
  Map<String, dynamic>? getCurrentState(InteractionDefinition interaction) =>
      null;
}
