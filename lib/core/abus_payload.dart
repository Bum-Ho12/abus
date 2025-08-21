// lib/core/abus_payload.dart
/// Base interface for serializable payloads
abstract class AbusPayload {
  /// Convert to JSON for serialization
  Map<String, dynamic> toJson();

  /// Optional validation
  bool validate() => true;

  /// Get validation errors
  List<String> getValidationErrors() => [];
}

/// Smart payload wrapper that handles any type automatically
class SmartPayload {
  final dynamic data;
  final String type;
  final bool _isClass;
  final Map<String, dynamic>? _serializedData;

  SmartPayload._(this.data, this.type, this._isClass, this._serializedData);

  /// Create from any data type
  factory SmartPayload.from(dynamic data) {
    if (data == null) {
      return SmartPayload._(null, 'null', false, null);
    } else if (data is SmartPayload) {
      return data;
    } else {
      final type = data.runtimeType.toString();
      final isClass = _isCustomClass(data);
      Map<String, dynamic>? serializedData;

      if (isClass) {
        serializedData = _serializeClass(data);
      }

      return SmartPayload._(data, type, isClass, serializedData);
    }
  }

  /// Check if this is a custom class (not a built-in type)
  static bool _isCustomClass(dynamic data) {
    if (data == null) return false;
    if (data is Map ||
        data is List ||
        data is String ||
        data is num ||
        data is bool) {
      return false;
    }
    if (data is DateTime || data is Duration || data is Enum) return false;
    if (data is AbusPayload) return false;

    // It's likely a custom class
    return true;
  }

  /// Serialize a class to Map&lt;String, dynamic&gt;
  static Map<String, dynamic> _serializeClass(dynamic data) {
    try {
      // First try: Check if the object has a toJson method
      try {
        final dynamic obj = data;
        final result = obj.toJson();
        if (result is Map<String, dynamic>) {
          return result;
        } else if (result is Map) {
          return Map<String, dynamic>.from(result);
        }
      } catch (e) {
        // toJson doesn't exist or failed, continue to other methods
      }

      // Second try: Parse toString() if it follows a pattern
      final str = data.toString();
      final className = data.runtimeType.toString();

      if (str.contains('(') && str.contains(')') && str.startsWith(className)) {
        final content =
            str.substring(str.indexOf('(') + 1, str.lastIndexOf(')'));
        final Map<String, dynamic> properties = {};

        // Parse "property: value, property2: value2" format
        if (content.isNotEmpty) {
          final parts = content.split(', ');
          for (final part in parts) {
            if (part.contains(': ')) {
              final colonIndex = part.indexOf(': ');
              final key = part.substring(0, colonIndex).trim();
              final valueStr = part.substring(colonIndex + 2).trim();

              // Try to parse the value
              properties[key] = _parseValue(valueStr);
            }
          }
        }

        if (properties.isNotEmpty) {
          return properties;
        }
      }

      // Third try: Fallback to basic representation
      return <String, dynamic>{
        'toString': str,
        'runtimeType': className,
        '_fallback': true,
      };
    } catch (e) {
      // Ultimate fallback
      return <String, dynamic>{
        'toString': data.toString(),
        'runtimeType': data.runtimeType.toString(),
        'error': e.toString(),
        '_error_fallback': true,
      };
    }
  }

  /// Parse a string value to appropriate type
  static dynamic _parseValue(String valueStr) {
    // Remove quotes if present
    if ((valueStr.startsWith("'") && valueStr.endsWith("'")) ||
        (valueStr.startsWith('"') && valueStr.endsWith('"'))) {
      return valueStr.substring(1, valueStr.length - 1);
    }

    // Try to parse as number
    if (RegExp(r'^\d+$').hasMatch(valueStr)) {
      return int.tryParse(valueStr) ?? valueStr;
    }

    if (RegExp(r'^\d+\.\d+$').hasMatch(valueStr)) {
      return double.tryParse(valueStr) ?? valueStr;
    }

    // Try to parse as boolean
    if (valueStr == 'true') return true;
    if (valueStr == 'false') return false;
    if (valueStr == 'null') return null;

    return valueStr;
  }

  /// Get typed data with automatic reconstruction
  T? as<T>() {
    if (data is T) return data as T;

    // If we're looking for the original type and we have serialized data
    if (_isClass && _serializedData != null && T.toString() == type) {
      // Try to reconstruct the object using a factory constructor
      return _tryReconstruct<T>(_serializedData);
    }

    return null;
  }

  /// Try to reconstruct an object of type T from serialized data
  T? _tryReconstruct<T>(Map<String, dynamic> serializedData) {
    try {
      // For now, we'll return null and let the caller handle the serialized data
      // The caller can still access the data via the raw property or as a Map
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if data is of specific type
  bool isOf<T>() {
    if (data is T) return true;
    // Check if we can reconstruct to this type
    if (_isClass && T.toString() == type) return true;
    return false;
  }

  /// Get the raw data
  dynamic get raw => data;

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': _serializeForJson(data),
      'isClass': _isClass,
      if (_serializedData != null) 'classData': _serializedData,
    };
  }

  /// Create from JSON with smart reconstruction
  factory SmartPayload.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'unknown';
    final isClass = json['isClass'] as bool? ?? false;
    final classData = json['classData'] as Map<String, dynamic>?;

    dynamic data = json['data'];

    // If it was a class, use the class data as the main data for backward compatibility
    if (isClass && classData != null) {
      data = classData;
    }

    return SmartPayload._(data, type, isClass, classData);
  }

  /// Smart serialization for JSON
  dynamic _serializeForJson(dynamic data) {
    if (data == null) {
      return null;
    } else if (_isClass) {
      // Return the serialized class data
      return _serializedData ?? _serializeClass(data);
    } else if (data is AbusPayload) {
      return data.toJson();
    } else if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      return Map<String, dynamic>.from(data);
    } else if (data is List || data is String || data is num || data is bool) {
      return data;
    } else if (data is DateTime) {
      return data.toIso8601String();
    } else if (data is Duration) {
      return data.inMilliseconds;
    } else if (data is Enum) {
      return data.toString();
    } else {
      // This shouldn't happen for classes since we handle them above
      return data.toString();
    }
  }

  /// Validate the payload
  bool validate() {
    if (data is AbusPayload) {
      return (data as AbusPayload).validate();
    }
    return true;
  }

  /// Get validation errors
  List<String> getValidationErrors() {
    if (data is AbusPayload) {
      return (data as AbusPayload).getValidationErrors();
    }
    return [];
  }

  @override
  String toString() =>
      'SmartPayload(type: $type, data: $data, isClass: $_isClass)';
}
