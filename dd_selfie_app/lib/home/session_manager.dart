// lib/session/session_manager.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionKeys {
  static const String isLoggedIn = "isLoggedIn";
  static const String token = "token";

  // Shortcuts
  static const String userId = "user_id";
  static const String empCode = "emp_code";
  static const String userName = "name";
  static const String phone = "phone";

  // ✅ Full payload (entire login response)
  static const String loginPayload = "login_payload_json";
}

class SessionManager {
  static Future<void> saveLoginPayload(Map<String, dynamic> payload) async {
    final sp = await SharedPreferences.getInstance();

    final token = (payload["token"] ?? "").toString();
    final user = (payload["user"] is Map) ? payload["user"] as Map : <String, dynamic>{};

    final userId = (user["id"] ?? "").toString();
    final name = (user["name"] ?? "").toString();
    final empCode = (user["code"] ?? "").toString();
    final phone = (user["phone"] ?? "").toString();

    await sp.setBool(SessionKeys.isLoggedIn, true);
    await sp.setString(SessionKeys.token, token);

    // shortcuts
    await sp.setString(SessionKeys.userId, userId);
    await sp.setString(SessionKeys.userName, name);
    await sp.setString(SessionKeys.empCode, empCode);
    await sp.setString(SessionKeys.phone, phone);

    // ✅ store full JSON (so you can access roles, pivot, everything)
    await sp.setString(SessionKeys.loginPayload, jsonEncode(payload));
  }

  static Future<Map<String, dynamic>?> getLoginPayload() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(SessionKeys.loginPayload);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<String> getToken() async {
    final sp = await SharedPreferences.getInstance();
    return (sp.getString(SessionKeys.token) ?? "").trim();
  }

  static Future<bool> isLoggedIn() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(SessionKeys.isLoggedIn) ?? false;
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.clear();
  }
}