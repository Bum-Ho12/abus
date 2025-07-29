// lib/adapters/ui_notifier.dart

import 'package:abus/core/abus_definition.dart';
import 'package:abus/core/abus_result.dart';

/// Interface for UI notifications
abstract class UINotifier {
  /// Notify when interaction starts
  void onInteractionStarted(
      String interactionId, InteractionDefinition interaction) {}

  /// Notify when interaction completes
  void onInteractionCompleted(String interactionId, InteractionResult result) {}

  /// Notify when rollback occurs
  void onRollback(String interactionId, InteractionDefinition interaction) {}

  /// Check if this notifier should handle the interaction
  bool shouldHandle(InteractionDefinition interaction) => true;
}
