# Security and Privacy

TimeTrack is offline-first. Local records are stored on the device first, and Supabase cloud sync, LAN sync, and file import/export are optional ways to move the same data between devices.

## Local Data

- Time entries, activities, settings, sync peers, and device metadata are stored in the local SQLite database.
- The local database is not encrypted by TimeTrack. Use the operating system account, disk encryption, and device lock screen to protect local data.
- Deleting an activity or entry uses soft-delete tombstones so deletions can sync to other devices.

## Supabase Cloud Sync

- Supabase is disabled unless `SUPABASE_URL` and `SUPABASE_ANON_KEY` are provided at build or run time.
- Authentication uses Supabase Email OTP.
- Row-level security in `supabase/schema.sql` limits rows to `auth.uid() = user_id`.
- TimeTrack does not store Supabase service role keys or other server secrets in the app.

## LAN Sync

- LAN sync uses HTTP on the local network with a short-lived pairing code and a stored bearer token for later syncs.
- Pair only on trusted Wi-Fi. Anyone who sees the pairing code during the pairing window may attempt to pair.
- Android keeps cleartext networking available for dynamic LAN hosts, but the LAN client rejects public HTTP hosts and accepts only loopback, private/link-local IPs, `.local` names, or local hostnames.
- Use **Remove pairing** in Settings to clear this device's saved LAN peer. Stop the LAN host when you are done pairing or syncing.

## File Import and Export

- Exported `.timetrack.json` files are plain JSON and may contain activity names, notes, timestamps, device IDs, and settings.
- Store exports in a trusted location and delete old copies when they are no longer needed.
- Import validates the TimeTrack bundle schema before merging data into the local repository.

## Reminders

- Current reminders are in-app prompts. They are not operating-system notifications and are not guaranteed to appear when the app is closed, suspended, or restricted in the background.
- Android local notifications and Windows toast notifications are future platform enhancements, not part of the current reminder behavior.

## Release Handling

- Do not commit `android/key.properties`, keystores, local database files, Supabase service keys, or build outputs.
- Release builds should be produced only after `flutter analyze` and `flutter test` pass.
