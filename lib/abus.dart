// lib/abus.dart

export 'core/abus_manager.dart';
export 'core/abus_definition.dart';
export 'core/abus_result.dart';
export 'adapters/state_adapter.dart';
export 'adapters/ui_notifier.dart';
export 'adapters/provider_adapter.dart';
export 'adapters/getit_adapter.dart';
// Conditional exports - only export if dependency is available
export 'adapters/bloc_adapter.dart'
    if (dart.library.developer) 'adapters/bloc_adapter_stub.dart';
