import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggym/ui/core/text_input.dart';

void main() {
  testWidgets('focusing selects the whole value, a second tap does not', (
    tester,
  ) async {
    final controller = TextEditingController(text: '62.5');
    final focusNode = SelectAllFocusNode(controller);
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(controller: controller, focusNode: focusNode),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 4),
    );

    await tester.tapAt(
      tester.getTopLeft(find.byType(TextField)) + const Offset(2, 20),
    );
    await tester.pumpAndSettle();

    expect(controller.selection.isCollapsed, isTrue);
  });

  testWidgets('the clear button empties the field and reports it', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Squat');
    addTearDown(controller.dispose);
    String? reported;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              void onChanged(String text) => setState(() => reported = text);
              return TextField(
                controller: controller,
                decoration: InputDecoration(
                  suffixIcon: clearButton(controller, onChanged: onChanged),
                ),
                onChanged: onChanged,
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(reported, isEmpty);
    expect(find.byTooltip('Clear'), findsNothing);
  });

  testWidgets('tapping outside the field closes the keyboard', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        actions: {...WidgetsApp.defaultActions, ...unfocusOnTapOutside},
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: focusNode),
              const SizedBox(height: 300, width: 300),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tapAt(const Offset(200, 400));
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
  });
}
