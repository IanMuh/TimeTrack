import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/domain/activity.dart';
import 'package:timetrack/ui/home_page.dart';

Activity _activity() {
  return Activity(
    id: 'work',
    userId: null,
    name: '工作',
    color: 0xff2563eb,
    isFavorite: true,
    updatedAt: DateTime(2026, 1, 1),
    isDeleted: false,
  );
}

void main() {
  testWidgets('activity button supports two tap confirmation flow', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivitySwitchButton(
            activity: _activity(),
            selected: false,
            pending: false,
            onTap: () => taps += 1,
            onDoubleTap: () {},
            onEdit: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('工作'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 1));

    expect(taps, 1);

    await tester.tap(find.text('工作'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(taps, 2);
  });
}
