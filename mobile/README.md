# Runova Android

Flutter client for Runova's free Android MVP.

## Configuration

Values are injected at build time rather than stored in source control:

```powershell
flutter run `
  --dart-define=RUNOVA_API_BASE_URL=http://10.0.2.2:8000 `
  --dart-define=RUNOVA_MAP_STYLE_URL=https://demotiles.maplibre.org/style.json `
  --dart-define=RUNOVA_SUPABASE_URL=your-project-url `
  --dart-define=RUNOVA_SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

The Android emulator reaches the host through `10.0.2.2`. A physical phone
must use the development computer's LAN address.

The current shell includes dashboard, run, territory map, leaderboard, history,
and profile routes. Real foreground GPS recording and offline persistence are
the next vertical implementation milestone.

