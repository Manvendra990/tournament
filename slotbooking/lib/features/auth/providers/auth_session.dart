import 'package:google_sign_in/google_sign_in.dart';
import 'package:slotbooking/core/api/session_manager.dart';

class AuthSession {
  static Future<String?> getSavedUid() async {
    if (!SessionManager.isLoggedIn) await SessionManager.init();
    return SessionManager.currentUserId;
  }

  static Future<void> saveUid(String uid) async {
    // Kept only for source compatibility. API sessions are stored centrally.
  }

  static Future<void> clearUid() => SessionManager.clear();

  static Future<bool> restore() async {
    await SessionManager.init();
    return SessionManager.isLoggedIn;
  }

  static Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await SessionManager.clear();
  }
}
