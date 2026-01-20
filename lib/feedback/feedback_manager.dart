// lib/feedback/feedback_manager.dart

import 'dart:async';
import 'package:abus/core/abus_definition.dart';
import 'package:abus/core/abus_manager.dart';
import 'package:abus/core/abus_result.dart';
import 'package:abus/feedback/feedback_events.dart';
import 'package:abus/feedback/feedback_interactions.dart';

/// Core feedback manager that handles the queue and deduplication
class FeedbackManager extends CustomAbusHandler {
  static FeedbackManager? _instance;
  static FeedbackManager get instance => _instance ??= FeedbackManager._();

  FeedbackManager._();

  // Internal state
  final List<FeedbackEvent> _queue = [];
  final Set<String> _activeDeduplicationKeys = {};
  final Map<String, FeedbackEvent> _activeEvents = {};
  StreamSubscription? _storageSubscription;

  // Storage key
  static const String _storageKey = 'abus_feedback_queue';

  // Configuration
  static const int _maxQueueSize = 20;
  static const Duration _deduplicationWindow = Duration(seconds: 5);
  final Map<String, DateTime> _lastShownTimes = {};

  @override
  String get handlerId => 'FeedbackManager';

  @override
  bool canHandle(InteractionDefinition interaction) {
    return interaction.id.startsWith('show_feedback') ||
        interaction.id == 'dismiss_feedback' ||
        interaction.id == 'sync_feedback';
  }

  /// Initialize storage and load existing queue
  Future<void> initStorage() async {
    final storage = ABUSManager.instance.storage;
    if (storage == null) return;

    // Load initial data
    final data = await storage.load(_storageKey);
    if (data != null && data['queue'] is List) {
      _updateFromSerializedData(data);
    }

    // Watch for external changes (cross-app sync)
    _storageSubscription?.cancel();
    _storageSubscription = storage.watch(_storageKey).listen((data) {
      if (data != null) {
        _updateFromSerializedData(data, notify: true);
      }
    });
  }

  void _updateFromSerializedData(Map<String, dynamic> data,
      {bool notify = false}) {
    final serializedQueue = data['queue'] as List;
    _queue.clear();
    _activeEvents.clear();

    for (final item in serializedQueue) {
      try {
        final interaction = ShowFeedbackInteraction(
          event: _deserializeEvent(item as Map<String, dynamic>),
        );
        final event = interaction.event;
        _queue.add(event);
        _activeEvents[event.id] = event;
        _activeDeduplicationKeys.add(event.deduplicationKey);
      } catch (e) {
        // Skip invalid events
      }
    }

    // Sort queue
    _queue.sort((a, b) => b.priority.compareTo(a.priority));

    if (notify) {
      _notifyQueueChanged(persist: false);
    }
  }

  FeedbackEvent _deserializeEvent(Map<String, dynamic> data) {
    final type = data['type'] as String;
    switch (type) {
      case 'SnackbarEvent':
        return ShowFeedbackInteraction.createSnackbarEvent(data);
      case 'BannerEvent':
        return ShowFeedbackInteraction.createBannerEvent(data);
      case 'ToastEvent':
        return ShowFeedbackInteraction.createToastEvent(data);
      default:
        throw ArgumentError('Unknown feedback event type: $type');
    }
  }

  @override
  Future<void> handleOptimistic(
      String interactionId, InteractionDefinition interaction) async {
    if (interaction is ShowFeedbackInteraction) {
      await _handleShowFeedback(interaction);
    } else if (interaction is DismissFeedbackInteraction) {
      await _handleDismissFeedback(interaction);
    }
  }

  Future<void> _handleShowFeedback(ShowFeedbackInteraction interaction) async {
    final event = interaction.event;
    final replace = interaction.data['replace'] as bool;

    // Check deduplication
    if (!replace && _shouldDeduplicate(event)) {
      return; // Skip duplicate
    }

    // Add to queue with size management
    _addToQueue(event, replace);

    // Mark as active for deduplication
    _activeDeduplicationKeys.add(event.deduplicationKey);
    _lastShownTimes[event.deduplicationKey] = DateTime.now();
    _activeEvents[event.id] = event;

    // Notify listeners
    _notifyQueueChanged();
  }

  Future<void> _handleDismissFeedback(
      DismissFeedbackInteraction interaction) async {
    final eventId = interaction.data['eventId'] as String?;
    final tags = interaction.data['tags'] as List?;
    final dismissAll = interaction.data['dismissAll'] as bool;

    if (dismissAll) {
      _queue.clear();
      _activeEvents.clear();
    } else if (eventId != null) {
      _queue.removeWhere((e) => e.id == eventId);
      _activeEvents.remove(eventId);
    } else if (tags != null) {
      final tagSet = Set<String>.from(tags);
      _queue.removeWhere((e) => e.tags.any((tag) => tagSet.contains(tag)));
      _activeEvents
          .removeWhere((id, e) => e.tags.any((tag) => tagSet.contains(tag)));
    }

    _notifyQueueChanged();
  }

  bool _shouldDeduplicate(FeedbackEvent event) {
    final key = event.deduplicationKey;
    final lastShown = _lastShownTimes[key];

    if (lastShown == null) return false;

    final timeSinceLastShown = DateTime.now().difference(lastShown);
    return timeSinceLastShown < _deduplicationWindow;
  }

  void _addToQueue(FeedbackEvent event, bool replace) {
    if (replace) {
      // Remove existing events of same type
      _queue.removeWhere((e) => e.runtimeType == event.runtimeType);
    }

    // Add new event
    _queue.add(event);

    // Sort by priority (higher first)
    _queue.sort((a, b) => b.priority.compareTo(a.priority));

    // Enforce size limit
    while (_queue.length > _maxQueueSize) {
      final removed = _queue.removeLast(); // Remove lowest priority
      _activeEvents.remove(removed.id);
    }
  }

  Future<void> _persistQueue() async {
    final storage = ABUSManager.instance.storage;
    if (storage == null) return;

    await storage.save(_storageKey, {
      'queue': _queue.map((e) => e.toJson()).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  void _notifyQueueChanged({bool persist = true}) {
    if (persist) {
      _persistQueue();
    }
    // Emit a custom result through the ABUS result stream to notify widgets
    final result = ABUSResult.success(
      data: {
        'queue': _queue.map((e) => e.toJson()).toList(),
        'activeEvents': _activeEvents.keys.toList(),
        'queueSize': _queue.length,
      },
      interactionId: 'feedback_queue_changed',
      metadata: {
        'type': 'queue_update',
        'timestamp': DateTime.now().toIso8601String(),
        'tags': ['feedback', 'queue', 'update'],
      },
    );

    // Using the existing ABUS manager to emit the result
    ABUSManager.instance.emitResult(result);
  }

  // Public API
  List<FeedbackEvent> get queue => List.unmodifiable(_queue);
  Map<String, FeedbackEvent> get activeEvents =>
      Map.unmodifiable(_activeEvents);

  void clearQueue() {
    _queue.clear();
    _activeEvents.clear();
    _activeDeduplicationKeys.clear();
    _cleanupDeduplication();
    _notifyQueueChanged();
  }

  // Clean up old deduplication entries
  void _cleanupDeduplication() {
    final now = DateTime.now();
    _lastShownTimes.removeWhere(
        (key, time) => now.difference(time) > _deduplicationWindow);

    _activeDeduplicationKeys
        .removeWhere((key) => !_lastShownTimes.containsKey(key));
  }
}
