class SupabaseConfigException implements Exception {
  const SupabaseConfigException(this.missingKeys);

  final List<String> missingKeys;

  String get message =>
      'Missing required Supabase configuration: ${missingKeys.join(', ')}. '
      'Provide them with --dart-define.';

  @override
  String toString() => message;
}

class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String mobileRedirectUrl = 'todoup://auth/callback';

  static String get baseUrlForMessages =>
      url.trim().isEmpty ? 'your configured Supabase project' : url;

  static void validate() {
    validateValues(url: url, anonKey: anonKey);
  }

  static void validateValues({required String url, required String anonKey}) {
    final missingKeys = <String>[
      if (url.trim().isEmpty) 'SUPABASE_URL',
      if (anonKey.trim().isEmpty) 'SUPABASE_ANON_KEY',
    ];

    if (missingKeys.isNotEmpty) {
      throw SupabaseConfigException(missingKeys);
    }
  }
}
