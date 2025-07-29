// lib/adapters/getit_adapter.dart
import 'package:abus/core/abus_definition.dart';
import 'package:abus/core/abus_result.dart';

import 'state_adapter.dart';

/// GetIt dependency injection adapter
class GetItAdapter extends StateAdapter {
  final dynamic service;
  final String Function(InteractionDefinition) _idExtractor;
  final bool Function(InteractionDefinition) _canHandleChecker;
  final Future<void> Function(
          dynamic service, String id, InteractionDefinition interaction)
      _optimisticHandler;
  final Future<void> Function(
          dynamic service, String id, InteractionDefinition interaction)
      _rollbackHandler;
  final Future<void> Function(
          dynamic service, String id, InteractionDefinition interaction)
      _commitHandler;
  final Future<InteractionResult> Function(InteractionDefinition interaction)?
      _apiHandler;

  GetItAdapter({
    required this.service,
    required String Function(InteractionDefinition) idExtractor,
    required bool Function(InteractionDefinition) canHandle,
    required Future<void> Function(
            dynamic service, String id, InteractionDefinition interaction)
        onOptimistic,
    required Future<void> Function(
            dynamic service, String id, InteractionDefinition interaction)
        onRollback,
    required Future<void> Function(
            dynamic service, String id, InteractionDefinition interaction)
        onCommit,
    Future<InteractionResult> Function(InteractionDefinition interaction)?
        onApiCall,
  })  : _idExtractor = idExtractor,
        _canHandleChecker = canHandle,
        _optimisticHandler = onOptimistic,
        _rollbackHandler = onRollback,
        _commitHandler = onCommit,
        _apiHandler = onApiCall;

  @override
  String get name => 'GetItAdapter<${service.runtimeType}>';

  @override
  bool canHandle(InteractionDefinition interaction) =>
      _canHandleChecker(interaction);

  @override
  Future<void> updateOptimistic(
      String interactionId, InteractionDefinition interaction) {
    final id = _idExtractor(interaction);
    return _optimisticHandler(service, id, interaction);
  }

  @override
  Future<void> rollback(
      String interactionId, InteractionDefinition interaction) {
    final id = _idExtractor(interaction);
    return _rollbackHandler(service, id, interaction);
  }

  @override
  Future<void> commit(String interactionId, InteractionDefinition interaction) {
    final id = _idExtractor(interaction);
    return _commitHandler(service, id, interaction);
  }

  @override
  Future<InteractionResult>? executeAPI(InteractionDefinition interaction) =>
      _apiHandler?.call(interaction);
}
