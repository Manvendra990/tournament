import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _tokenKey = 'api_token';
  static const _userKey = 'api_user';

  static String? _token;
  static Map<String, dynamic>? _user;

  static String? get token => _token;
  static Map<String, dynamic>? get currentUser => _user;
  static String? get currentUserId => _user?['id']?.toString();
  static String? get currentUserPhone => _user?['phone']?.toString();
  static String? get currentUserEmail => _user?['email']?.toString();
  static String? get currentUserName => _user?['name']?.toString();
  static String? get currentUsername => _user?['username']?.toString();
  static String? get currentUserPhoto => _user?['photoUrl']?.toString();
  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final raw = prefs.getString(_userKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _user = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        _user = null;
      }
    }
  }

  static Future<void> saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    _token = token;
    _user = Map<String, dynamic>.from(user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(_user));
  }

  static Future<void> updateUser(Map<String, dynamic> user) async {
    _user = Map<String, dynamic>.from(user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(_user));
  }

  static Future<void> clear() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    // Remove old Firebase-era session key as well.
    await prefs.remove('signed_in_uid');
  }
}
