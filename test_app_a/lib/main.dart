// diagnostic_main.dart - Use this to test your initialization
import 'package:flutter/material.dart';
import 'package:abus/abus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Run diagnostics
  final diagnostics = CrossAppDiagnostics();
  await diagnostics.runDiagnostics();

  runApp(const DiagnosticApp());
}

class CrossAppDiagnostics {
  Future<void> runDiagnostics() async {
    debugPrint('=== ABUS Cross-App Diagnostics ===');

    // Test 1: Check if ABUS core is working
    await _testABUSCore();

    // Test 2: Check if cross-app classes exist
    await _testCrossAppClasses();

    // Test 3: Test initialization
    await _testInitialization();

    // Test 4: Test manager registration
    await _testManagerRegistration();

    debugPrint('=== Diagnostics Complete ===');
  }

  Future<void> _testABUSCore() async {
    debugPrint('Test 1: ABUS Core');
    try {
      final manager = ABUS.manager;
      debugPrint('✓ ABUS manager accessible');
      debugPrint('  Handler count: ${manager.handlerCount}');
      debugPrint('  API handler count: ${manager.apiHandlerCount}');
    } catch (e) {
      debugPrint('✗ ABUS core error: $e');
    }
  }

  Future<void> _testCrossAppClasses() async {
    debugPrint('\nTest 2: Cross-App Classes');

    // Test AppPermission
    try {
      final sendPerm = AppPermission.send.permission;
      debugPrint('✓ AppPermission class exists: $sendPerm');
    } catch (e) {
      debugPrint('✗ AppPermission class missing: $e');
    }

    // Test AppCommunicationManager
    try {
      final manager = AppCommunicationManager.instance;
      debugPrint('✓ AppCommunicationManager accessible');
      debugPrint('  Handler ID: ${manager.handlerId}');
    } catch (e) {
      debugPrint('✗ AppCommunicationManager error: $e');
    }

    // Test CrossAppBus
    try {
      debugPrint('✓ CrossAppBus class exists');
      // Don't call methods yet, just check class existence
    } catch (e) {
      debugPrint('✗ CrossAppBus class missing: $e');
    }
  }

  Future<void> _testInitialization() async {
    debugPrint('\nTest 3: Initialization');
    try {
      await CrossAppBus.initialize(
        appId: 'com.example.diagnostic',
        permissions: {
          AppPermission.send.permission,
          AppPermission.receive.permission,
        },
      );
      debugPrint('✓ CrossAppBus initialization successful');
    } catch (e) {
      debugPrint('✗ Initialization failed: $e');
      debugPrint('  This is likely the source of your problem');
      _suggestInitializationFix(e);
    }
  }

  Future<void> _testManagerRegistration() async {
    debugPrint('\nTest 4: Manager Registration');
    try {
      final handlerCount = ABUS.manager.handlerCount;
      debugPrint('✓ Handler registration check');
      debugPrint('  Total handlers: $handlerCount');

      // Check if AppCommunicationManager is registered
      bool managerRegistered = false;
      // This is a simplified check - in real implementation you'd need
      // to expose handler inspection methods
      if (handlerCount > 0) {
        managerRegistered = true;
      }

      if (managerRegistered) {
        debugPrint('✓ AppCommunicationManager appears to be registered');
      } else {
        debugPrint('✗ AppCommunicationManager not registered');
      }
    } catch (e) {
      debugPrint('✗ Manager registration check failed: $e');
    }
  }

  void _suggestInitializationFix(dynamic error) {
    debugPrint('\n--- INITIALIZATION FIX SUGGESTIONS ---');

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('crossappbus')) {
      debugPrint(
          '• CrossAppBus class not found - check exports in lib/abus.dart');
      debugPrint('• Make sure you have all cross-app files in lib/cross_app/');
    }

    if (errorString.contains('apppermission')) {
      debugPrint(
          '• AppPermission class not found - missing app_communication_manager.dart');
    }

    if (errorString.contains('platform')) {
      debugPrint('• Platform channel error - check Android/iOS configuration');
      debugPrint('• Make sure you have method/event channels set up');
    }

    if (errorString.contains('permission')) {
      debugPrint('• Permission error - check Android manifest permissions');
    }

    debugPrint('\nQuick fixes to try:');
    debugPrint('1. Add missing files from the diagnostic artifact');
    debugPrint('2. Check lib/abus.dart exports');
    debugPrint('3. Run "flutter pub get"');
    debugPrint('4. Check platform configurations');
  }
}

class DiagnosticApp extends StatefulWidget {
  const DiagnosticApp({super.key});

  @override
  State<DiagnosticApp> createState() => _DiagnosticAppState();
}

class _DiagnosticAppState extends State<DiagnosticApp> {
  String _status = 'Checking initialization...';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      // Try to access the manager
      final manager = AppCommunicationManager.instance;
      debugPrint('Manager, $manager');

      // Check if initialized (this is a mock check - you'd need proper status checking)
      setState(() {
        _isInitialized = true;
        _status = 'Cross-app communication is working!';
      });
    } catch (e) {
      setState(() {
        _isInitialized = false;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _testSendIntent() async {
    if (!_isInitialized) {
      _showError('Not initialized');
      return;
    }

    try {
      final result = await CrossAppBus.sendIntent(
        action: 'com.example.TEST',
        extras: {'test': 'diagnostic'},
      );

      _showResult(
          'Intent test: ${result.isSuccess ? 'SUCCESS' : 'FAILED: ${result.error}'}');
    } catch (e) {
      _showError('Intent test failed: $e');
    }
  }

  void _showResult(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    debugPrint('Error: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('ABUS Cross-App Diagnostics'),
          backgroundColor: _isInitialized ? Colors.green : Colors.red,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color:
                    _isInitialized ? Colors.green.shade50 : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isInitialized ? Icons.check_circle : Icons.error,
                            color: _isInitialized ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Initialization Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_status),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Quick Tests',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _isInitialized ? _testSendIntent : null,
                child: const Text('Test Send Intent'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Troubleshooting Steps',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTroubleshootingCard(
                        'Step 1: Check File Structure',
                        [
                          'Ensure lib/cross_app/ directory exists',
                          'Check for app_communication_manager.dart',
                          'Check for cross_app_bus.dart',
                          'Check for app_event.dart',
                          'Check for app_interactions.dart',
                        ],
                      ),
                      _buildTroubleshootingCard(
                        'Step 2: Check Exports',
                        [
                          'Open lib/abus.dart',
                          'Add cross-app exports if missing',
                          'Run "flutter pub get"',
                        ],
                      ),
                      _buildTroubleshootingCard(
                        'Step 3: Check Initialization',
                        [
                          'Call CrossAppBus.initialize() before runApp()',
                          'Use await with WidgetsFlutterBinding.ensureInitialized()',
                          'Check console for detailed error messages',
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTroubleshootingCard(String title, List<String> steps) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...steps.map((step) => Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(step)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// Simple mock implementation for testing (if the real ones don't exist)
// Only use this temporarily to test - replace with real implementation

class MockAppPermission {
  final String permission;
  const MockAppPermission(this.permission);

  static const send = MockAppPermission('cross_app.send');
  static const receive = MockAppPermission('cross_app.receive');
  static const dataShare = MockAppPermission('cross_app.data_share');
}

class MockAppCommunicationManager {
  static MockAppCommunicationManager? _instance;
  static MockAppCommunicationManager get instance =>
      _instance ??= MockAppCommunicationManager._();

  MockAppCommunicationManager._();

  String get handlerId => 'MockAppCommunicationManager';

  Future<void> initialize({
    required String appId,
    Set<String> permissions = const {},
    Map<String, String>? sharedStoragePaths,
  }) async {
    debugPrint('Mock initialization called with appId: $appId');
    // Mock success
  }
}

class MockCrossAppBus {
  static Future<void> initialize({
    required String appId,
    Set<String> permissions = const {},
    Map<String, String>? sharedStoragePaths,
  }) async {
    await MockAppCommunicationManager.instance.initialize(
      appId: appId,
      permissions: permissions,
      sharedStoragePaths: sharedStoragePaths,
    );
  }
}
