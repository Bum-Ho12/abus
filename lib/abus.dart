// lib/abus.dart

import 'package:abus/core/abus_definition.dart';
import 'package:abus/core/abus_manager.dart';
import 'package:abus/core/abus_result.dart';
import 'package:flutter/material.dart';

export 'core/abus_manager.dart';
export 'core/abus_definition.dart';
export 'core/mixins/abus_widget_mixin.dart';
export 'core/mixins/bloc_mixin.dart';
export 'core/mixins/provider_mixin.dart';
export 'core/abus_result.dart';

// Feedback system exports

export 'feedback/feedback_events.dart';
export 'feedback/feedback_interactions.dart';
export 'feedback/feedback_manager.dart';
export 'feedback/feedback_bus.dart';
export 'core/mixins/feedback_widget_mixin.dart';

/// This library provides a queue-based system for managing complex state
/// interactions with automatic rollback capabilities and optimistic UI updates.
///
/// Example usage:
/// ```dart
/// // Register an API handler
/// ABUS.registerApiHandler((interaction) async {
///   // Handle API calls based on interaction
///   return ABUSResult.success(data: {'result': 'ok'});
/// });
///
/// // Execute an interaction
/// final result = await ABUS.execute(
///   InteractionBuilder()
///     .withId('user_update')
///     .withData({'name': 'John'})
///     .build()
/// );
/// ```

/// Main entry point for ABUS operations.
///
/// Provides convenient static methods for common operations like executing
/// interactions, registering handlers, and creating builders.
///
/// This class acts as a facade over [ABUSManager] to simplify usage.
class ABUS {
  /// Private constructor to prevent instantiation.
  ABUS._();

  /// Access to the singleton [ABUSManager] instance.
  static ABUSManager get manager => ABUSManager.instance;

  /// Executes an interaction without Flutter context.
  ///
  /// Use this when you don't need automatic handler discovery from the widget tree.
  ///
  /// Example:
  /// ```dart
  /// final interaction = InteractionBuilder()
  ///   .withId('create_user')
  ///   .withData({'name': 'John', 'email': 'john@example.com'})
  ///   .build();
  ///
  /// final result = await ABUS.execute(interaction);
  /// if (result.isSuccess) {
  ///   print('User created successfully');
  /// }
  /// ```
  ///
  /// Returns a [Future] that completes with an [ABUSResult].
  static Future<ABUSResult> execute(InteractionDefinition interaction) {
    return manager.execute(interaction);
  }

  /// Executes an interaction with Flutter [BuildContext].
  ///
  /// Automatically discovers and registers compatible handlers from the widget tree.
  /// Use this when your handlers are part of widget states (StatefulWidget).
  ///
  /// The [context] is used to traverse the widget tree and find handlers that
  /// implement [AbusHandler].
  ///
  /// Example:
  /// ```dart
  /// // In a widget method
  /// final result = await ABUS.executeWith(interaction, context);
  /// ```
  ///
  /// Parameters:
  /// - [interaction]: The interaction to execute
  /// - [context]: Flutter build context for handler discovery
  ///
  /// Returns a [Future] that completes with an [ABUSResult].
  static Future<ABUSResult> executeWith(
    InteractionDefinition interaction,
    BuildContext context,
  ) {
    return manager.execute(interaction, context: context);
  }

  /// Creates a new [InteractionBuilder] for fluent interaction creation.
  ///
  /// The builder pattern provides a clean way to construct interactions
  /// with various properties like ID, data, timeouts, and tags.
  ///
  /// Example:
  /// ```dart
  /// final interaction = ABUS.builder()
  ///   .withId('update_profile')
  ///   .withData({'name': 'Jane'})
  ///   .withTimeout(Duration(seconds: 10))
  ///   .withOptimistic(true)
  ///   .addTag('profile')
  ///   .build();
  /// ```
  ///
  /// Returns a new [InteractionBuilder] instance.
  static InteractionBuilder builder() => InteractionBuilder();

  /// Registers a global API handler function.
  ///
  /// Global API handlers are called when no specific handler is found for
  /// an interaction. They provide a fallback mechanism for API calls.
  ///
  /// The [handler] function receives an [InteractionDefinition] and should
  /// return a [Future<ABUSResult>] containing the API response.
  ///
  /// Example:
  /// ```dart
  /// ABUS.registerApiHandler((interaction) async {
  ///   switch (interaction.id) {
  ///     case 'create_user':
  ///       final response = await http.post('/users', body: interaction.toJson());
  ///       return ABUSResult.success(data: response.data);
  ///     default:
  ///       return ABUSResult.error('Unhandled interaction: ${interaction.id}');
  ///   }
  /// });
  /// ```
  ///
  /// Parameters:
  /// - [handler]: Function that handles API calls for interactions
  static void registerApiHandler(
    Future<ABUSResult> Function(InteractionDefinition) handler,
  ) {
    manager.registerApiHandler(handler);
  }

  /// Registers a handler instance.
  ///
  /// Handlers implement [AbusHandler] and provide custom logic for
  /// optimistic updates, rollbacks, commits, and API calls.
  ///
  /// Example:
  /// ```dart
  /// class UserHandler extends CustomAbusHandler {
  ///   @override
  ///   Future<void> handleOptimistic(String id, InteractionDefinition interaction) async {
  ///     // Update UI optimistically
  ///   }
  ///
  ///   @override
  ///   Future<ABUSResult> executeAPI(InteractionDefinition interaction) async {
  ///     // Make API call
  ///     return ABUSResult.success();
  ///   }
  /// }
  ///
  /// ABUS.registerHandler(UserHandler());
  /// ```
  ///
  /// Parameters:
  /// - [handler]: Handler instance implementing [AbusHandler]
  static void registerHandler(AbusHandler handler) {
    manager.registerHandler(handler);
  }
}
