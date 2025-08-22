// test/abus_widget_integration_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abus/abus.dart';
import 'dart:async';

void main() {
  group('ABUS Widget Mixin Tests', () {
    setUp(() {
      ABUSManager.reset();
    });

    tearDown(() {
      ABUSManager.instance.dispose();
    });

    testWidgets('should react to ABUS results with mixin', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: TestWidgetWithMixin(),
      ));

      final testWidget = tester
          .state<_TestWidgetWithMixinState>(find.byType(TestWidgetWithMixin));

      expect(testWidget.receivedResults, isEmpty);

      // Register API handler
      ABUS.registerApiHandler((interaction) async {
        return ABUSResult.success(
          data: {'message': 'Widget test success'},
          interactionId: interaction.id,
        );
      });

      // Execute interaction
      final interaction = ABUS
          .builder()
          .withId('widget_test')
          .withPayload({'action': 'test'})
          .addTag('ui_test')
          .build();

      await testWidget.executeInteraction(interaction);
      await tester.pumpAndSettle();

      expect(testWidget.receivedResults, hasLength(1));
      expect(testWidget.receivedResults.first.isSuccess, isTrue);
      expect(testWidget.rebuilds, greaterThan(0));
    });

    testWidgets('should filter results based on configuration', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: FilteredTestWidget(),
      ));

      final testWidget = tester
          .state<_FilteredTestWidgetState>(find.byType(FilteredTestWidget));

      // Register API handlers for different scenarios
      ABUS.registerApiHandler((interaction) async {
        if (interaction.id.contains('error')) {
          return ABUSResult.error('Test error', interactionId: interaction.id);
        }
        return ABUSResult.success(
          data: {'message': 'Success'},
          interactionId: interaction.id,
        );
      });

      // Execute success interaction (should be filtered out)
      final successInteraction = ABUS
          .builder()
          .withId('success_test')
          .withPayload({'action': 'test'}).build();

      await testWidget.executeInteraction(successInteraction);
      await tester.pumpAndSettle();

      // Should not trigger update (filtered out)
      expect(testWidget.receivedResults, isEmpty);
      expect(testWidget.rebuilds, equals(0));

      // Execute error interaction (should pass filter)
      final errorInteraction = ABUS
          .builder()
          .withId('error_test')
          .withPayload({'action': 'test'}).build();

      await testWidget.executeInteraction(errorInteraction);
      await tester.pumpAndSettle();

      // Should trigger update (passes filter)
      expect(testWidget.receivedResults, hasLength(1));
      expect(testWidget.receivedResults.first.isSuccess, isFalse);
      expect(testWidget.rebuilds, equals(1));
    });

    testWidgets('should handle debounced updates', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: DebouncedTestWidget(),
      ));

      final testWidget = tester
          .state<_DebouncedTestWidgetState>(find.byType(DebouncedTestWidget));

      ABUS.registerApiHandler((interaction) async {
        return ABUSResult.success(
          data: {'message': 'Debounced test'},
          interactionId: interaction.id,
        );
      });

      // Execute multiple interactions rapidly
      for (int i = 0; i < 5; i++) {
        final interaction = ABUS
            .builder()
            .withId('debounced_$i')
            .withPayload({'index': i}).build();

        testWidget.executeInteraction(interaction);
      }

      // Should not rebuild immediately
      await tester.pump(const Duration(milliseconds: 100));
      expect(testWidget.rebuilds, equals(0));

      // Should rebuild after debounce delay
      await tester.pump(const Duration(milliseconds: 600));
      expect(testWidget.rebuilds, equals(1));
      expect(testWidget.receivedResults, hasLength(1));
    });

    testWidgets('should handle widget disposal correctly', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: DisposableTestWidget(key: Key('disposable')),
      ));

      final testWidget = tester.state<_DisposableTestWidgetState>(
          find.byKey(const Key('disposable')));

      expect(testWidget.isDisposed, isFalse);

      // Remove widget
      await tester.pumpWidget(MaterialApp(
        home: Container(),
      ));

      expect(testWidget.isDisposed, isTrue);
    });

    testWidgets('should work with custom update configurations',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: CustomConfigWidget(),
      ));

      final testWidget = tester
          .state<_CustomConfigWidgetState>(find.byType(CustomConfigWidget));

      ABUS.registerApiHandler((interaction) async {
        return ABUSResult.success(
          data: {'message': 'Custom config test'},
          interactionId: interaction.id,
          metadata: {
            'tags': ['ui', 'test']
          },
        );
      });

      // Execute interaction with matching tag
      final matchingInteraction = ABUS
          .builder()
          .withId('matching_test')
          .withPayload({'action': 'test'})
          .addTag('ui')
          .build();

      await testWidget.executeInteraction(matchingInteraction);
      await tester.pumpAndSettle();

      expect(testWidget.receivedResults, hasLength(1));
      expect(testWidget.rebuilds, greaterThan(0));

      testWidget.reset();

      // Execute interaction without matching tag
      final nonMatchingInteraction = ABUS
          .builder()
          .withId('non_matching_test')
          .withPayload({'action': 'test'})
          .addTag('other')
          .build();

      await testWidget.executeInteraction(nonMatchingInteraction);
      await tester.pumpAndSettle();

      // Should not receive result due to tag filter
      expect(testWidget.receivedResults, isEmpty);
      expect(testWidget.rebuilds, equals(0));
    });
  });

  group('BLoC and Provider Mixin Tests', () {
    test('should work with BLoC mixin', () {
      final bloc = TestBloc();

      expect(bloc.handlerId, equals('TestBloc'));
      expect(bloc.canHandle(TestInteractionBuilder.build()), isTrue);

      // Test that methods can be overridden
      expect(bloc.getCurrentState(TestInteractionBuilder.build()), isNull);
    });

    test('should work with Provider mixin', () {
      final provider = TestProvider();

      expect(provider.handlerId, equals('TestProvider'));
      expect(provider.canHandle(TestInteractionBuilder.build()), isTrue);

      // Test ChangeNotifier functionality
      bool notified = false;
      provider.addListener(() => notified = true);
      provider.testNotify();
      expect(notified, isTrue);
    });
  });

  group('Advanced Integration Scenarios', () {
    testWidgets('should handle complex workflow with multiple widgets',
        (tester) async {
      final completer = Completer<ABUSResult>();

      await tester.pumpWidget(MaterialApp(
        home: WorkflowTestWidget(resultCompleter: completer),
      ));

      final testWidget = tester
          .state<_WorkflowTestWidgetState>(find.byType(WorkflowTestWidget));

      // Register workflow handler
      ABUS.registerApiHandler((interaction) async {
        if (interaction.id == 'workflow_step_1') {
          return ABUSResult.success(
            data: {'step': 1, 'nextStep': 'workflow_step_2'},
            interactionId: interaction.id,
          );
        } else if (interaction.id == 'workflow_step_2') {
          return ABUSResult.success(
            data: {'step': 2, 'completed': true},
            interactionId: interaction.id,
          );
        }
        return ABUSResult.error('Unknown step', interactionId: interaction.id);
      });

      // Start workflow
      final step1 = ABUS
          .builder()
          .withId('workflow_step_1')
          .withPayload({'userId': '123'}).build();

      await testWidget.executeInteraction(step1);
      await tester.pumpAndSettle();

      expect(testWidget.workflowSteps, hasLength(1));
      expect(testWidget.workflowSteps.first.getData<Map>()!['step'], equals(1));

      // Continue workflow
      final step2 = ABUS
          .builder()
          .withId('workflow_step_2')
          .withPayload({'userId': '123'}).build();

      await testWidget.executeInteraction(step2);
      await tester.pumpAndSettle();

      expect(testWidget.workflowSteps, hasLength(2));
      expect(
          testWidget.workflowSteps.last.getData<Map>()!['completed'], isTrue);

      completer.complete(testWidget.workflowSteps.last);
    });

    testWidgets('should handle optimistic updates with rollback in widgets',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: OptimisticTestWidget(),
      ));

      final testWidget = tester
          .state<_OptimisticTestWidgetState>(find.byType(OptimisticTestWidget));

      // Register handler that will fail
      ABUS.registerApiHandler((interaction) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return ABUSResult.error('API failed', interactionId: interaction.id);
      });

      final interaction = ABUS
          .builder()
          .withId('optimistic_fail')
          .withPayload({'action': 'update', 'value': 'new_value'}).build();

      await testWidget.executeInteraction(interaction, optimistic: true);
      await tester.pumpAndSettle();

      // Should have received both optimistic and rollback results
      expect(testWidget.allResults, hasLength(2));

      // First should be success (optimistic), second should be error/rollback
      expect(testWidget.allResults.first.isSuccess, isTrue);
      expect(testWidget.allResults.last.isSuccess, isFalse);
    });
  });
}

// Test Widgets and Classes

class TestWidgetWithMixin extends StatefulWidget {
  const TestWidgetWithMixin({super.key});

  @override
  _TestWidgetWithMixinState createState() => _TestWidgetWithMixinState();
}

class _TestWidgetWithMixinState extends State<TestWidgetWithMixin>
    with AbusWidgetMixin<TestWidgetWithMixin> {
  List<ABUSResult> receivedResults = [];
  int rebuilds = 0;

  @override
  void onAbusResult(ABUSResult result) {
    receivedResults.add(result);
  }

  @override
  bool shouldRebuild(ABUSResult result) {
    rebuilds++;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Rebuilds: $rebuilds'),
          Text('Results: ${receivedResults.length}'),
        ],
      ),
    );
  }
}

class FilteredTestWidget extends StatefulWidget {
  const FilteredTestWidget({super.key});

  @override
  _FilteredTestWidgetState createState() => _FilteredTestWidgetState();
}

class _FilteredTestWidgetState extends State<FilteredTestWidget>
    with AbusWidgetMixin<FilteredTestWidget> {
  List<ABUSResult> receivedResults = [];
  int rebuilds = 0;

  @override
  AbusUpdateConfig get abusConfig => AbusUpdateConfig.errorsOnly;

  @override
  void onAbusResult(ABUSResult result) {
    receivedResults.add(result);
  }

  @override
  bool shouldRebuild(ABUSResult result) {
    rebuilds++;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Error Rebuilds: $rebuilds'),
          Text('Error Results: ${receivedResults.length}'),
        ],
      ),
    );
  }
}

class DebouncedTestWidget extends StatefulWidget {
  const DebouncedTestWidget({super.key});

  @override
  _DebouncedTestWidgetState createState() => _DebouncedTestWidgetState();
}

class _DebouncedTestWidgetState extends State<DebouncedTestWidget>
    with AbusWidgetMixin<DebouncedTestWidget> {
  List<ABUSResult> receivedResults = [];
  int rebuilds = 0;

  @override
  AbusUpdateConfig get abusConfig => const AbusUpdateConfig(
        debounceDelay: Duration(milliseconds: 500),
      );

  @override
  void onAbusResult(ABUSResult result) {
    receivedResults.add(result);
  }

  @override
  bool shouldRebuild(ABUSResult result) {
    rebuilds++;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Debounced Rebuilds: $rebuilds'),
          Text('Debounced Results: ${receivedResults.length}'),
        ],
      ),
    );
  }
}

class DisposableTestWidget extends StatefulWidget {
  const DisposableTestWidget({super.key});

  @override
  _DisposableTestWidgetState createState() => _DisposableTestWidgetState();
}

class _DisposableTestWidgetState extends State<DisposableTestWidget>
    with AbusWidgetMixin<DisposableTestWidget> {
  bool isDisposed = false;

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class CustomConfigWidget extends StatefulWidget {
  const CustomConfigWidget({super.key});

  @override
  _CustomConfigWidgetState createState() => _CustomConfigWidgetState();
}

class _CustomConfigWidgetState extends State<CustomConfigWidget>
    with AbusWidgetMixin<CustomConfigWidget> {
  List<ABUSResult> receivedResults = [];
  int rebuilds = 0;

  @override
  AbusUpdateConfig get abusConfig => const AbusUpdateConfig(
        tags: {'ui'},
        rebuildOnSuccess: true,
        rebuildOnError: false,
      );

  @override
  void onAbusResult(ABUSResult result) {
    receivedResults.add(result);
  }

  @override
  bool shouldRebuild(ABUSResult result) {
    rebuilds++;
    return true;
  }

  void reset() {
    receivedResults.clear();
    rebuilds = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Custom Rebuilds: $rebuilds'),
          Text('Custom Results: ${receivedResults.length}'),
        ],
      ),
    );
  }
}

class WorkflowTestWidget extends StatefulWidget {
  final Completer<ABUSResult>? resultCompleter;

  const WorkflowTestWidget({super.key, this.resultCompleter});

  @override
  _WorkflowTestWidgetState createState() => _WorkflowTestWidgetState();
}

class _WorkflowTestWidgetState extends State<WorkflowTestWidget>
    with AbusWidgetMixin<WorkflowTestWidget> {
  List<ABUSResult> workflowSteps = [];

  @override
  void onAbusResult(ABUSResult result) {
    if (result.isSuccess) {
      workflowSteps.add(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('Workflow Steps: ${workflowSteps.length}'),
          ...workflowSteps.map((step) => Text(
              'Step ${step.getData<Map>()!['step']}: ${step.interactionId}')),
        ],
      ),
    );
  }
}

class OptimisticTestWidget extends StatefulWidget {
  const OptimisticTestWidget({super.key});

  @override
  _OptimisticTestWidgetState createState() => _OptimisticTestWidgetState();
}

class _OptimisticTestWidgetState extends State<OptimisticTestWidget>
    with AbusWidgetMixin<OptimisticTestWidget> {
  List<ABUSResult> allResults = [];

  @override
  void onAbusResult(ABUSResult result) {
    allResults.add(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('All Results: ${allResults.length}'),
          ...allResults.map((result) => Text(
              '${result.isSuccess ? 'SUCCESS' : 'ERROR'}: ${result.interactionId}')),
        ],
      ),
    );
  }
}

// Test BLoC and Provider classes
class TestBloc extends Object with AbusBloc<String> {
  String _state = 'initial';

  String get state => _state;

  @override
  Future<void> handleOptimistic(
      String interactionId, InteractionDefinition interaction) async {
    _state = 'optimistic_${interaction.id}';
  }

  @override
  Future<void> handleCommit(
      String interactionId, InteractionDefinition interaction) async {
    _state = 'committed_${interaction.id}';
  }

  @override
  Future<void> handleRollback(
      String interactionId, InteractionDefinition interaction) async {
    _state = 'rolled_back_${interaction.id}';
  }

  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) {
    return Future.value(ABUSResult.success(
      data: {'bloc_handled': true, 'state': _state},
      interactionId: interaction.id,
    ));
  }
}

class TestProvider extends ChangeNotifier with AbusProvider {
  String _data = 'initial';

  String get data => _data;

  void testNotify() {
    notifyListeners();
  }

  @override
  Future<void> handleOptimistic(
      String interactionId, InteractionDefinition interaction) async {
    _data = 'optimistic_${interaction.id}';
    notifyListeners();
  }

  @override
  Future<void> handleCommit(
      String interactionId, InteractionDefinition interaction) async {
    _data = 'committed_${interaction.id}';
    notifyListeners();
  }

  @override
  Future<void> handleRollback(
      String interactionId, InteractionDefinition interaction) async {
    _data = 'rolled_back_${interaction.id}';
    notifyListeners();
  }

  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) {
    return Future.value(ABUSResult.success(
      data: {'provider_handled': true, 'data': _data},
      interactionId: interaction.id,
    ));
  }
}

// Helper class for building test interactions
class TestInteractionBuilder {
  static InteractionDefinition build({
    String? id,
    dynamic payload,
  }) {
    return InteractionBuilder()
        .withId(id ?? 'test_interaction')
        .withPayload(payload ?? {'test': 'data'})
        .build();
  }
}
