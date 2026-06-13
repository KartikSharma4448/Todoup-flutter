# ToDoUp Production Launch Pack

Last updated: March 7, 2026

## 1. Release build and signing

### Android

- Signing scaffold is configured in [`android/app/build.gradle.kts`](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/flutter_mobile/android/app/build.gradle.kts)
- Example signing file: [`android/key.properties.example`](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/flutter_mobile/android/key.properties.example)
- Secret files are ignored in [`.gitignore`](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/flutter_mobile/.gitignore)
- Android release builds now fail fast if upload signing is missing, instead of silently falling back to the debug key

Required values for a signed Android release:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

### iOS

- Bundle display metadata is configured in [`ios/Runner/Info.plist`](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/flutter_mobile/ios/Runner/Info.plist)
- Production bundle identifier is `app.todoup` in [`ios/Runner.xcodeproj/project.pbxproj`](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/flutter_mobile/ios/Runner.xcodeproj/project.pbxproj)
- Apple signing, certificates, and provisioning profiles must still be completed in Xcode and App Store Connect

## 5. Legal and support

- In-app support screen is available from Settings
- In-app privacy policy is available from Settings
- In-app terms of service are available from Settings
- Open source licenses are available from Settings

Source files:

- [`lib/src/legal_support_screens.dart`](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/flutter_mobile/lib/src/legal_support_screens.dart)
- [`docs/privacy_policy.md`](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/flutter_mobile/docs/privacy_policy.md)
- [`docs/terms_of_service.md`](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/flutter_mobile/docs/terms_of_service.md)

## 6. QA status

Verified on March 6, 2026:

- `flutter analyze`
- `flutter test`
- `flutter build web --release`
- `flutter build apk --release` with signing configured
- `flutter build appbundle --release` with signing configured

Still manual before store submission:

- Physical Android device smoke test
- iPhone smoke test on macOS/Xcode
- Email confirmation deep-link test
- Slow-network retry test
- Delete-account end-to-end test against production project
- Hosted AI backend HTTPS, rate limiting, and abuse protection review

## 7. Store readiness

Template file:

- [`docs/store_listing_template.md`](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/flutter_mobile/docs/store_listing_template.md)

Still required outside the repo:

- Final screenshots
- Feature graphic
- Store descriptions and keywords
- Category/rating selections
- Privacy disclosures in store consoles

## 8. Security review

Completed in repo:

- No Postgres connection string or service-role key stored in app source
- Android signing files and keystores ignored from version control
- Release builds use GitHub secrets in CI
- Supabase access from the client uses anon key only

Recommended recurring checks:

- Rotate database password and any previously shared credentials
- Re-run repo secret scan before every release
- Review Supabase RLS policies before enabling business/team features
- Keep release builds tied to production-only `dart-define` values

## 9. CI/CD release flow

Workflow:

- [`../.github/workflows/ci-cd.yml`](/c:/Users/Tanu%20Raj/Downloads/Enhance%20App%20Smoothness/.github/workflows/ci-cd.yml)

The workflow now:

- runs formatting, analyze, tests
- scans for forbidden secret patterns
- builds web release artifacts
- builds signed Android `apk` and `aab` when release secrets are configured
- publishes release artifacts in GitHub Actions

## 10. Final go-live checklist

- Confirm `SUPABASE_URL` and `SUPABASE_ANON_KEY` production values
- Confirm hosted `ASSISTANT_API_URL` is reachable over HTTPS if AI drafting is enabled
- Confirm `todoup://auth/callback` is registered in Supabase Auth redirect URLs
- Confirm iOS signing uses bundle ID `app.todoup`
- Confirm any iOS widget/app-group entitlements use `group.app.todoup` before enabling the iOS widget target
- Confirm support mailbox ownership and response process
- Confirm privacy policy and terms text are final
- Confirm Android signing secrets are loaded in GitHub Actions
- Confirm store listing metadata and screenshots are final
- Confirm release artifacts build cleanly from `main`
- Confirm production auth, task sync, export data, and delete-account flows
