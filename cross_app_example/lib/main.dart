// cross_app_example/lib/main.dart
import 'package:flutter/material.dart';
import 'package:abus/abus.dart';

void main() {
  runApp(const CrossAppTestApp());
}

class CrossAppTestApp extends StatelessWidget {
  const CrossAppTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ABUS Cross-App Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TestHomePage(),
    );
  }
}

class TestHomePage extends StatefulWidget {
  const TestHomePage({super.key});

  @override
  State<TestHomePage> createState() => _TestHomePageState();
}

class _TestHomePageState extends State<TestHomePage>
    with AbusWidgetMixin<TestHomePage> {
  final List<String> _eventLog = [];
  bool _initialized = false;
  String _currentAppId = 'test_app_1';

  @override
  void initState() {
    super.initState();
    _setupABUS();
    _initializeCrossApp();
  }

  void _setupABUS() {
    // Register a mock API handler for testing
    ABUS.registerApiHandler((interaction) async {
      _log('API Handler called for: ${interaction.id}');

      // Mock platform channel responses
      if (interaction.id == 'send_app_event') {
        await Future.delayed(
            const Duration(milliseconds: 500)); // Simulate network delay
        return ABUSResult.success(
          data: {
            'sent': true,
            'timestamp': DateTime.now().millisecondsSinceEpoch
          },
          interactionId: interaction.id,
        );
      }

      return ABUSResult.error('Unsupported interaction: ${interaction.id}');
    });

    // Listen to ABUS results
    ABUS.manager.resultStream.listen((result) {
      _log(
          'ABUS Result: ${result.isSuccess ? "Success" : "Error: ${result.error}"}');
    });
  }

  Future<void> _initializeCrossApp() async {
    try {
      // Mock cross-app initialization
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _initialized = true;
      });

      _log('Cross-app communication initialized for $_currentAppId');
    } catch (e) {
      _log('Failed to initialize: $e');
    }
  }

  void _log(String message) {
    setState(() {
      _eventLog.insert(0,
          '${DateTime.now().toLocal().toString().substring(11, 19)} - $message');
      if (_eventLog.length > 50) _eventLog.removeLast();
    });
  }

  // Mock cross-app event creation
  Map<String, dynamic> _createMockIntent({
    required String action,
    String? targetApp,
    Map<String, dynamic> extras = const {},
  }) {
    return {
      'id': 'intent_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'IntentEvent',
      'sourceApp': _currentAppId,
      'targetApp': targetApp,
      'data': {
        'action': action,
        'extras': extras,
      },
      'timestamp': DateTime.now().toIso8601String(),
      'permissions': ['cross_app.send'],
    };
  }

  Map<String, dynamic> _createMockUrl({
    required String scheme,
    required String path,
    Map<String, String> queryParams = const {},
  }) {
    final url =
        '$scheme://$path${queryParams.isNotEmpty ? '?' : ''}${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    return {
      'id': 'url_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'UrlEvent',
      'sourceApp': _currentAppId,
      'data': {
        'scheme': scheme,
        'path': path,
        'queryParams': queryParams,
        'fullUrl': url,
      },
      'timestamp': DateTime.now().toIso8601String(),
      'permissions': ['cross_app.url_handle'],
    };
  }

  Future<void> _sendTestIntent() async {
    if (!_initialized) return;

    final mockEvent = _createMockIntent(
      action: 'com.test.ACTION_HELLO',
      targetApp: 'test_app_2',
      extras: {
        'message': 'Hello from $_currentAppId',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );

    final interaction = ABUS
        .builder()
        .withId('send_app_event')
        .withData({
          'event': mockEvent,
          'eventType': 'IntentEvent',
        })
        .withTimeout(const Duration(seconds: 5))
        .addTag('cross_app')
        .build();

    _log('Sending intent event...');
    final result = await ABUS.execute(interaction);

    if (result.isSuccess) {
      _log('Intent sent successfully');
    } else {
      _log('Failed to send intent: ${result.error}');
    }
  }

  Future<void> _sendTestUrl() async {
    if (!_initialized) return;

    final mockEvent = _createMockUrl(
      scheme: 'test_app',
      path: 'home',
      queryParams: {
        'user': 'test_user',
        'action': 'navigate',
      },
    );

    final interaction = ABUS
        .builder()
        .withId('send_app_event')
        .withData({
          'event': mockEvent,
          'eventType': 'UrlEvent',
        })
        .addTag('cross_app')
        .build();

    _log('Sending URL event...');
    final result = await ABUS.execute(interaction);

    if (result.isSuccess) {
      _log('URL event sent successfully');
    } else {
      _log('Failed to send URL: ${result.error}');
    }
  }

  Future<void> _sendTestData() async {
    if (!_initialized) return;

    final mockEvent = {
      'id': 'share_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'DataShareEvent',
      'sourceApp': _currentAppId,
      'data': {
        'dataType': 'user_profile',
        'payload': {
          'userId': 123,
          'username': 'test_user',
          'preferences': {
            'theme': 'dark',
            'notifications': true,
          },
        },
      },
      'timestamp': DateTime.now().toIso8601String(),
      'permissions': ['cross_app.data_share'],
    };

    final interaction = ABUS
        .builder()
        .withId('send_app_event')
        .withData({
          'event': mockEvent,
          'eventType': 'DataShareEvent',
        })
        .addTag('cross_app')
        .build();

    _log('Sending data share event...');
    final result = await ABUS.execute(interaction);

    if (result.isSuccess) {
      _log('Data shared successfully');
    } else {
      _log('Failed to share data: ${result.error}');
    }
  }

  Future<void> _simulateIncomingEvent() async {
    if (!_initialized) return;

    final mockIncomingEvent = _createMockIntent(
      action: 'com.test.ACTION_RESPONSE',
      extras: {
        'response': 'Hello back from test_app_2',
        'originalSender': _currentAppId,
      },
    );

    _log('Simulating incoming event from test_app_2');

    // Simulate processing the incoming event
    final interaction = ABUS
        .builder()
        .withId('receive_app_event')
        .withData({
          'event': mockIncomingEvent,
          'eventType': 'IntentEvent',
        })
        .withOptimistic(true)
        .addTag('cross_app')
        .build();

    final result = await ABUS.execute(interaction);

    if (result.isSuccess) {
      _log('Processed incoming event successfully');
    } else {
      _log('Failed to process incoming event: ${result.error}');
    }
  }

  void _switchApp() {
    setState(() {
      _currentAppId =
          _currentAppId == 'test_app_1' ? 'test_app_2' : 'test_app_1';
      _eventLog.clear();
      _initialized = false;
    });
    _initializeCrossApp();
  }

  void _testABUSBasics() async {
    _log('Testing ABUS basic functionality...');

    // Test simple interaction
    final interaction =
        ABUS.builder().withId('test_basic').withData({'test': 'data'}).build();

    final result = await ABUS.execute(interaction);
    _log('Basic test result: ${result.isSuccess ? "Success" : result.error}');

    // Test builder
    final builderTest = ABUS
        .builder()
        .withId('test_builder')
        .addData('key1', 'value1')
        .addData('key2', 'value2')
        .withPriority(5)
        .addTag('test')
        .build();

    _log(
        'Builder test - ID: ${builderTest.id}, Priority: ${builderTest.priority}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ABUS Cross-App Test ($_currentAppId)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: _switchApp,
            tooltip: 'Switch App Identity',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _initialized ? Icons.check_circle : Icons.error,
                        color: _initialized ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _initialized
                            ? 'Cross-app ready ($_currentAppId)'
                            : 'Initializing...',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ABUS Handlers: ${ABUS.manager.handlerCount} | API Handlers: ${ABUS.manager.apiHandlerCount}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _testABUSBasics,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Test ABUS'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _initialized ? _sendTestIntent : null,
                        icon: const Icon(Icons.send),
                        label: const Text('Send Intent'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _initialized ? _sendTestUrl : null,
                        icon: const Icon(Icons.link),
                        label: const Text('Send URL'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _initialized ? _sendTestData : null,
                        icon: const Icon(Icons.share),
                        label: const Text('Share Data'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _initialized ? _simulateIncomingEvent : null,
                    icon: const Icon(Icons.sim_card_download),
                    label: const Text('Simulate Incoming Event'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Event Log
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Text(
                      'Event Log',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _eventLog.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _eventLog[index],
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _eventLog.clear();
          });
        },
        tooltip: 'Clear Log',
        child: const Icon(Icons.clear),
      ),
    );
  }
}
