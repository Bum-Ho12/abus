// lib/abus.dart
import 'package:abus/core/abus_definition.dart';
import 'package:abus/core/abus_manager.dart';
import 'package:abus/core/abus_result.dart';
import 'package:flutter/material.dart';
// import 'package:abus/core/mixins/abus_widget_mixin.dart';

export 'core/abus_manager.dart';
export 'core/abus_definition.dart';
export 'core/mixins/abus_widget_mixin.dart';

/// Convenience class for common operations
class ABUS {
  static ABUSManager get manager => ABUSManager.instance;

  /// Quick execution without context
  static Future<ABUSResult> execute(InteractionDefinition interaction) {
    return manager.execute(interaction);
  }

  /// Quick execution with context
  static Future<ABUSResult> executeWith(
    InteractionDefinition interaction,
    BuildContext context,
  ) {
    return manager.execute(interaction, context: context);
  }

  /// Create interaction builder
  static InteractionBuilder builder() => InteractionBuilder();

  /// Register global API handler
  static void registerApiHandler(
    Future<ABUSResult> Function(InteractionDefinition) handler,
  ) {
    manager.registerApiHandler(handler);
  }

  /// Register handler
  static void registerHandler(AbusHandler handler) {
    manager.registerHandler(handler);
  }
}
