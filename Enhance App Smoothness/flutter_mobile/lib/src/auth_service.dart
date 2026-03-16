import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final SupabaseClient _client = Supabase.instance.client;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _sessionKey = 'supabase.session';

  Session? _cachedSession;
  bool _initialized = false;
  bool _hasStoredSession = false;

  Session? get session => _client.auth.currentSession ?? _cachedSession;
  bool get isLoggedIn => session != null || _hasStoredSession;

  /// Must be called once after Supabase.initialize()
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final current = _client.auth.currentSession;
    if (current != null) {
      _cachedSession = current;
      _hasStoredSession = true;
      await _persistSession(current);
    } else {
      await _loadStoredSession();
    }

    _client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      switch (data.event) {
        case AuthChangeEvent.signedOut:
          _cachedSession = null;
          _hasStoredSession = false;
          await _storage.delete(key: _sessionKey);
          break;
        default:
          if (session != null) {
            _cachedSession = session;
            _hasStoredSession = true;
            await _persistSession(session);
          }
      }
    });

    _initialized = true;
  }

  Future<AuthActionResult> login(String email, String password) async {
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();

    try {
      final response = await _client.auth.signInWithPassword(
        email: trimmedEmail,
        password: trimmedPassword,
      );

      if (response.session != null) {
        _cachedSession = response.session;
        _hasStoredSession = true;
        await _persistSession(response.session!);
      }

      return AuthActionResult.success;
    } on AuthException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<void> logout() async {
    await _client.auth.signOut();
    _cachedSession = null;
    _hasStoredSession = false;
    await _storage.delete(key: _sessionKey);
  }

  /// Loads session from secure storage. When online, attempts recovery to
  /// refresh tokens; when offline, returns cached session for local-only mode.
  Future<bool> restoreSession({bool tryServerRecovery = false}) async {
    final current = _client.auth.currentSession;
    if (current != null) {
      _cachedSession = current;
      _hasStoredSession = true;
      await _persistSession(current);
      return true;
    }

    final loaded = await _loadStoredSession();
    if (!loaded) {
      return false;
    }

    if (tryServerRecovery && _cachedSession?.refreshToken?.isNotEmpty == true) {
      try {
        final response = await _client.auth
            .recoverSession(_cachedSession!.refreshToken!);
        if (response.session != null) {
          _cachedSession = response.session;
          _hasStoredSession = true;
          await _persistSession(response.session!);
        }
      } catch (_) {
        // If recovery fails (likely offline), stay in offline-auth mode.
      }
    }

    return _hasStoredSession;
  }

  Future<void> _persistSession(Session session) async {
    try {
      await _storage.write(
        key: _sessionKey,
        value: jsonEncode(session.toJson()),
      );
    } catch (_) {
      // Persistence best-effort; failure should not block auth.
    }
  }

  Future<bool> _loadStoredSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) {
      _hasStoredSession = false;
      return false;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _cachedSession = Session.fromJson(decoded);
      _hasStoredSession = true;
      return true;
    } catch (_) {
      await _storage.delete(key: _sessionKey);
      _hasStoredSession = false;
      return false;
    }
  }
}
