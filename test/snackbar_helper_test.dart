import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/ui/snackbar_helper.dart';

void main() {
  testWidgets('showAppSnackBar displays message and action', (tester) async {
    var actionTapped = false;
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showAppSnackBar(
                  context,
                  message: 'Hello',
                  actionLabel: 'Undo',
                  onAction: () => actionTapped = true,
                );
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(actionTapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showErrorSnackBar displays message without action',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showErrorSnackBar(context, message: 'Oops');
              },
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    expect(find.text('Oops'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
