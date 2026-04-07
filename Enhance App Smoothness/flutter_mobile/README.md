# TodoUp Flutter App

TodoUp is a Flutter productivity app with Supabase-backed auth, task sync, reminders, and assistant-ready flows.

## Production-focused capabilities

- Supabase auth + profile/task sync
- Guarded bootstrap with auth-state aware routing
- Pull-to-refresh, inline sync feedback, and swipe-to-delete UX
- Local reminder notifications (one-time and recurring)
- Optional hosted assistant backend integration
- Home widget sync and daily task focus support

## Tech stack

- Flutter 3.8+ / Dart 3.8+
- supabase_flutter
- flutter_local_notifications
- home_widget
- flutter_secure_storage

## Local development

```powershell
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key --dart-define=ASSISTANT_API_URL=https://your-ai-backend.example.com
```

If `ASSISTANT_API_URL` is omitted, the app can fallback to local heuristic behavior.

## Release builds

```powershell
flutter build apk --release --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key --dart-define=ASSISTANT_API_URL=https://your-ai-backend.example.com
flutter build appbundle --release --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key --dart-define=ASSISTANT_API_URL=https://your-ai-backend.example.com
```

## Required configuration

- Run `supabase_bootstrap.sql` in your Supabase project
- Configure auth redirect URLs (including deep links)
- Pass all required `dart-define` values at build/run time

## CI and release workflow

The project supports CI checks for format, analyze, tests, and release artifacts. Configure secure secrets in your CI provider before shipping.

## License

See [../../LICENSE](../../LICENSE).