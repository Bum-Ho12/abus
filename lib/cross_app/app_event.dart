// lib/cross_app/app_event.dart

/// Base class for cross-application events
abstract class AppEvent {
  final String id;
  final String sourceApp;
  final String? targetApp; // null for broadcast
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final Set<String> permissions;

  const AppEvent({
    required this.id,
    required this.sourceApp,
    this.targetApp,
    required this.data,
    required this.timestamp,
    this.permissions = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceApp': sourceApp,
        'targetApp': targetApp,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'permissions': permissions.toList(),
        'type': runtimeType.toString(),
      };

  factory AppEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'IntentEvent':
        return IntentEvent.fromJson(json);
      case 'UrlEvent':
        return UrlEvent.fromJson(json);
      case 'DataShareEvent':
        return DataShareEvent.fromJson(json);
      default:
        return GenericAppEvent.fromJson(json);
    }
  }
}

/// Android Intent-style event
class IntentEvent extends AppEvent {
  final String action;
  final String? category;
  final Map<String, dynamic> extras;

  IntentEvent({
    required super.id,
    required super.sourceApp,
    required this.action,
    this.category,
    this.extras = const {},
    super.targetApp,
    super.permissions,
  }) : super(
          data: {
            'action': action,
            'category': category,
            'extras': extras,
          },
          timestamp: DateTime.now(),
        );

  factory IntentEvent.fromJson(Map<String, dynamic> json) => IntentEvent(
        id: json['id'],
        sourceApp: json['sourceApp'],
        action: json['data']['action'],
        category: json['data']['category'],
        extras: Map<String, dynamic>.from(json['data']['extras'] ?? {}),
        targetApp: json['targetApp'],
        permissions: Set<String>.from(json['permissions'] ?? []),
      );
}

/// URL Scheme / App Link event
class UrlEvent extends AppEvent {
  final String scheme;
  final String path;
  final Map<String, String> queryParams;

  UrlEvent({
    required super.id,
    required super.sourceApp,
    required this.scheme,
    required this.path,
    this.queryParams = const {},
    super.targetApp,
    super.permissions,
  }) : super(
          data: {
            'scheme': scheme,
            'path': path,
            'queryParams': queryParams,
            'fullUrl':
                '$scheme://$path${queryParams.isNotEmpty ? '?' : ''}${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}',
          },
          timestamp: DateTime.now(),
        );

  String get fullUrl => data['fullUrl'] as String;

  factory UrlEvent.fromJson(Map<String, dynamic> json) => UrlEvent(
        id: json['id'],
        sourceApp: json['sourceApp'],
        scheme: json['data']['scheme'],
        path: json['data']['path'],
        queryParams:
            Map<String, String>.from(json['data']['queryParams'] ?? {}),
        targetApp: json['targetApp'],
        permissions: Set<String>.from(json['permissions'] ?? []),
      );
}

/// Data sharing event (App Groups, Content Providers)
class DataShareEvent extends AppEvent {
  final String dataType;
  final String? filePath;
  final Map<String, dynamic> payload;

  DataShareEvent({
    required super.id,
    required super.sourceApp,
    required this.dataType,
    this.filePath,
    this.payload = const {},
    super.targetApp,
    super.permissions,
  }) : super(
          data: {
            'dataType': dataType,
            'filePath': filePath,
            'payload': payload,
          },
          timestamp: DateTime.now(),
        );

  factory DataShareEvent.fromJson(Map<String, dynamic> json) => DataShareEvent(
        id: json['id'],
        sourceApp: json['sourceApp'],
        dataType: json['data']['dataType'],
        filePath: json['data']['filePath'],
        payload: Map<String, dynamic>.from(json['data']['payload'] ?? {}),
        targetApp: json['targetApp'],
        permissions: Set<String>.from(json['permissions'] ?? []),
      );
}

/// Generic app event for custom implementations
class GenericAppEvent extends AppEvent {
  GenericAppEvent({
    required super.id,
    required super.sourceApp,
    required super.data,
    super.targetApp,
    super.permissions,
  }) : super(timestamp: DateTime.now());

  factory GenericAppEvent.fromJson(Map<String, dynamic> json) =>
      GenericAppEvent(
        id: json['id'],
        sourceApp: json['sourceApp'],
        data: Map<String, dynamic>.from(json['data']),
        targetApp: json['targetApp'],
        permissions: Set<String>.from(json['permissions'] ?? []),
      );
}
