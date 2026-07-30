import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/ui/ui_components.dart';

void main() {
  testWidgets('DialogContentScrollView limits child height to 85% of parent',
      (tester) async {
    const parentHeight = 400.0;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: parentHeight,
            child: DialogContentScrollView(
              child: SizedBox(
                height: 1000,
                child: Text('Tall content'),
              ),
            ),
          ),
        ),
      ),
    );

    final constrainedBox = find.ancestor(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(ConstrainedBox),
    );
    final constraints = tester.widget<ConstrainedBox>(constrainedBox).constraints;

    expect(constraints.maxHeight, parentHeight * 0.85);
    expect(tester.takeException(), isNull);
  });
}
