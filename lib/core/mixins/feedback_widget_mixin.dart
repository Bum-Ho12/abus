// lib/core/mixins/feedback_widget_mixin.dart

import 'package:abus/core/mixins/abus_widget_mixin.dart';
import 'package:abus/core/abus_result.dart';
import 'package:abus/feedback/feedback_events.dart';
import 'package:flutter/material.dart';

/// Mixin for widgets that need to react to feedback queue changes
mixin FeedbackWidgetMixin<T extends StatefulWidget> on AbusWidgetMixin<T> {
  /// Current feedback queue
  List<FeedbackEvent> get feedbackQueue => _currentQueue;
  List<FeedbackEvent> _currentQueue = [];

  @override
  AbusUpdateConfig get abusConfig => const AbusUpdateConfig(
        interactionIds: {'feedback_queue_changed'},
        rebuildOnSuccess: true,
        rebuildOnError: false,
        rebuildOnRollback: false,
      );

  @override
  void onAbusResult(ABUSResult result) {
    super.onAbusResult(result);

    // Handle feedback queue updates
    if (result.interactionId == 'feedback_queue_changed' &&
        result.metadata?['type'] == 'queue_update') {
      _updateFeedbackQueue(result);
      onFeedbackQueueChanged(_currentQueue);
    }
  }

  void _updateFeedbackQueue(ABUSResult result) {
    final queueData = result.data?['queue'] as List<dynamic>?;
    if (queueData != null) {
      _currentQueue = queueData
          .cast<Map<String, dynamic>>()
          .map((eventJson) => _createEventFromJson(eventJson))
          .toList();
    }
  }

  FeedbackEvent _createEventFromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'SnackbarEvent':
        return SnackbarEvent(
          id: json['id'],
          message: json['message'],
          type: SnackbarType.values
              .firstWhere((t) => t.name == json['snackbarType']),
          actionLabel: json['actionLabel'],
          priority: json['priority'] ?? 0,
          duration: json['duration'] != null
              ? Duration(milliseconds: json['duration'])
              : null,
          tags: Set<String>.from(json['tags'] ?? []),
          dismissible: json['dismissible'] ?? true,
          metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
        );
      case 'BannerEvent':
        return BannerEvent(
          id: json['id'],
          message: json['message'],
          type:
              BannerType.values.firstWhere((t) => t.name == json['bannerType']),
          priority: json['priority'] ?? 1,
          duration: json['duration'] != null
              ? Duration(milliseconds: json['duration'])
              : null,
          tags: Set<String>.from(json['tags'] ?? []),
          dismissible: json['dismissible'] ?? true,
          metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
        );
      case 'ToastEvent':
        return ToastEvent(
          id: json['id'],
          message: json['message'],
          type: ToastType.values.firstWhere((t) => t.name == json['toastType']),
          priority: json['priority'] ?? 0,
          duration: json['duration'] != null
              ? Duration(milliseconds: json['duration'])
              : null,
          tags: Set<String>.from(json['tags'] ?? []),
          dismissible: json['dismissible'] ?? false,
          metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
        );
      default:
        throw ArgumentError('Unknown feedback event type: $type');
    }
  }

  /// Override to handle feedback queue changes
  void onFeedbackQueueChanged(List<FeedbackEvent> queue) {}

  /// Get events of specific type
  List<E> getEventsOfType<E extends FeedbackEvent>() {
    return _currentQueue.whereType<E>().toList();
  }

  /// Get snackbar events
  List<SnackbarEvent> get snackbarEvents => getEventsOfType<SnackbarEvent>();

  /// Get banner events
  List<BannerEvent> get bannerEvents => getEventsOfType<BannerEvent>();

  /// Get toast events
  List<ToastEvent> get toastEvents => getEventsOfType<ToastEvent>();
}
