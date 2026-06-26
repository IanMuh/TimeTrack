import 'package:flutter_test/flutter_test.dart';
import 'package:timetrack/core/app_version.dart';

void main() {
  group('AppVersion', () {
    test('parses v prefix, prerelease, and build metadata', () {
      final version = AppVersion.parse('v0.2.0-pre+2');

      expect(version.major, 0);
      expect(version.minor, 2);
      expect(version.patch, 0);
      expect(version.prerelease, 'pre');
      expect(version.buildMetadata, '2');
      expect(version.isPrerelease, isTrue);
      expect(version.toString(), '0.2.0-pre+2');
    });

    test('orders prerelease and stable semantic versions', () {
      expect(
        AppVersion.parse('0.2.0-pre'),
        greaterThan(AppVersion.parse('0.1.0-pre')),
      );
      expect(
        AppVersion.parse('0.2.0'),
        greaterThan(AppVersion.parse('0.2.0-pre')),
      );
      expect(
        AppVersion.parse('0.2.0+7').compareTo(AppVersion.parse('0.2.0+2')),
        0,
      );
    });

    test('rejects invalid versions', () {
      expect(() => AppVersion.parse('latest'), throwsFormatException);
      expect(() => AppVersion.parse('1.2'), throwsFormatException);
      expect(() => AppVersion.parse('1.2.3.4'), throwsFormatException);
    });
  });
}
