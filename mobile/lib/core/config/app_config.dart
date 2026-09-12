abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'RUNOVA_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const mapStyleUrl = String.fromEnvironment(
    'RUNOVA_MAP_STYLE_URL',
    defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
  );

  static const supabaseUrl = String.fromEnvironment('RUNOVA_SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'RUNOVA_SUPABASE_PUBLISHABLE_KEY',
  );
}
