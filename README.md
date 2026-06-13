# TimeTrack

TimeTrack is a personal, offline-first time tracker for Windows and Android.

## Setup

1. Install Flutter with Windows desktop and Android support.
2. Generate native platform folders:

   ```powershell
   flutter create --platforms=windows,android .
   ```

3. Create a Supabase project and run `supabase/schema.sql` in the SQL editor.
4. In Supabase Auth, enable email OTP login.
5. Provide Supabase config at runtime:

   ```powershell
   flutter run -d windows `
     --dart-define=SUPABASE_URL=https://your-project.supabase.co `
     --dart-define=SUPABASE_ANON_KEY=your-anon-key
   ```

Without Supabase config the app runs in local-only mode.

## Commands

```powershell
flutter pub get
flutter test
flutter run -d windows
flutter run -d android
```

The first build requires generated `android/` and `windows/` folders. They are
not committed here because this machine does not have the Flutter SDK installed.
