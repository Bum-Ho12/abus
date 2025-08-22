// test/widget/abus_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abus/abus.dart';

void main() {
  group('ABUS Widget Tests', () {
    setUp(() {
      ABUSManager.reset();
    });

    tearDown(() {
      ABUS.manager.dispose();
    });

    testWidgets('should rebuild widget on ABUS result', (tester) async {
      final handler = WidgetTestHandler();
      ABUS.registerHandler(handler);

      await tester.pumpWidget(
        const MaterialApp(
          home: TestWidget(),
        ),
      );

      // Verify initial state
      expect(find.text('Count: 0'), findsOneWidget);

      // Execute interaction
      final interaction = ABUS
          .builder()
          .withId('widget_test')
          .addData('increment', 1)
          .addTag('counter')
          .build();

      await ABUS.execute(interaction);
      await tester.pump(const Duration(seconds: 31)); // Trigger rebuild

      // Verify updated state
      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('should filter results by configuration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FilteredTestWidget(),
        ),
      );

      // Verify initial state
      expect(find.text('Filtered Count: 0'), findsOneWidget);

      // Execute interaction that should be filtered out
      final filteredInteraction = ABUS
          .builder()
          .withId('filtered_test')
          .addData('should_filter', true)
          .addTag('update')
          .build();

      ABUS.registerApiHandler((interaction) async {
        return ABUSResult.success(interactionId: interaction.id);
      });

      await ABUS.execute(filteredInteraction);
      await tester.pump();

      // Still 0 because filtered
      expect(find.text('Filtered Count: 0'), findsOneWidget);

      // Execute interaction that should not be filtered
      final unFilteredInteraction = ABUS
          .builder()
          .withId('unfiltered_test')
          .addData('should_filter', false)
          .addTag('update')
          .build();

      await ABUS.execute(unFilteredInteraction);
      await tester.pump(const Duration(seconds: 31));

      // Should now show updated state
      expect(find.text('Filtered Count: 1'), findsOneWidget);
    });

    testWidgets('should handle interaction execution from widget',
        (tester) async {
      final handler = WidgetTestHandler();
      ABUS.registerHandler(handler);

      await tester.pumpWidget(
        const MaterialApp(
          home: InteractiveTestWidget(),
        ),
      );

      // Tap the button to trigger interaction
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(seconds: 31));

      // Verify interaction was executed and widget updated
      expect(find.text('Button Pressed: 1'), findsOneWidget);
    });

    testWidgets('should handle optimistic updates with rollback',
        (tester) async {
      final handler = RollbackTestHandler();
      ABUS.registerHandler(handler);

      await tester.pumpWidget(
        const MaterialApp(
          home: OptimisticTestWidget(),
        ),
      );

      expect(find.text('Status: idle'), findsOneWidget);

      // Trigger optimistic interaction that will fail
      await tester.tap(find.byType(GestureDetector));

      // Processing is set immediately
      expect(find.text('Status: processing'), findsOneWidget);

      // Wait for API failure and rollback
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Status: failed'), findsOneWidget);
    });

    testWidgets('should debounce rapid updates', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DebouncedTestWidget(),
        ),
      );

      ABUS.registerApiHandler((interaction) async {
        return ABUSResult.success(interactionId: interaction.id);
      });

      // Execute multiple rapid interactions
      for (int i = 0; i < 5; i++) {
        final interaction = ABUS
            .builder()
            .withId('debounce_$i')
            .addData('dummy', true)
            .addTag('debounced')
            .build();
        await ABUS.execute(interaction);
      }

      // Should only update once after debounce
      await tester.pump(const Duration(milliseconds: 600)); // Wait for debounce
      expect(find.text('Update Count: 1'), findsOneWidget);
    });

    testWidgets('should handle visibility tracking', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VisibilityTestWidget(),
        ),
      );

      final state = tester
          .state<_VisibilityTestWidgetState>(find.byType(VisibilityTestWidget));

      // Execute interaction while visible
      final interaction = ABUS
          .builder()
          .withId('visibility_test')
          .addData('dummy', true)
          .addTag('visibility')
          .build();

      ABUS.registerApiHandler((interaction) async {
        return ABUSResult.success(interactionId: interaction.id);
      });

      await ABUS.execute(interaction);
      await tester.pump(const Duration(seconds: 31));

      expect(find.text('Updates: 1'), findsOneWidget);

      // Set widget as not visible
      state.setVisible(false);

      // Execute another interaction
      final interaction2 = ABUS
          .builder()
          .withId('visibility_test_2')
          .addData('dummy', true)
          .addTag('visibility')
          .build();

      await ABUS.execute(interaction2);
      await tester.pump();

      // Should still show 1 update (not 2) because widget was not visible
      expect(find.text('Updates: 1'), findsOneWidget);
    });

    testWidgets('should handle widget lifecycle correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LifecycleTestWidget(),
        ),
      );

      // Execute interaction
      final interaction = ABUS
          .builder()
          .withId('lifecycle_test')
          .addData('dummy', true)
          .build();

      ABUS.registerApiHandler((interaction) async {
        return ABUSResult.success(interactionId: interaction.id);
      });

      await ABUS.execute(interaction);
      await tester.pump();

      expect(find.text('State: updated'), findsOneWidget);

      // Remove widget
      await tester.pumpWidget(Container());

      // Execute another interaction - should not cause errors
      final interaction2 = ABUS
          .builder()
          .withId('lifecycle_test_2')
          .addData('dummy', true)
          .build();

      await ABUS.execute(interaction2);
      await tester.pump();

      // Should complete without errors
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}

class TestWidget extends StatefulWidget {
  const TestWidget({super.key});

  @override
  _TestWidgetState createState() => _TestWidgetState();
}

class _TestWidgetState extends State<TestWidget> with AbusWidgetMixin {
  int count = 0;

  @override
  AbusUpdateConfig get abusConfig => const AbusUpdateConfig(
        tags: {'counter'},
      );

  @override
  void onAbusResult(ABUSResult result) {
    if (result.isSuccess) {
      setState(() {
        count++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Count: $count'),
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
    with AbusWidgetMixin {
  int count = 0;

  @override
  AbusUpdateConfig get abusConfig => AbusUpdateConfig(
        tags: {'update'},
        customFilter: (result) {
          // Filter out results that have should_filter = true in metadata
          return !(result.data?['should_filter'] == true);
        },
      );

  @override
  void onAbusResult(ABUSResult result) {
    setState(() {
      count++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Filtered Count: $count'),
      ),
    );
  }
}

class InteractiveTestWidget extends StatefulWidget {
  const InteractiveTestWidget({super.key});

  @override
  _InteractiveTestWidgetState createState() => _InteractiveTestWidgetState();
}

class _InteractiveTestWidgetState extends State<InteractiveTestWidget>
    with AbusWidgetMixin {
  int buttonPresses = 0;

  void _onButtonPress() async {
    final interaction = interactionBuilder()
        .withId('button_press')
        .addData('timestamp', DateTime.now().millisecondsSinceEpoch)
        .build();

    await executeInteraction(interaction);
  }

  @override
  void onAbusResult(ABUSResult result) {
    if (result.isSuccess && result.interactionId == 'button_press') {
      setState(() {
        buttonPresses++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Button Pressed: $buttonPresses'),
          ElevatedButton(
            onPressed: _onButtonPress,
            child: const Text('Press Me'),
          ),
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
    with AbusWidgetMixin {
  String status = 'idle';

  void _executeOptimistic() async {
    setState(() {
      status = 'processing';
    });

    final interaction =
        ABUS.builder().withId('optimistic_test').addData('test', true).build();

    // This will trigger optimistic update, then fail and rollback
    await executeInteraction(interaction, optimistic: true);
  }

  @override
  void onAbusResult(ABUSResult result) {
    setState(() {
      if (result.metadata?['rollback'] == true) {
        status = 'failed';
      } else if (result.isSuccess) {
        status = 'success';
      } else {
        status = 'error';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Status: $status'),
          GestureDetector(
            onTap: _executeOptimistic,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue,
              child: const Text('Execute Optimistic'),
            ),
          ),
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
    with AbusWidgetMixin {
  int updateCount = 0;

  @override
  AbusUpdateConfig get abusConfig => const AbusUpdateConfig(
        tags: {'debounced'},
        debounceDelay: Duration(milliseconds: 500),
      );

  @override
  void onAbusResult(ABUSResult result) {
    setState(() {
      updateCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Update Count: $updateCount'),
      ),
    );
  }
}

class VisibilityTestWidget extends StatefulWidget {
  const VisibilityTestWidget({super.key});

  @override
  _VisibilityTestWidgetState createState() => _VisibilityTestWidgetState();
}

class _VisibilityTestWidgetState extends State<VisibilityTestWidget>
    with AbusWidgetMixin {
  int updates = 0;

  @override
  AbusUpdateConfig get abusConfig => const AbusUpdateConfig(
        tags: {'visibility'},
        onlyWhenVisible: true,
      );

  @override
  void onAbusResult(ABUSResult result) {
    setState(() {
      updates++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Updates: $updates'),
      ),
    );
  }
}

class LifecycleTestWidget extends StatefulWidget {
  const LifecycleTestWidget({super.key});

  @override
  _LifecycleTestWidgetState createState() => _LifecycleTestWidgetState();
}

class _LifecycleTestWidgetState extends State<LifecycleTestWidget>
    with AbusWidgetMixin {
  String state = 'init';

  @override
  void initState() {
    super.initState();
    state = 'active';
  }

  @override
  void onAbusResult(ABUSResult result) {
    if (mounted) {
      setState(() {
        state = 'updated';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('State: $state'),
      ),
    );
  }
}

// Test Handlers
class WidgetTestHandler extends CustomAbusHandler {
  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) {
    return Future.value(ABUSResult.success(
      data: {'processed': true},
      interactionId: interaction.id,
    ));
  }
}

class RollbackTestHandler extends CustomAbusHandler {
  @override
  Future<void> handleOptimistic(
      String interactionId, InteractionDefinition interaction) async {
    // Optimistic update handled
  }

  @override
  Future<ABUSResult>? executeAPI(InteractionDefinition interaction) {
    // Simulate API failure
    return Future.value(ABUSResult.error('API Error'));
  }

  @override
  Future<void> handleRollback(
      String interactionId, InteractionDefinition interaction) async {
    // Rollback handled
  }
}
