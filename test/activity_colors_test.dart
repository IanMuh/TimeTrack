import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/ui/activity_colors.dart';

void main() {
  test('nextActivityColor chooses the first unused palette color', () {
    expect(
      nextActivityColor([
        activityPalette[0],
        activityPalette[1],
      ]),
      activityPalette[2],
    );
  });

  test('nextActivityColor cycles after all palette colors are used', () {
    expect(
      nextActivityColor(activityPalette),
      activityPalette[0],
    );
  });
}
