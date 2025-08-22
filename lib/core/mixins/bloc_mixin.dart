// lib/core/mixins/bloc_mixin.dart
import 'package:abus/core/abus_definition.dart';
import 'package:abus/core/abus_manager.dart';
import 'package:abus/core/abus_result.dart';

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
