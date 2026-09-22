# TimeWise — Smart Time Management System with AI

TimeWise helps you plan a realistic day by combining tasks, deadlines,
fixed commitments (classes, work, appointments, travel) and an AI
schedule assistant that fits everything into your free time.

## Features

- **Tasks** — title, description, deadline, priority, category, estimated
  duration, optional reminder; filtered into Upcoming / Overdue / Completed.
- **Schedule** — add fixed events (class, work, appointment, travel,
  personal) that the AI will never overwrite; conflicts are rejected with a
  clear message.
- **AI Schedule Assistant** — generates a plan around your fixed events,
  sleep schedule and pending tasks. Review, edit, regenerate, or reject the
  suggestion before it's saved.
- **Dashboard** — today's stats, upcoming deadlines and what's next.
- Firebase Auth (email/password + Google), per-user Firestore data with
  security rules enforcing that isolation server-side.

## Setup

```bash
flutter pub get
```

### AI Schedule Assistant (Gemini API key)

The Gemini API key is **not** stored in source. Provide it at build/run
time so it never gets committed to version control:

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

For release builds:

```bash
flutter build apk --dart-define=GEMINI_API_KEY=your_key_here
```

Without a key, every other feature works normally — the AI Schedule
Assistant simply shows a message explaining how to enable it instead of
crashing.

> For a production deployment, consider moving the Gemini call behind a
> small server-side proxy (e.g. a Cloud Function) instead of shipping the
> key inside the compiled app, since any key bundled into a mobile binary
> can eventually be extracted by a determined user.

### Firebase

Firestore and Storage security rules live in `firestore.rules` and
`storage.rules` and are deployed with:

```bash
firebase deploy --only firestore:rules,storage:rules
```

## Development

```bash
flutter analyze
flutter test
```
