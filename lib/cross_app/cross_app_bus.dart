// lib/cross_app/cross_app_bus.dart

import 'package:abus/abus.dart';

/// Main API for cross-app communication
class CrossAppBus {
  CrossAppBus._();

  /// Initialize cross-app communication
  static Future<void> initialize({
    required String appId,
    Set<String> permissions = const {},
    Map<String, String>? sharedStoragePaths,
  }) async {
    await AppCommunicationManager.instance.initialize(
      appId: appId,
      permissions: permissions,
      sharedStoragePaths: sharedStoragePaths,
    );

    // Register the manager with ABUS
    ABUS.registerHandler(AppCommunicationManager.instance);
  }

  /// Send an Android-style intent
  static Future<ABUSResult> sendIntent({
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

  /// Open a URL scheme / app link
  static Future<ABUSResult> openUrl({
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

  /// Share data between apps
  static Future<ABUSResult> shareData({
    required String dataType,
    required Map<String, dynamic> payload,
    String? targetApp,
    String? filePath,
    Set<String> permissions = const {},
  }) {
    return AppCommunicationManager.instance.shareData(
      dataType: dataType,
      payload: payload,
      targetApp: targetApp,
      filePath: filePath,
      permissions: permissions,
    );
  }

  /// Add a custom event filter
  static void addEventFilter(String filterId, bool Function(AppEvent) filter) {
    AppCommunicationManager.instance.addEventFilter(filterId, filter);
  }

  /// Remove an event filter
  static void removeEventFilter(String filterId) {
    AppCommunicationManager.instance.removeEventFilter(filterId);
  }
}
