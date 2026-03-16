import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mobile/src/state.dart';

void main() {
  group('friendlyErrorMessage', () {
    test('keeps invalid credentials ahead of generic client exception text', () {
      final message = friendlyErrorMessage(
        Exception(
          'ClientException: AuthApiException(message: Invalid login credentials, statusCode: 400, code: invalid_credentials)',
        ),
        baseUrl: 'https://example.supabase.co',
      );

      expect(message, 'Invalid email or password.');
    });

    test('maps transport failures to the reachability message', () {
      final message = friendlyErrorMessage(
        const SocketException('Failed host lookup'),
        baseUrl: 'https://example.supabase.co',
      );

      expect(
        message,
        'Unable to reach Supabase at https://example.supabase.co. Check your internet connection and Supabase project settings.',
      );
    });

    test('extracts wrapped auth messages', () {
      final message = friendlyErrorMessage(
        Exception(
          'AuthApiException(message: Email not confirmed, statusCode: 400, code: email_not_confirmed)',
        ),
        baseUrl: 'https://example.supabase.co',
      );

      expect(
        message,
        'Email not confirmed. Check your inbox, confirm the account, then sign in.',
      );
    });
  });
}
