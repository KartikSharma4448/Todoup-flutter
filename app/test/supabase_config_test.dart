import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/src/supabase_config.dart';

void main() {
  group('SupabaseConfig', () {
    test('validateValues throws for missing dart-defines', () {
      expect(
        () => SupabaseConfig.validateValues(url: '', anonKey: '  '),
        throwsA(
          isA<SupabaseConfigException>().having(
            (error) => error.missingKeys,
            'missingKeys',
            ['SUPABASE_URL', 'SUPABASE_ANON_KEY'],
          ),
        ),
      );
    });

    test('validateValues accepts provided values', () {
      expect(
        () => SupabaseConfig.validateValues(
          url: 'https://example.supabase.co',
          anonKey: 'anon-key',
        ),
        returnsNormally,
      );
    });
  });
}
