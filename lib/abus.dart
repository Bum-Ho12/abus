// lib/abus.dart
import 'package:abus/core/abus_definition.dart';
import 'package:abus/core/abus_manager.dart';
import 'package:abus/core/abus_result.dart';
import 'package:flutter/material.dart';

export 'core/abus_manager.dart';
export 'core/abus_definition.dart';

/// Convenience class for common operations
class ABUS {
  static ABUSManager get manager => ABUSManager.instance;

  /// Quick execution without context
  static Future<InteractionResult> execute(InteractionDefinition interaction) {
    return manager.execute(interaction);
  }

  /// Quick execution with context
  static Future<InteractionResult> executeWith(
    InteractionDefinition interaction,
    BuildContext context,
  ) {
    return manager.execute(interaction, context: context);
  }

  /// Create interaction builder
  static InteractionBuilder builder() => InteractionBuilder();

  /// Register global API handler
  static void registerApiHandler(
    Future<InteractionResult> Function(InteractionDefinition) handler,
  ) {
    manager.registerApiHandler(handler);
  }

  /// Register handler
  static void registerHandler(AbusHandler handler) {
    manager.registerHandler(handler);
  }
}
