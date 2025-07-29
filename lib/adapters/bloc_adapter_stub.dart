// lib/adapters/bloc_adapter_stub.dart
import 'package:abus/core/abus_definition.dart';

import 'state_adapter.dart';

/// Stub implementation when flutter_bloc is not available
class BlocAdapter extends StateAdapter {
  BlocAdapter() {
    throw UnsupportedError('BlocAdapter requires flutter_bloc dependency. '
        'Add "flutter_bloc: version" to your pubspec.yaml and '
        'import "package:abus/abus_bloc.dart" instead of "package:abus/abus.dart"');
  }

  @override
  String get name => 'BlocAdapter';

  @override
  bool canHandle(InteractionDefinition interaction) => false;

  @override
  Future<void> updateOptimistic(
      String interactionId, InteractionDefinition interaction) async {}

  @override
  Future<void> rollback(
      String interactionId, InteractionDefinition interaction) async {}

  @override
  Future<void> commit(
      String interactionId, InteractionDefinition interaction) async {}
}
