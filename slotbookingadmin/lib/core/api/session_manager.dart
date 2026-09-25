import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  SessionManager._();

  static String? _cachedToken;
  static String? _cachedRole;
  static Map<String, dynamic>? _cachedUser;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    _cachedRole = prefs.getString(_roleKey);
    final raw = prefs.getString(_userKey);
    if (raw != null && raw.isNotEmpty) {
      try { _cachedUser = Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) { _cachedUser = null; }
    }
  }

  static String? get currentToken => _cachedToken;
  static String? get currentRole => _cachedRole;
  static Map<String, dynamic>? get currentUser => _cachedUser;
  static String get currentUserId => (_cachedUser?['id'] ?? _cachedUser?['_id'] ?? '').toString();
  static const _tokenKey = 'api_token';
  static const _userKey = 'api_user';
  static const _roleKey = 'api_role';

  static Future<void> saveSession({
    required String token,
    required Map<String, dynamic> user,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
    await prefs.setString(_roleKey, role);
    await prefs.setBool('keep_logged_in', true);
    _cachedToken = token;
    _cachedUser = Map<String, dynamic>.from(user);
    _cachedRole = role;
  }

  static Future<String?> token() async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);

  static Future<String?> role() async =>
      (await SharedPreferences.getInstance()).getString(_roleKey);

  static Future<Map<String, dynamic>?> user() async {
    final raw = (await SharedPreferences.getInstance()).getString(_userKey);
    if (raw == null || raw.isEmpty) return null;
    try { return Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) { return null; }
  }

  static Future<String?> userId() async => (await user())?['id']?.toString();

  static Future<bool> hasSession() async {
    final value = await token();
    return value != null && value.isNotEmpty;
  }

  static Future<void> updateUser(Map<String, dynamic> user) async {
    _cachedUser = Map<String, dynamic>.from(user);
    if (user['role'] != null) _cachedRole = user['role'].toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
    if (user['role'] != null) await prefs.setString(_roleKey, user['role'].toString());
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_roleKey);
    await prefs.remove('keep_logged_in');
    _cachedToken = null;
    _cachedUser = null;
    _cachedRole = null;
  }
}
