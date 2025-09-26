// lib/cross_app/app_interactions.dart

import 'package:abus/core/abus_definition.dart';
import 'package:abus/cross_app/app_event.dart';

/// Interaction for sending cross-app events
class SendAppEventInteraction extends GenericInteraction {
  SendAppEventInteraction({
    required AppEvent event,
    Duration? timeout,
  }) : super(
          id: 'send_app_event',
          data: {
            'event': event.toJson(),
            'eventType': event.runtimeType.toString(),
          },
          timeout: timeout ?? const Duration(seconds: 10),
          supportsOptimistic: false, // Cross-app should be reliable
          tags: {'cross_app', 'send'},
        );

  AppEvent get event => AppEvent.fromJson(data['event']);
}

/// Interaction for receiving cross-app events
class ReceiveAppEventInteraction extends GenericInteraction {
  ReceiveAppEventInteraction({
    required AppEvent event,
  }) : super(
          id: 'receive_app_event',
          data: {
            'event': event.toJson(),
            'eventType': event.runtimeType.toString(),
          },
          supportsOptimistic: true, // Can update UI immediately
          tags: {'cross_app', 'receive'},
        );

  AppEvent get event => AppEvent.fromJson(data['event']);
}
