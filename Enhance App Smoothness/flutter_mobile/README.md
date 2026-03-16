# ToDoUp Flutter App

ToDoUp is a Flutter client backed directly by Supabase Auth and Postgres.

## Production hardening included

- Supabase-backed auth, profile sync, tasks, and assistant history
- Session-aware app bootstrap with auth-state listener and guarded navigation
- Pull-to-refresh, inline sync feedback, empty-state UX, and swipe-to-delete on tasks
- Local reminder notifications with one-time and recurring schedules
- Optional hosted AI assistant backend for model-based task drafting with confirmation
- Smart home-screen widget sync with daily score and today task focus
- GitHub Actions workflow for formatting, analysis, tests, web builds, and Android builds
- `dart-define` support for release-time Supabase secrets

## Local development

From [`flutter_mobile`](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/flutter_mobile):

```powershell
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key --dart-define=ASSISTANT_API_URL=https://your-ai-backend.example.com
```

Android release artifacts:

```powershell
flutter build apk --release --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key --dart-define=ASSISTANT_API_URL=https://your-ai-backend.example.com
flutter build appbundle --release --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key --dart-define=ASSISTANT_API_URL=https://your-ai-backend.example.com
```

Supabase config is required at launch time. If those values are missing, the app shows an in-app bootstrap error screen with the exact `dart-define` names that must be supplied.

If `ASSISTANT_API_URL` is configured, the AI assistant requests a task draft from your hosted backend and still requires explicit user confirmation before a task is added. Without it, the app falls back to the built-in heuristic draft.
Release builds only accept `https://` assistant endpoints.

## Supabase requirements

- Apply [`supabase_bootstrap.sql`](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/flutter_mobile/supabase_bootstrap.sql) to the target project
- Configure email templates and redirect URLs in Supabase Auth
- Add `todoup://auth/callback` to Supabase Auth redirect URLs for Android/iOS email confirmation
- If email confirmation is enabled, users must confirm their email before first sign-in
- iOS production bundle identifier is `app.todoup`

## CI and release

GitHub Actions workflow: [ci-cd.yml](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/.github/workflows/ci-cd.yml)

Required GitHub secrets for release builds:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `ASSISTANT_API_URL` (recommended when shipping hosted AI drafting)
- `ASSISTANT_API_URL` must use `https://` for release builds
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The workflow runs:

- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`
- `flutter build web --release`
- `flutter build apk --release`
- `flutter build appbundle --release`

Launch docs:

- [`docs/production_launch_pack.md`](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/flutter_mobile/docs/production_launch_pack.md)
- [`docs/store_listing_template.md`](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/flutter_mobile/docs/store_listing_template.md)
- [`docs/privacy_policy.md`](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/flutter_mobile/docs/privacy_policy.md)
- [`docs/terms_of_service.md`](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/flutter_mobile/docs/terms_of_service.md)

## Still outside the repo

These are necessary before a true public production launch:

- Android/iOS signing and store submission assets
- Crash reporting and product analytics
- Secret rotation, staging/prod environment separation, and backup policy
- Supabase console deep-link registration for email confirmation flows
- iOS WidgetKit extension signing and Xcode verification on macOS
