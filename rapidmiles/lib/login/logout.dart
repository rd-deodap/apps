import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rapidmiles/login/login_screen.dart';

Future<void> performLogout(BuildContext context) async {
  final sp = await SharedPreferences.getInstance();
  final token = sp.getString(SessionKeys.token) ?? "";

  // Call logout API (best-effort — clear session regardless)
  if (token.isNotEmpty) {
    try {
      await http.get(
        Uri.parse("https://rapidmiles.in/api/logout"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );
    } catch (_) {
      // Ignore network errors — still clear local session
    }
  }

  // Clear local session
  await sp.remove(SessionKeys.token);
  await sp.remove(SessionKeys.name);
  await sp.remove(SessionKeys.userId);
  await sp.remove(SessionKeys.email);
  await sp.setBool(SessionKeys.isLoggedIn, false);

  if (!context.mounted) return;

  // Navigate to login and clear the navigation stack
  Navigator.of(context).pushAndRemoveUntil(
    CupertinoPageRoute(builder: (_) => const LoginPage()),
    (_) => false,
  );
}

Future<void> showLogoutConfirmation(BuildContext context) async {
  await showCupertinoDialog<void>(
    context: context,
    builder: (_) => CupertinoAlertDialog(
      title: const Text("Logout"),
      content: const Text("Are you sure you want to logout?"),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.pop(context);
            performLogout(context);
          },
          child: const Text("Logout"),
        ),
      ],
    ),
  );
}
