# Repository Guidelines

## Project Structure & Module Organization

TimeTrack is a Flutter app for Windows and Android with offline-first storage and optional Supabase sync. Application code lives in `lib/`: `core/` contains shared utilities and configuration, `domain/` contains value objects and models, `data/` contains SQLite/Supabase persistence, `app/` contains app state, and `ui/` contains pages and layout widgets. Tests live in `test/` and currently cover domain models, repository behavior, and adaptive layout. Platform code is under `android/` and `windows/`; database setup is in `supabase/schema.sql`.

## Build, Test, and Development Commands

- `flutter pub get`: install Dart and Flutter dependencies from `pubspec.yaml`.
- `flutter analyze`: run static analysis using `flutter_lints` and local rules.
- `flutter test`: run all tests in `test/`.
- `flutter run -d windows`: run the desktop app locally.
- `flutter run -d android`: run on an Android emulator or device.
- `flutter build windows --release`: produce a Windows release build.

To enable cloud sync, pass Supabase runtime config:

```powershell
flutter run -d windows `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Without these defines, the app should continue to run in local-only mode.

## Coding Style & Naming Conventions

Use standard Dart formatting with two-space indentation; run `dart format lib test` before submitting changes. The project includes `package:flutter_lints/flutter.yaml` and enforces `prefer_single_quotes`. Use `PascalCase` for classes and widgets, `camelCase` for members and variables, and `snake_case.dart` file names. Keep UI widgets in `lib/ui/`, persistence concerns in `lib/data/`, and pure business objects in `lib/domain/`.

## Testing Guidelines

Use `flutter_test` for unit and widget tests. Name test files with the `_test.dart` suffix and mirror the unit under test, for example `time_entry_test.dart` for `lib/domain/time_entry.dart`. Add or update tests when changing domain rules, repository behavior, layout breakpoints, or sync logic. Run `flutter test` and `flutter analyze` before opening a PR.

## Commit & Pull Request Guidelines

The current history only contains `Initial commit`, so no strict commit convention is established. Use short, imperative commit subjects such as `Add activity color selector` or `Fix repository sync conflict`. Pull requests should include a concise description, test results, linked issues when applicable, and screenshots or recordings for UI changes on Windows and Android.

## Security & Configuration Tips

Do not commit Supabase URLs, anon keys, service keys, generated credentials, or local database files. Keep schema changes in `supabase/schema.sql` and document any required Supabase Auth settings, such as email OTP, in the PR description.
