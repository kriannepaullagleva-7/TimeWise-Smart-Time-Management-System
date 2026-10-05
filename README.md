# TimeWise — Smart Time Management with AI

TimeWise is an Android-first Flutter app that helps students plan a realistic
day. It combines tasks and deadlines, fixed commitments (classes, work,
appointments), a calendar, focus sessions and an AI schedule planner that fits
pending tasks into the free time around the fixed events and sleep hours.

## Features

| Area | What it does |
| --- | --- |
| Onboarding | Welcome screen and a five-question quiz (purpose, schedule style, wake/sleep hours, AI help). Answers become planning hints. |
| Accounts | Email + password, Google sign-in, guest mode (upgradeable to an email account), password-reset email. |
| Dashboard | Today's progress, streak, AI planner entry, free-time bar, today's schedule, most urgent tasks. |
| Tasks | Title, description, deadline, priority, category, estimated time, reminder, subtasks, repeat rules. Search and filter. |
| Calendar | Week/month view with markers, events (fixed or flexible), overlap detection, repeat rules, tasks due that day. |
| AI Schedule | Gemini builds a plan for a day; the user reviews, edits times, removes blocks, regenerates or accepts. |
| Focus mode | Timestamp-based countdown that survives leaving the screen and restarting the app; writes focus time to the task. |
| Profile | Stats, reminders and AI switches, sleep schedule, categories, appearance (light/dark/system and accent colour), log out. |

## Running it

```bash
flutter pub get
copy dart_defines.example.json dart_defines.json   # then paste your Gemini key
flutter run --dart-define-from-file=dart_defines.json
```

In VS Code choose **TimeWise (debug)** from Run and Debug; `.vscode/launch.json`
already passes `--dart-define-from-file=dart_defines.json`.

`dart_defines.json` is git-ignored. Without a key every feature except the AI
planner works, and the planner explains what is missing instead of failing.

> The Gemini key is compiled into the app. That is acceptable for a coursework
> demo but not for a public release: put the call behind a server-side proxy
> (for example a Cloud Function) so the key never ships in the binary.

### Firebase

The app uses the Firebase project in `lib/firebase_options.dart` and
`android/app/google-services.json`. Email/password, Google and Anonymous
sign-in must be enabled in the console, and the debug SHA-1 must be registered
for Google sign-in on Android.

Rules and indexes live in `firestore.rules`, `storage.rules` and
`firestore.indexes.json`:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

To develop against a throw-away local backend instead of the real project:

```bash
firebase emulators:start --only auth,firestore,storage
adb reverse tcp:8080 tcp:8080 && adb reverse tcp:9099 tcp:9099 && adb reverse tcp:9199 tcp:9199
flutter run --dart-define-from-file=dart_defines.json --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=localhost
```

## Project layout

```
lib/
  models/        Task, ScheduleItem, UserModel, RecurrenceRule
  repositories/  Firestore access behind interfaces (fakes are used in tests)
  providers/     Auth, Task (one shared live query), Schedule, Focus, Theme, Preferences
  services/      Auth, Gemini (AIService), local notifications, onboarding store
  screens/       One folder per area (auth, onboarding, tasks, schedule, ...)
  widgets/       Shared UI kit (ui.dart), TaskCard, ScheduleItemCard, EmptyState, ...
  theme/         Colours, text styles, Material 3 theme
test/            Unit and widget tests
```

## Development

```bash
flutter analyze
flutter test
```

The release build is signed with the debug key so `flutter run --release`
works; create a real keystore before publishing.
