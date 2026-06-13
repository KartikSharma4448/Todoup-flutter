import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/src/assistant_config.dart';

void main() {
  group('AssistantConfig', () {
    test('is disabled when no backend URL is provided', () {
      expect(AssistantConfig.baseUrl, isEmpty);
      expect(AssistantConfig.isEnabled, isFalse);
    });

    test('draftUri joins the configured endpoint path', () {
      expect(
        () => AssistantConfig.draftUri,
        throwsA(isA<AssistantConfigException>()),
      );
    });

    test('validateBaseUrl accepts a secure hosted endpoint', () {
      final uri = AssistantConfig.validateBaseUrl(
        'https://assistant.todoup.app',
        requireHttps: true,
      );

      expect(uri.toString(), 'https://assistant.todoup.app');
    });

    test('validateBaseUrl rejects non-https release endpoints', () {
      expect(
        () => AssistantConfig.validateBaseUrl(
          'http://assistant.todoup.app',
          requireHttps: true,
        ),
        throwsA(isA<AssistantConfigException>()),
      );
    });
  });
}
