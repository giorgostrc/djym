import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// [testWidgets] for tests that pump the app: it is unmounted at the end of
/// the test, failed or not, so drift's stream timers run before Flutter checks
/// for pending ones. Unmounting only on success left a failed test's database
/// unable to close in `tearDown`, hanging the file instead of reporting it.
void testWidgetsThenUnmount(
  String description,
  WidgetTesterCallback callback, {
  bool? skip,
}) => testWidgets(description, skip: skip, (tester) async {
  try {
    await callback(tester);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }
});
