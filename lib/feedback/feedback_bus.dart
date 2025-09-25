// lib/feedback/feedback_bus.dart

import 'dart:ui';

import 'package:abus/abus.dart';

/// Main API for the feedback system
class FeedbackBus {
  FeedbackBus._();

  /// Show a snackbar
  static Future<ABUSResult> showSnackbar({
    required String message,
    SnackbarType type = SnackbarType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    Set<String>? tags,
    int priority = 0,
    bool replace = false,
  }) {
    final event = SnackbarEvent(
      id: 'snackbar_${DateTime.now().millisecondsSinceEpoch}',
      message: message,
      type: type,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      tags: tags ?? {},
      priority: priority,
    );

    return ABUS
        .execute(ShowFeedbackInteraction(event: event, replace: replace));
  }

  /// Show a banner
  static Future<ABUSResult> showBanner({
    required String message,
    BannerType type = BannerType.info,
    List<BannerAction> actions = const [],
    Duration? duration,
    Set<String>? tags,
    int priority = 1,
    bool replace = false,
  }) {
    final event = BannerEvent(
      id: 'banner_${DateTime.now().millisecondsSinceEpoch}',
      message: message,
      type: type,
      actions: actions,
      duration: duration,
      tags: tags ?? {},
      priority: priority,
    );

    return ABUS
        .execute(ShowFeedbackInteraction(event: event, replace: replace));
  }

  /// Show a toast
  static Future<ABUSResult> showToast({
    required String message,
    ToastType type = ToastType.info,
    Duration? duration,
    Set<String>? tags,
    int priority = 0,
    bool replace = false,
  }) {
    final event = ToastEvent(
      id: 'toast_${DateTime.now().millisecondsSinceEpoch}',
      message: message,
      type: type,
      duration: duration,
      tags: tags ?? {},
      priority: priority,
    );

    return ABUS
        .execute(ShowFeedbackInteraction(event: event, replace: replace));
  }

  /// Dismiss feedback by ID
  static Future<ABUSResult> dismiss(String eventId) {
    return ABUS.execute(DismissFeedbackInteraction(eventId: eventId));
  }

  /// Dismiss feedback by tags
  static Future<ABUSResult> dismissByTags(Set<String> tags) {
    return ABUS.execute(DismissFeedbackInteraction(tags: tags));
  }

  /// Dismiss all feedback
  static Future<ABUSResult> dismissAll() {
    return ABUS.execute(DismissFeedbackInteraction(dismissAll: true));
  }

  /// Get current queue state
  static List<FeedbackEvent> get queue => FeedbackManager.instance.queue;

  /// Initialize the feedback system
  static void initialize() {
    ABUS.registerHandler(FeedbackManager.instance);
  }
}
