// test_app_b/lib/main.dart
import 'package:flutter/material.dart';
import 'package:abus/abus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize cross-app communication for App B
  await CrossAppBus.initialize(
    appId: 'com.example.test_app_b',
    permissions: {
      AppPermission.send.permission,
      AppPermission.receive.permission,
      AppPermission.dataShare.permission,
      AppPermission.urlHandle.permission,
    },
    sharedStoragePaths: {
      'documents': '/shared/documents',
      'images': '/shared/images',
    },
  );

  // Set up event filters for security
  CrossAppBus.addEventFilter('trusted_apps', (event) {
    final trustedApps = {
      'com.example.test_app_a',
      'com.example.test_app_b',
    };
    return trustedApps.contains(event.sourceApp);
  });

  // Register our custom handler for receiving events
  ABUS.registerHandler(AppBEventHandler());

  runApp(const TestAppB());
}

class TestAppB extends StatelessWidget {
  const TestAppB({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test App B',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
      // Handle incoming URL schemes
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('testappb://') == true) {
          final uri = Uri.parse(settings.name!);
          return MaterialPageRoute(
            builder: (context) => UrlHandlerScreen(uri: uri),
          );
        }
        return null;
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<ReceivedEvent> _receivedEvents = [];
  final ScrollController _scrollController = ScrollController();
  int _totalReceived = 0;

  @override
  void initState() {
    super.initState();

    // Listen to ABUS results for received events
    ABUS.manager.resultStream.listen((result) {
      if (result.isSuccess && result.data != null) {
        final data = result.data!;
        if (data.containsKey('type')) {
          final eventType = data['type'] as String;
          if (eventType.endsWith('_received')) {
            setState(() {
              _receivedEvents.insert(
                  0,
                  ReceivedEvent(
                    type: eventType,
                    data: data,
                    timestamp: DateTime.now(),
                  ));
              _totalReceived++;
            });
          }
        }
      }
    });

    _addSystemEvent('App B initialized and listening for events');
  }

  void _addSystemEvent(String message) {
    setState(() {
      _receivedEvents.insert(
          0,
          ReceivedEvent(
            type: 'system',
            data: {'message': message},
            timestamp: DateTime.now(),
          ));
    });
  }

  Future<void> _sendResponseToAppA() async {
    _addSystemEvent('Sending response to App A...');

    final result = await CrossAppBus.sendIntent(
      action: 'com.example.ACTION_RESPONSE',
      targetApp: 'com.example.test_app_a',
      extras: {
        'message': 'Hello back from App B!',
        'responseTime': DateTime.now().millisecondsSinceEpoch,
        'status': 'received_and_processed',
      },
    );

    if (result.isSuccess) {
      _addSystemEvent('Response sent successfully');
    } else {
      _addSystemEvent('Failed to send response: ${result.error}');
    }
  }

  Future<void> _shareDataWithAppA() async {
    _addSystemEvent('Sharing configuration data with App A...');

    final configData = {
      'appVersion': '1.0.0',
      'settings': {
        'autoSync': true,
        'maxConnections': 5,
        'timeout': 30,
      },
      'capabilities': [
        'data_processing',
        'file_sharing',
        'notifications',
      ],
      'status': 'active',
    };

    final result = await CrossAppBus.shareData(
      dataType: 'app_config',
      payload: configData,
      targetApp: 'com.example.test_app_a',
      permissions: {AppPermission.dataShare.permission},
    );

    if (result.isSuccess) {
      _addSystemEvent('Configuration data shared successfully');
    } else {
      _addSystemEvent('Failed to share data: ${result.error}');
    }
  }

  void _clearEvents() {
    setState(() {
      _receivedEvents.clear();
      _totalReceived = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test App B - Receiver'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearEvents,
            tooltip: 'Clear events',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatusCard(
                      'Total Received',
                      _totalReceived.toString(),
                      Colors.blue,
                    ),
                    _buildStatusCard(
                      'Currently Displayed',
                      _receivedEvents.length.toString(),
                      Colors.orange,
                    ),
                    _buildStatusCard(
                      'Status',
                      'Listening',
                      Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _sendResponseToAppA,
                        icon: const Icon(Icons.reply),
                        label: const Text('Send Response'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _shareDataWithAppA,
                        icon: const Icon(Icons.settings),
                        label: const Text('Share Config'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          // Events Display
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Received Events',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _receivedEvents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No events received yet',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Use Test App A to send events',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: _receivedEvents.length,
                            itemBuilder: (context, index) {
                              final event = _receivedEvents[index];
                              return _buildEventCard(event, index);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, Color color) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(ReceivedEvent event, int index) {
    Color cardColor;
    IconData icon;

    switch (event.type) {
      case 'intent_received':
        cardColor = Colors.green.shade100;
        icon = Icons.email;
        break;
      case 'url_received':
        cardColor = Colors.orange.shade100;
        icon = Icons.link;
        break;
      case 'data_received':
        cardColor = Colors.purple.shade100;
        icon = Icons.share;
        break;
      case 'system':
        cardColor = Colors.blue.shade50;
        icon = Icons.info;
        break;
      default:
        cardColor = Colors.grey.shade100;
        icon = Icons.message;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardColor,
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.grey.shade700),
        title: Text(
          event.type.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${event.timestamp.toString().substring(11, 19)} • ${event.data['from'] ?? 'system'}',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _formatEventData(event.data),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatEventData(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    data.forEach((key, value) {
      buffer.writeln('$key: ${_formatValue(value)}');
    });
    return buffer.toString();
  }

  String _formatValue(dynamic value) {
    if (value is Map) {
      return '\n  ${value.entries.map((e) => '${e.key}: ${e.value}').join('\n  ')}';
    } else if (value is List) {
      return '[${value.join(', ')}]';
    }
    return value.toString();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

// Data class for received events
class ReceivedEvent {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  ReceivedEvent({
    required this.type,
    required this.data,
    required this.timestamp,
  });
}

// Screen for handling URL schemes
class UrlHandlerScreen extends StatelessWidget {
  final Uri uri;

  const UrlHandlerScreen({super.key, required this.uri});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('URL Handler'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Received URL:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        uri.toString(),
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'URL Components:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Scheme', uri.scheme),
                    _buildInfoRow('Host', uri.host),
                    _buildInfoRow('Path', uri.path),
                    if (uri.queryParameters.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Query Parameters:'),
                      ...uri.queryParameters.entries
                          .map((e) => _buildInfoRow('  ${e.key}', e.value)),
                    ],
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Main'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '(empty)' : value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom handler for receiving cross-app events
class AppBEventHandler extends CustomAbusHandler {
  @override
  String get handlerId => 'AppBEventHandler';

  @override
  bool canHandle(InteractionDefinition interaction) {
    return interaction.id == 'receive_app_event';
  }

  @override
  Future<void> handleOptimistic(
    String interactionId,
    InteractionDefinition interaction,
  ) async {
    if (interaction is ReceiveAppEventInteraction) {
      final event = interaction.event;

      debugPrint(
          'App B received event: ${event.runtimeType} from ${event.sourceApp}');

      switch (event.runtimeType) {
        case const (IntentEvent):
          await _handleIntent(event as IntentEvent);
          break;
        case const (UrlEvent):
          await _handleUrl(event as UrlEvent);
          break;
        case const (DataShareEvent):
          await _handleDataShare(event as DataShareEvent);
          break;
        default:
          debugPrint('Unknown event type: ${event.runtimeType}');
      }
    }
  }

  Future<void> _handleIntent(IntentEvent event) async {
    debugPrint('Intent received - Action: ${event.action}');
    debugPrint('Extras: ${event.extras}');

    // Emit result for UI update
    ABUS.manager.emitResult(
      ABUSResult.success(
        data: {
          'type': 'intent_received',
          'action': event.action,
          'from': event.sourceApp,
          'extras': event.extras,
        },
        interactionId: 'app_b_intent_handler',
      ),
    );
  }

  Future<void> _handleUrl(UrlEvent event) async {
    debugPrint('URL received: ${event.fullUrl}');
    debugPrint('Query params: ${event.queryParams}');

    ABUS.manager.emitResult(
      ABUSResult.success(
        data: {
          'type': 'url_received',
          'url': event.fullUrl,
          'from': event.sourceApp,
          'scheme': event.scheme,
          'path': event.path,
          'queryParams': event.queryParams,
        },
        interactionId: 'app_b_url_handler',
      ),
    );
  }

  Future<void> _handleDataShare(DataShareEvent event) async {
    debugPrint('Data received - Type: ${event.dataType}');
    debugPrint('Payload: ${event.payload}');

    ABUS.manager.emitResult(
      ABUSResult.success(
        data: {
          'type': 'data_received',
          'dataType': event.dataType,
          'from': event.sourceApp,
          'payload': event.payload,
          'hasFile': event.filePath != null,
        },
        interactionId: 'app_b_data_handler',
      ),
    );
  }
}
