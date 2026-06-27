# TimeTrack pre0.2 Update Check Remaining Work

## TL;DR
> Summary:      Finish the user-facing update check by adding localized settings UI, a one-time startup snackbar that routes to Settings, README release/update documentation, and evidence-backed verification. The core update parser/service/AppState wiring already exists and must be preserved.
> Deliverables:
> - Localized update-check strings and regenerated Flutter localization outputs.
> - Settings update card with manual check and external download-page action.
> - One-time AppShell update snackbar whose action navigates to Settings.
> - Focused widget tests and C001-C003 evidence files.
> - README release/update documentation.
> Effort:       Medium
> Risk:         Medium - Generated l10n, widget layout, platform build attempts, and a dirty worktree must be handled without touching `docs/architecture-audit.md`.

## Scope
### Must have
- Preserve the existing core update behavior in `lib/core/app_version.dart`, `lib/data/app_update_service.dart`, and `lib/app/app_state.dart`.
- Add an update card to `SettingsPage` using existing `QuietPanel`, `SectionTitle`, button, status, and responsive layout patterns from `lib/ui/settings_page.dart:20`, `lib/ui/settings_page.dart:100`, `lib/ui/settings_page.dart:161`, `lib/ui/settings_page.dart:364`, and `lib/ui/settings_page.dart:503`.
- The settings card must show current version when known, update status, available version/release name when available, errors when failed, a manual check button, and an "open download page" action only when `state.availableUpdate != null`.
- Add AppShell one-time snackbar behavior based on `state.shouldShowUpdatePrompt` from `lib/app/app_state.dart:221`; its action must navigate to Settings using the existing destination index 3 from `lib/ui/app_shell.dart:51` and `lib/ui/app_shell.dart:130`.
- Add all new strings to `lib/l10n/app_zh.arb` and `lib/l10n/app_en.arb`, then regenerate `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_zh.dart`, and `lib/l10n/app_localizations_en.dart`.
- Add focused widget tests for Settings update-card states and AppShell snackbar routing/repeat behavior.
- Update README docs for GitHub Releases update checks, `UPDATE_RELEASES_URL`, and no silent install/download behavior.
- Capture C001-C003 evidence exactly under `.omo/ulw-loop/evidence/`:
  - C001: `.omo/ulw-loop/evidence/pre02-core-tests.txt`
  - C002: `.omo/ulw-loop/evidence/pre02-widget-tests.txt`
  - C003: `.omo/ulw-loop/evidence/pre02-release-readiness.txt`

### Must NOT have (guardrails, anti-slop, scope boundaries)
- Do not download, install, or replace binaries inside the app. Only open the release/download page externally through `AppUpdateService.openDownload`.
- Do not make Supabase required. Existing optional Supabase behavior is controlled by `AppConfig.hasSupabase` at `lib/core/app_config.dart:9` and must remain optional.
- Do not add SQLite or Supabase schema changes. Keep `lib/data/local_database.dart` and `supabase/schema.sql` out of scope.
- Do not touch `docs/architecture-audit.md`.
- Do not introduce background polling beyond the existing one startup check in `lib/app/app_state.dart:363`.
- Do not make widget tests hit the network or GitHub.
- Do not split implementation from its tests for the same behavior.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: tests-after + Flutter `flutter_test` widget tests and existing unit tests.
- QA policy: every task has agent-executed scenarios.
- Evidence: `.omo/evidence/task-<N>-<slug>.<ext>` plus C001-C003 evidence in `.omo/ulw-loop/evidence/`.

## Execution strategy
### Parallel execution waves
> Target 5-8 tasks per wave. <3 per wave (except final) = under-splitting.
> Extract shared dependencies as Wave-1 tasks to maximize parallelism.

Wave 1 (no dependencies):
- Task 1: Add update-check localization resources and generated outputs
- Task 4: Document update checks and release expectations in README

Wave 2 (after Wave 1):
- Task 2: depends [1] - Add Settings update card and widget coverage
- Task 3: depends [1] - Add AppShell one-time update snackbar and widget coverage

Wave 3 (after Wave 2):
- Task 5: depends [2, 3] - Capture C001/C002 focused evidence
- Task 6: depends [2, 3, 4, 5] - Capture full C003 release-readiness evidence

Critical path: Task 1 -> Task 2 -> Task 5 -> Task 6

Note: Wave widths are below the 5-8 target because this is a remaining-work plan with hard l10n dependencies and disjoint write sets. Do not create artificial source-code splits just to widen a wave.

### Dependency matrix
| Task | Depends on | Blocks | Can parallelize with |
|------|------------|--------|----------------------|
| 1    | none       | 2, 3   | 4                    |
| 2    | 1          | 5, 6   | 3                    |
| 3    | 1          | 5, 6   | 2                    |
| 4    | none       | 6      | 1                    |
| 5    | 2, 3       | 6      | none                 |
| 6    | 2, 3, 4, 5 | final  | none                 |

## Todos
> Implementation + Test = ONE task. Never separate.
> Every task MUST have: References + Acceptance Criteria + QA Scenarios + Commit.

- [ ] 1. Add update-check localization resources and generated outputs

  What to do: Add new ARB keys for update card labels, status text, snackbar copy, and download/check actions in both ARB files near the existing settings strings. Run Flutter l10n generation so all generated localization Dart files expose the new getters/placeholders.
  Must NOT do: Do not manually hand-edit generated localization Dart beyond what `flutter gen-l10n` produces. Do not remove or rename existing keys.

  Parallelization: Can parallel: YES | Wave 1 | Blocks: [2, 3] | Blocked by: []

  References (executor has NO interview context - be exhaustive):
  - Pattern:  `lib/l10n/app_zh.arb:275` - Settings strings are grouped here and this is the template ARB per `l10n.yaml`.
  - Pattern:  `lib/l10n/app_en.arb:275` - English translations mirror the same settings key group.
  - Pattern:  `lib/l10n/app_localizations.dart:935` - Generated abstract getters appear here after `flutter gen-l10n`.
  - Pattern:  `lib/l10n/app_localizations_zh.dart:464` - Generated Chinese concrete strings.
  - Pattern:  `lib/l10n/app_localizations_en.dart:477` - Generated English concrete strings.
  - API/Type: `lib/data/app_update_service.dart:11` - `AppUpdateStatus` names the states to render.
  - API/Type: `lib/data/app_update_service.dart:19` - `AppUpdateInfo` fields available for UI copy.
  - Config:   `l10n.yaml:1` - ARB directory, template file, and generated output.
  - External: `https://docs.flutter.dev/ui/internationalization` - Flutter ARB and localization generation guidance.

  Acceptance criteria (agent-executable only):
  - [ ] `flutter gen-l10n` exits 0.
  - [ ] `rg -n "updateSettings|checkForUpdates|openDownloadPage|startupUpdateAvailable|viewUpdate" lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_en.dart` finds generated getters/implementations.
  - [ ] `powershell -NoProfile -Command "$zh=(Get-Content 'lib/l10n/app_zh.arb' -Raw | ConvertFrom-Json).psobject.Properties.Name; $en=(Get-Content 'lib/l10n/app_en.arb' -Raw | ConvertFrom-Json).psobject.Properties.Name; $keys=@('updateSettings','updateSettingsHint','currentVersionLabel','updateStatusIdle','updateStatusChecking','updateStatusUpToDate','updateStatusAvailable','updateStatusFailed','checkForUpdates','openDownloadPage','updateCheckFailed','startupUpdateAvailable','viewUpdate'); foreach ($k in $keys) { if (($zh -notcontains $k) -or ($en -notcontains $k)) { throw \"missing $k\" } }; 'l10n parity ok'"` exits 0.

  QA scenarios (MANDATORY - task incomplete without these):
  > Name the exact tool AND its exact invocation - not "verify it works". Browser use: use Chrome to drive the page; if Chrome is not available, download and use agent-browser (https://github.com/vercel-labs/agent-browser). Computer use: OS-level GUI automation for a non-browser desktop app.
  ```
  Scenario: l10n generation exposes update strings
    Tool:     bash
    Steps:    mkdir -p .omo/evidence && { echo "COMMAND: flutter gen-l10n"; flutter gen-l10n; echo "COMMAND: rg generated update getters"; rg -n "updateSettings|checkForUpdates|openDownloadPage|startupUpdateAvailable|viewUpdate" lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_en.dart; } > .omo/evidence/task-1-l10n-gen.txt 2>&1
    Expected: Command exits 0 and evidence contains generated references for all searched update keys.
    Evidence: .omo/evidence/task-1-l10n-gen.txt

  Scenario: ARB key parity covers edge states
    Tool:     bash
    Steps:    mkdir -p .omo/evidence && powershell -NoProfile -Command "$zh=(Get-Content 'lib/l10n/app_zh.arb' -Raw | ConvertFrom-Json).psobject.Properties.Name; $en=(Get-Content 'lib/l10n/app_en.arb' -Raw | ConvertFrom-Json).psobject.Properties.Name; $keys=@('updateSettings','updateSettingsHint','currentVersionLabel','updateStatusIdle','updateStatusChecking','updateStatusUpToDate','updateStatusAvailable','updateStatusFailed','checkForUpdates','openDownloadPage','updateCheckFailed','startupUpdateAvailable','viewUpdate'); foreach ($k in $keys) { if (($zh -notcontains $k) -or ($en -notcontains $k)) { throw \"missing $k\" } }; 'l10n parity ok'" > .omo/evidence/task-1-l10n-parity.txt 2>&1
    Expected: Command exits 0 and evidence contains "l10n parity ok".
    Evidence: .omo/evidence/task-1-l10n-parity.txt
  ```

  Commit: YES | Message: `feat(l10n): add update check strings` | Files: [`lib/l10n/app_zh.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_zh.dart`, `lib/l10n/app_localizations_en.dart`]

- [ ] 2. Add Settings update card and widget coverage

  What to do: Add an `UpdateSettingsCard` to `SettingsPage`. It must use existing panel/card styling, render all `AppUpdateStatus` states, show `currentAppVersion` when non-empty, show `availableUpdate.latestVersion` and `releaseName` when available, show `updateErrorMessage` when failed, call `state.checkForUpdates()` from a manual button, and call `state.openUpdateDownload()` only from an explicit user action when an update is available. Add focused widget tests in a new `test/settings_update_card_test.dart` or an existing UI test file if the worker can keep the file readable.
  Must NOT do: Do not call `openUpdateDownload()` automatically. Do not trigger network directly from the widget. Do not change Supabase, LAN, import/export, or reminder controls.

  Parallelization: Can parallel: YES | Wave 2 | Blocks: [5, 6] | Blocked by: [1]

  References (executor has NO interview context - be exhaustive):
  - Pattern:  `lib/ui/settings_page.dart:20` - `SettingsPage` builds an `AdaptivePage` with a `LayoutBuilder`.
  - Pattern:  `lib/ui/settings_page.dart:29` - Current compact/expanded card layout decision.
  - Pattern:  `lib/ui/settings_page.dart:100` - `QuietPanel` plus `SectionTitle` card pattern.
  - Pattern:  `lib/ui/settings_page.dart:351` - Existing `CloudSyncSettingsCard` status/actions pattern.
  - Pattern:  `lib/ui/settings_page.dart:476` - Existing interop card shows explicit file/import/sync actions.
  - API/Type: `lib/app/app_state.dart:99` - `updateStatus`, `availableUpdate`, `currentAppVersion`, and `updateErrorMessage` are public state fields.
  - API/Type: `lib/app/app_state.dart:300` - Manual update check entry point.
  - API/Type: `lib/app/app_state.dart:346` - Explicit external download-page action.
  - Test:     `test/ui_controls_test.dart:142` - Existing `SettingsPage` compact widget test pattern.
  - Test:     `test/test_fixtures.dart:91` - Fixture can build `AppState` with fake update services and version/platform loaders.
  - Test:     `test/app_state_update_test.dart:134` - Fake update service pattern for check/open counters.
  - External: `https://docs.flutter.dev/cookbook/testing/widget/introduction` - Widget-test structure.
  - External: `https://pub.dev/documentation/url_launcher/latest/url_launcher/LaunchMode.html` - External application launch concept used by the service.

  Acceptance criteria (agent-executable only):
  - [ ] `flutter test test/settings_update_card_test.dart` exits 0.
  - [ ] A widget test verifies available state renders a concrete latest version such as `0.2.0-pre`, renders the explicit download action, and increments a fake `openDownload` counter only after tapping that action.
  - [ ] A widget test verifies checking/up-to-date/failed states render without `tester.takeException()` and without overflow at compact width 320 or 390.
  - [ ] `rg -n "UpdateSettingsCard|openUpdateDownload|checkForUpdates" lib/ui/settings_page.dart test/settings_update_card_test.dart` finds the implemented widget and test coverage.

  QA scenarios (MANDATORY - task incomplete without these):
  > Name the exact tool AND its exact invocation - not "verify it works". Browser use: use Chrome to drive the page; if Chrome is not available, download and use agent-browser (https://github.com/vercel-labs/agent-browser). Computer use: OS-level GUI automation for a non-browser desktop app.
  ```
  Scenario: available update opens only after explicit tap
    Tool:     bash
    Steps:    mkdir -p .omo/evidence && flutter test test/settings_update_card_test.dart --plain-name "SettingsPage update card opens download for available update" > .omo/evidence/task-2-settings-available.txt 2>&1
    Expected: Command exits 0; evidence shows the named test passed; fake open counter is asserted to stay 0 before tap and become 1 after tap.
    Evidence: .omo/evidence/task-2-settings-available.txt

  Scenario: status edge states render without overflow
    Tool:     bash
    Steps:    mkdir -p .omo/evidence && flutter test test/settings_update_card_test.dart --plain-name "SettingsPage update card renders checking up-to-date and failed states" > .omo/evidence/task-2-settings-edge.txt 2>&1
    Expected: Command exits 0; evidence shows checking, up-to-date, and failed states passed with no Flutter exception output.
    Evidence: .omo/evidence/task-2-settings-edge.txt
  ```

  Commit: YES | Message: `feat(settings): show update check card` | Files: [`lib/ui/settings_page.dart`, `test/settings_update_card_test.dart`]

- [ ] 3. Add AppShell one-time update snackbar and widget coverage

  What to do: Extend `AppShell` passive prompts so an available startup update shows a one-time snackbar. The snackbar content must include the latest version or release name, use localized copy, and its action must switch to Settings (`_index = 3`) rather than opening the download directly. Mark the prompt shown through `state.markUpdatePromptShown()` so repeated `notifyListeners()` calls do not show duplicate snackbars. Add tests to the existing shell widget test file.
  Must NOT do: Do not show the snackbar when `availableUpdate` is null. Do not navigate to the release URL from the snackbar. Do not break reminder banner/dialog and suspicious-entry prompts.

  Parallelization: Can parallel: YES | Wave 2 | Blocks: [5, 6] | Blocked by: [1]

  References (executor has NO interview context - be exhaustive):
  - Pattern:  `lib/ui/app_shell.dart:60` - Shell builds page list once, including `SettingsPage`.
  - Pattern:  `lib/ui/app_shell.dart:68` - Shell listens to `state` for passive prompts.
  - Pattern:  `lib/ui/app_shell.dart:77` - Existing passive prompt coordinator.
  - Pattern:  `lib/ui/app_shell.dart:91` - Existing snackbar lifecycle pattern for reminder banner.
  - Pattern:  `lib/ui/app_shell.dart:130` - Existing destination selection helper.
  - Pattern:  `lib/ui/app_shell.dart:258` - Compact bottom navigation uses the same selected index.
  - API/Type: `lib/app/app_state.dart:221` - `shouldShowUpdatePrompt` is the one-time prompt predicate.
  - API/Type: `lib/app/app_state.dart:292` - `markUpdatePromptShown()` persists the prompt as shown for this app session.
  - API/Type: `lib/data/app_update_service.dart:19` - `AppUpdateInfo` fields for snackbar message.
  - Test:     `test/app_shell_shortcuts_test.dart:189` - Existing shell pump helper.
  - Test:     `test/app_shell_shortcuts_test.dart:323` - Existing destination shortcut test reaches Settings.
  - External: `https://docs.flutter.dev/cookbook/testing/widget/tap-drag` - Widget interaction testing for tap and pump.

  Acceptance criteria (agent-executable only):
  - [ ] `flutter test test/app_shell_shortcuts_test.dart --plain-name "update snackbar navigates to settings once"` exits 0.
  - [ ] The shell test proves snackbar action selects Settings and does not call `openUpdateDownload`.
  - [ ] The shell test proves a second `notifyListeners()` after `markUpdatePromptShown()` does not create another update snackbar.
  - [ ] Existing shortcut tests in `test/app_shell_shortcuts_test.dart` still pass.

  QA scenarios (MANDATORY - task incomplete without these):
  > Name the exact tool AND its exact invocation - not "verify it works". Browser use: use Chrome to drive the page; if Chrome is not available, download and use agent-browser (https://github.com/vercel-labs/agent-browser). Computer use: OS-level GUI automation for a non-browser desktop app.
  ```
  Scenario: snackbar action routes to Settings
    Tool:     bash
    Steps:    mkdir -p .omo/evidence && flutter test test/app_shell_shortcuts_test.dart --plain-name "update snackbar navigates to settings once" > .omo/evidence/task-3-shell-snackbar.txt 2>&1
    Expected: Command exits 0; evidence shows the named test passed and Settings text is found after tapping snackbar action.
    Evidence: .omo/evidence/task-3-shell-snackbar.txt

  Scenario: repeated state changes do not duplicate the prompt
    Tool:     bash
    Steps:    mkdir -p .omo/evidence && flutter test test/app_shell_shortcuts_test.dart --plain-name "update snackbar is not repeated after prompt is marked shown" > .omo/evidence/task-3-shell-no-repeat.txt 2>&1
    Expected: Command exits 0; evidence shows one initial snackbar and no second update snackbar after another state notification.
    Evidence: .omo/evidence/task-3-shell-no-repeat.txt
  ```

  Commit: YES | Message: `feat(shell): route update prompt to settings` | Files: [`lib/ui/app_shell.dart`, `test/app_shell_shortcuts_test.dart`]

- [ ] 4. Document update checks and release expectations in README

  What to do: Update README docs to mention manual/startup update checks, GitHub Releases as the default release source, optional `UPDATE_RELEASES_URL`, expected Windows/Android release assets, and the explicit no-silent-download/install policy. Keep existing release, Supabase, and keystore instructions intact.
  Must NOT do: Do not document Supabase as required. Do not claim the app can install updates automatically. Do not edit `docs/architecture-audit.md`.

  Parallelization: Can parallel: YES | Wave 1 | Blocks: [6] | Blocked by: []

  References (executor has NO interview context - be exhaustive):
  - Pattern:  `README.md:5` - Current feature list.
  - Pattern:  `README.md:48` - Optional compile-time configuration section for Supabase.
  - Pattern:  `README.md:68` - Build and install section.
  - Pattern:  `README.md:108` - Release checklist.
  - Pattern:  `README.md:119` - Existing release guardrails.
  - API/Type: `lib/core/app_config.dart:4` - `UPDATE_RELEASES_URL` compile-time define and default GitHub API URL.
  - API/Type: `lib/data/app_update_service.dart:61` - Default release endpoint mirrors config.
  - API/Type: `lib/data/app_update_service.dart:127` - App opens the update download URL, it does not install.
  - External: `https://docs.github.com/rest/releases/releases` - GitHub Releases list endpoint.
  - External: `https://docs.github.com/rest/releases/assets` - `browser_download_url` release asset behavior.
  - External: `https://pub.dev/documentation/package_info_plus/latest/package_info_plus/PackageInfo-class.html` - App version metadata source.

  Acceptance criteria (agent-executable only):
  - [ ] `rg -n "UPDATE_RELEASES_URL|GitHub Releases|browser_download_url|silent|install|update" README.md` finds the new update-check documentation.
  - [ ] `git diff -- README.md` shows only README changes and no edits to `docs/architecture-audit.md`.
  - [ ] `git diff -- docs/architecture-audit.md` is empty.

  QA scenarios (MANDATORY - task incomplete without these):
  > Name the exact tool AND its exact invocation - not "verify it works". Browser use: use Chrome to drive the page; if Chrome is not available, download and use agent-browser (https://github.com/vercel-labs/agent-browser). Computer use: OS-level GUI automation for a non-browser desktop app.
  ```
  Scenario: update-check docs are discoverable
    Tool:     bash
    Steps:    mkdir -p .omo/evidence && { rg -n "UPDATE_RELEASES_URL|GitHub Releases|browser_download_url|update" README.md; git diff -- README.md; } > .omo/evidence/task-4-readme-update-docs.txt 2>&1
    Expected: Command exits 0; evidence contains README lines for UPDATE_RELEASES_URL, GitHub Releases, release assets, and update behavior.
    Evidence: .omo/evidence/task-4-readme-update-docs.txt

  Scenario: docs guardrails remain intact
    Tool:     bash
    Steps:    mkdir -p .omo/evidence && { rg -n "SUPABASE_URL|SUPABASE_ANON_KEY|keystore|不要提交|no.*install|silent" README.md; git diff -- docs/architecture-audit.md; } > .omo/evidence/task-4-readme-guardrails.txt 2>&1
    Expected: Command exits 0; evidence shows Supabase/keystore guidance still exists and `git diff -- docs/architecture-audit.md` prints no diff.
    Evidence: .omo/evidence/task-4-readme-guardrails.txt
  ```

  Commit: YES | Message: `docs(readme): document update checks` | Files: [`README.md`]

- [ ] 5. Capture C001/C002 focused evidence

  What to do: Refresh C001 focused core evidence and capture C002 widget/UI evidence after Tasks 2 and 3 are complete. Write evidence to `.omo/ulw-loop/evidence/` and mirror a short receipt in `.omo/evidence/`. C001 already has earlier pass evidence, but rerun it after the UI work so the final proof is current.
  Must NOT do: Do not modify source code to make evidence pass. Do not edit `.omo/ulw-loop/goals.json` unless the executor's workflow explicitly requires updating captured evidence metadata.

  Parallelization: Can parallel: NO | Wave 3 | Blocks: [6] | Blocked by: [2, 3]

  References (executor has NO interview context - be exhaustive):
  - Pattern:  `.omo/ulw-loop/goals.json:17` - C001 exact scenario and evidence path.
  - Pattern:  `.omo/ulw-loop/goals.json:26` - C002 exact scenario and evidence path.
  - Test:     `test/app_version_test.dart:5` - Core version tests.
  - Test:     `test/app_update_service_test.dart:11` - Core release service tests.
  - Test:     `test/app_state_update_test.dart:13` - AppState update tests.
  - Test:     `test/settings_update_card_test.dart` - New settings widget tests from Task 2.
  - Test:     `test/app_shell_shortcuts_test.dart:219` - Existing shell widget test file that Task 3 extends.
  - External: `https://docs.flutter.dev/testing/overview` - Flutter test-type guidance.

  Acceptance criteria (agent-executable only):
  - [ ] `.omo/ulw-loop/evidence/pre02-core-tests.txt` exists and contains command, exit code 0, stdout tail, and cleanup receipt.
  - [ ] `.omo/ulw-loop/evidence/pre02-widget-tests.txt` exists and contains command, exit code 0, stdout tail, and cleanup receipt.
  - [ ] `flutter test test/app_version_test.dart test/app_update_service_test.dart test/app_state_update_test.dart` exits 0.
  - [ ] `flutter test test/settings_update_card_test.dart test/app_shell_shortcuts_test.dart` exits 0.

  QA scenarios (MANDATORY - task incomplete without these):
  > Name the exact tool AND its exact invocation - not "verify it works". Browser use: use Chrome to drive the page; if Chrome is not available, download and use agent-browser (https://github.com/vercel-labs/agent-browser). Computer use: OS-level GUI automation for a non-browser desktop app.
  ```
  Scenario: C001 core update tests pass
    Tool:     bash
    Steps:    mkdir -p .omo/ulw-loop/evidence .omo/evidence && powershell -NoProfile -Command "$cmd='flutter test test/app_version_test.dart test/app_update_service_test.dart test/app_state_update_test.dart'; 'COMMAND: '+$cmd | Tee-Object '.omo/ulw-loop/evidence/pre02-core-tests.txt'; Invoke-Expression $cmd *>&1 | Tee-Object -Append '.omo/ulw-loop/evidence/pre02-core-tests.txt'; 'EXIT_CODE: '+$LASTEXITCODE | Tee-Object -Append '.omo/ulw-loop/evidence/pre02-core-tests.txt'; 'CLEANUP: no spawned runtime state' | Tee-Object -Append '.omo/ulw-loop/evidence/pre02-core-tests.txt'; exit $LASTEXITCODE"
    Expected: Command exits 0 and evidence contains `EXIT_CODE: 0`.
    Evidence: .omo/ulw-loop/evidence/pre02-core-tests.txt

  Scenario: C002 widget update surface tests pass
    Tool:     bash
    Steps:    mkdir -p .omo/ulw-loop/evidence .omo/evidence && powershell -NoProfile -Command "$cmd='flutter test test/settings_update_card_test.dart test/app_shell_shortcuts_test.dart'; 'COMMAND: '+$cmd | Tee-Object '.omo/ulw-loop/evidence/pre02-widget-tests.txt'; Invoke-Expression $cmd *>&1 | Tee-Object -Append '.omo/ulw-loop/evidence/pre02-widget-tests.txt'; 'EXIT_CODE: '+$LASTEXITCODE | Tee-Object -Append '.omo/ulw-loop/evidence/pre02-widget-tests.txt'; 'CLEANUP: no spawned runtime state' | Tee-Object -Append '.omo/ulw-loop/evidence/pre02-widget-tests.txt'; exit $LASTEXITCODE"
    Expected: Command exits 0 and evidence contains `EXIT_CODE: 0`.
    Evidence: .omo/ulw-loop/evidence/pre02-widget-tests.txt
  ```

  Commit: NO | Message: `test(update): capture focused update evidence` | Files: [`.omo/ulw-loop/evidence/pre02-core-tests.txt`, `.omo/ulw-loop/evidence/pre02-widget-tests.txt`, `.omo/evidence/task-5-c001-c002.txt`]

- [ ] 6. Capture full C003 release-readiness evidence

  What to do: Run l10n generation, analysis, full tests, Windows release build attempt, Android APK release build attempt, and dirty-worktree/audit-file checks. Capture exact command, exit code, key output, build blocker classification if any, git status, and cleanup receipt in C003 evidence.
  Must NOT do: Do not hide or delete build failures. Do not modify keystore, Supabase secrets, build outputs, local databases, or `docs/architecture-audit.md`. Do not claim completion from build attempts if a failure is a Dart/source/test failure.

  Parallelization: Can parallel: NO | Wave 3 | Blocks: [final] | Blocked by: [2, 3, 4, 5]

  References (executor has NO interview context - be exhaustive):
  - Pattern:  `.omo/ulw-loop/goals.json:34` - C003 exact scenario and evidence path.
  - Pattern:  `README.md:108` - Existing release checklist commands.
  - Pattern:  `pubspec.yaml:4` - Current version is `0.2.0-pre+2`.
  - Pattern:  `pubspec.yaml:17` - New HTTP dependency exists for release checks.
  - Pattern:  `pubspec.yaml:19` - `package_info_plus` dependency exists for app version loading.
  - Pattern:  `pubspec.yaml:26` - `url_launcher` dependency exists for external release page opening.
  - Config:   `lib/core/app_config.dart:4` - `UPDATE_RELEASES_URL` compile-time config.
  - External: `https://docs.github.com/rest/releases/releases` - Release list API behavior.
  - External: `https://docs.github.com/rest/releases/assets` - Asset `browser_download_url` behavior.

  Acceptance criteria (agent-executable only):
  - [ ] `.omo/ulw-loop/evidence/pre02-release-readiness.txt` exists and includes command, exit code, and output excerpts for `flutter gen-l10n`, `flutter analyze`, `flutter test`, `flutter build windows --release`, `flutter build apk --release`, `git status --short`, and `git diff -- docs/architecture-audit.md`.
  - [ ] `flutter analyze` exits 0.
  - [ ] `flutter test` exits 0.
  - [ ] If either build command exits nonzero, evidence classifies it as an environment/toolchain blocker only if output clearly indicates missing Visual Studio, Android SDK, signing/toolchain, or device/build environment. Any Dart compile error, l10n error, test failure, or source error fails the task.
  - [ ] `git diff -- docs/architecture-audit.md` is empty.
  - [ ] `git status --short` still shows `docs/architecture-audit.md` only as untracked if it was already untracked; no plan task may stage or modify it.

  QA scenarios (MANDATORY - task incomplete without these):
  > Name the exact tool AND its exact invocation - not "verify it works". Browser use: use Chrome to drive the page; if Chrome is not available, download and use agent-browser (https://github.com/vercel-labs/agent-browser). Computer use: OS-level GUI automation for a non-browser desktop app.
  ```
  Scenario: release-readiness commands are attempted and captured
    Tool:     bash
    Steps:    mkdir -p .omo/ulw-loop/evidence .omo/evidence && powershell -NoProfile -Command "$out='.omo/ulw-loop/evidence/pre02-release-readiness.txt'; Remove-Item $out -ErrorAction SilentlyContinue; $commands=@('flutter gen-l10n','flutter analyze','flutter test','flutter build windows --release','flutter build apk --release','git status --short','git diff -- docs/architecture-audit.md'); foreach ($cmd in $commands) { 'COMMAND: '+$cmd | Tee-Object -Append $out; Invoke-Expression $cmd *>&1 | Tee-Object -Append $out; 'EXIT_CODE: '+$LASTEXITCODE | Tee-Object -Append $out; '---' | Tee-Object -Append $out }; 'CLEANUP: no app runtime, browser, tmux, or server sessions spawned' | Tee-Object -Append $out"
    Expected: Evidence file exists; analyze/test exit codes are 0; build exit codes are 0 or have explicit environment blocker notes added by the executor; audit diff section is empty.
    Evidence: .omo/ulw-loop/evidence/pre02-release-readiness.txt

  Scenario: audit file and dirty worktree guard remain visible
    Tool:     bash
    Steps:    mkdir -p .omo/evidence && { git status --short --branch; git diff -- docs/architecture-audit.md; git diff --name-only; } > .omo/evidence/task-6-dirty-worktree-guard.txt 2>&1
    Expected: Evidence shows branch `codex/pre-0.2`, no diff for `docs/architecture-audit.md`, and no unexpected product files outside this plan's file sets.
    Evidence: .omo/evidence/task-6-dirty-worktree-guard.txt
  ```

  Commit: NO | Message: `test(update): capture release readiness evidence` | Files: [`.omo/ulw-loop/evidence/pre02-release-readiness.txt`, `.omo/evidence/task-6-dirty-worktree-guard.txt`]

## Final verification wave (MANDATORY - after all implementation tasks)
> Runs in PARALLEL. ALL must APPROVE. Surface results to the caller and wait for an explicit "okay" before declaring complete.
- [ ] F1. Plan compliance audit - every task done, every acceptance criterion met; verify with `rg -n "\[ \]" .omo/plans/pre02-update-check-remaining.md` and direct evidence-file inspection.
- [ ] F2. Code quality review - diagnostics clean, idioms match, no dead code; verify `flutter analyze`, generated l10n diff, and no schema/Supabase coupling changes.
- [ ] F3. Real manual QA - every QA scenario executed with evidence captured; verify `.omo/evidence/task-*` and `.omo/ulw-loop/evidence/pre02-*.txt` exist and contain commands/exit codes.
- [ ] F4. Scope fidelity - nothing extra shipped beyond Must-Have, nothing Must-NOT-Have introduced; verify `git diff --name-only`, `git diff -- docs/architecture-audit.md`, and no edits to `lib/data/local_database.dart` or `supabase/schema.sql`.

## Commit strategy
- One logical change per commit. Conventional Commits (`<type>(<scope>): <subject>` body + footer).
- Atomic: every commit builds and passes tests on its own.
- No "WIP" / "fix typo squash later" commits on the final branch - clean up before merge.
- Reference the plan file path in the final commit footer: `Plan: .omo/plans/pre02-update-check-remaining.md`.

## Success criteria
- All Must-Have shipped; all QA scenarios pass with captured evidence; F1-F4 approved; commit history clean.
- C001, C002, and C003 evidence exists at the exact `.omo/ulw-loop/evidence/pre02-*.txt` paths.
- The update check remains explicit and local-first: no silent download/install, no Supabase requirement, no schema changes, and `docs/architecture-audit.md` untouched.
