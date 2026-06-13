import 'package:flutter/foundation.dart';

class AssistantConfigException implements Exception {
  const AssistantConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AssistantConfig {
  static const String baseUrl = String.fromEnvironment('ASSISTANT_API_URL');

  static bool get isEnabled => baseUrl.trim().isNotEmpty;

  static void validate() {
    validateBaseUrl(baseUrl, requireHttps: kReleaseMode);
  }

  static Uri validateBaseUrl(String value, {required bool requireHttps}) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw const AssistantConfigException(
        'ASSISTANT_API_URL is not configured.',
      );
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      throw const AssistantConfigException(
        'ASSISTANT_API_URL must be a valid absolute URL.',
      );
    }

    if (requireHttps && uri.scheme != 'https') {
      throw const AssistantConfigException(
        'ASSISTANT_API_URL must use HTTPS in release builds.',
      );
    }

    return uri;
  }

  static Uri get draftUri {
    final uri = validateBaseUrl(baseUrl, requireHttps: kReleaseMode);
    final normalized = uri.toString();
    final prefix = normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    return Uri.parse('$prefix/assistant/draft');
  }
}
