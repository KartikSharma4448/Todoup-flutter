# ToDoUp Backend

This local backend can draft assistant task previews with OpenRouter.

App-facing draft endpoint:

- `POST /assistant/draft`

## Run

```powershell
$env:OPENROUTER_API_KEY="your-openrouter-key"
$env:OPENROUTER_MODEL="openrouter/auto"
$env:SUPABASE_JWT_SECRET="your-supabase-jwt-secret"
dart run bin/server.dart
```

Optional environment variables:

- `OPENROUTER_HTTP_REFERER`
- `OPENROUTER_APP_TITLE`
- `SUPABASE_JWT_SECRET`
- `SUPABASE_JWT_AUD`
- `ASSISTANT_RATE_LIMIT_WINDOW_SECONDS`
- `ASSISTANT_RATE_LIMIT_MAX_REQUESTS`
- `PORT`

If `OPENROUTER_API_KEY` is missing, the backend falls back to the built-in heuristic assistant response instead of failing.

## Production notes

- Host this backend behind HTTPS before using it from release mobile builds.
- Release app builds reject non-HTTPS `ASSISTANT_API_URL` values.
- Set `SUPABASE_JWT_SECRET` so only signed-in app users can access `POST /assistant/draft`.
- Keep rate limiting enabled and place the backend behind gateway protection before public launch.
