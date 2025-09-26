// lib/cross_app/cross_app_widget_mixin.dart

import 'package:abus/core/mixins/abus_widget_mixin.dart';
import 'package:abus/core/abus_result.dart';
import 'package:abus/cross_app/app_communication_manager.dart';
import 'package:abus/cross_app/app_event.dart';
import 'package:flutter/material.dart';

/// Mixin for widgets that need to react to cross-app events
mixin CrossAppWidgetMixin<T extends StatefulWidget> on AbusWidgetMixin<T> {
  /// Filter for specific app event types
  Set<Type>? get appEventTypes => null;

  /// Filter for specific source apps
  Set<String>? get sourceApps => null;

  @override
  AbusUpdateConfig get abusConfig => const AbusUpdateConfig(
        interactionIds: {'receive_app_event'},
        rebuildOnSuccess: true,
        rebuildOnError: false,
      );

  @override
  void onAbusResult(ABUSResult result) {
    super.onAbusResult(result);

    if (result.interactionId == 'receive_app_event' && result.isSuccess) {
      final eventData = result.data?['event'] as Map<String, dynamic>?;
      if (eventData != null) {
        final appEvent = AppEvent.fromJson(eventData);

        // Apply filters
        if (appEventTypes != null &&
            !appEventTypes!.contains(appEvent.runtimeType)) {
          return;
        }

        if (sourceApps != null && !sourceApps!.contains(appEvent.sourceApp)) {
          return;
        }

        onAppEventReceived(appEvent);
      }
    }
  }

  /// Override to handle received app events
  void onAppEventReceived(AppEvent event) {}

  /// Convenience methods
  Future<ABUSResult> sendIntent({
    required String action,
    String? targetApp,
    String? category,
    Map<String, dynamic> extras = const {},
    Set<String> permissions = const {},
  }) {
    return AppCommunicationManager.instance.sendIntent(
      action: action,
      targetApp: targetApp,
      category: category,
      extras: extras,
      permissions: permissions,
    );
  }

  Future<ABUSResult> openUrl({
    required String scheme,
    required String path,
    Map<String, String> queryParams = const {},
    String? targetApp,
    Set<String> permissions = const {},
  }) {
    return AppCommunicationManager.instance.openUrl(
      scheme: scheme,
      path: path,
      queryParams: queryParams,
      targetApp: targetApp,
      permissions: permissions,
    );
  }
}
