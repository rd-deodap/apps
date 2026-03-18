// lib/login/login_screen.dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rapidmiles/home/home_screen.dart';

class ApiConfig {
  static const String loginUrl = "https://rapidmiles.in/api/login";
}

class SessionKeys {
  static const String isLoggedIn = "isLoggedIn";
  static const String token = "token";
  static const String userId = "user_id";
  static const String name = "name";
  static const String email = "email";

  // ✅ permissions
  static const String permissionsJson = "permissions_json"; // store list as json string
  static const String hasRtoDelivered = "has_rto_delivered"; // store bool
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // -------------------- form --------------------
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _loading = false;
  String? _error;
  bool _showPass = false;

  // -------------------- theme (white + creme only) --------------------
  static const Color _creamBg = Color(0xFFFFFBF2);
  static const Color _surface = Colors.white;
  static const Color _stroke = Color(0xFFEFE7D6);

  static const Color _text = Color(0xFF2B2B2B);
  static const Color _muted = Color(0xFF6B7280);

  static const Color _warm = Color(0xFFFFE7C2);
  static const Color _warm2 = Color(0xFFFFF1D8);

  static const Color _primary = Color(0xFFB45309);
  static const Color _primarySoft = Color(0xFFFFF3DC);

  @override
  void initState() {
    super.initState();

    // ✅ Do not prefill login fields
    _emailCtrl.text = "";
    _passCtrl.text = "";
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  // -------------------- api --------------------
  Future<Map<String, dynamic>> _postForm(
      String url,
      Map<String, String> body,
      ) async {
    final res = await http.post(
      Uri.parse(url),
      headers: const {"Content-Type": "application/x-www-form-urlencoded"},
      body: body,
    );

    try {
      final decoded = json.decode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {"success": false, "message": "Invalid JSON response"};
    } catch (_) {
      return {"success": false, "message": "Invalid JSON response"};
    }
  }

  Future<void> _forgotPasswordDialog() async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (_) => const CupertinoAlertDialog(
        title: Text("Forgot Password"),
        content: Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            "For security, password reset is managed by the Admin/HR.\n\n"
                "Please contact Admin/HR to reset your password.",
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  List<String> _parsePermissions(dynamic raw) {
    // Accepts: List, null, weird types
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return <String>[];
  }

  Future<void> _doLogin() async {
    FocusScope.of(context).unfocus();
    if (_loading) return;

    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;

      final jsonRes = await _postForm(ApiConfig.loginUrl, {
        "email": email,
        "password": password,
      });

      // Your API uses "success"
      if (jsonRes["success"] != true) {
        setState(() => _error = (jsonRes["message"] ?? "Login failed").toString());
        return;
      }

      final data = (jsonRes["data"] as Map?)?.cast<String, dynamic>();
      if (data == null) {
        setState(() => _error = "Invalid response: missing data");
        return;
      }

      final token = (data["token"] ?? "").toString();
      if (token.isEmpty) {
        setState(() => _error = "Invalid response: missing token");
        return;
      }

      final user = (data["user"] as Map?)?.cast<String, dynamic>();
      final name = (user?["name"] ?? "").toString();
      final userId = (user?["id"] ?? "").toString();
      final userEmail = (user?["email"] ?? email).toString();

      // ✅ permissions are inside data.permissions
      final permissions = _parsePermissions(data["permissions"]);
      final hasRtoDelivered = permissions.contains("rto-delivered");

      final sp = await SharedPreferences.getInstance();
      await sp.setString(SessionKeys.token, token);
      await sp.setString(SessionKeys.name, name);
      await sp.setString(SessionKeys.userId, userId);
      await sp.setString(SessionKeys.email, userEmail);
      await sp.setBool(SessionKeys.isLoggedIn, true);

      // ✅ save permissions
      await sp.setString(SessionKeys.permissionsJson, jsonEncode(permissions));
      await sp.setBool(SessionKeys.hasRtoDelivered, hasRtoDelivered);

      if (!mounted) return;

      // If you want: block user if no permission (optional)
      // if (!hasRtoDelivered) {
      //   setState(() => _error = "You don't have permission for RTO Delivered.");
      //   return;
      // }

      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      setState(() => _error = "Something went wrong: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // -------------------- ui helpers --------------------
  InputDecoration _dec(
      String label, {
        String? hint,
        Widget? prefixIcon,
        Widget? suffixIcon,
      }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _surface,
      labelStyle: const TextStyle(
        color: _muted,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: TextStyle(
        color: _muted.withOpacity(0.7),
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _stroke, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _primary.withOpacity(0.45), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _loadingSpinner() => const CupertinoActivityIndicator();

  Widget _errorBox() {
    final err = _error;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: (err == null)
          ? const SizedBox.shrink()
          : Container(
        key: const ValueKey("error"),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.65)),
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFFFEF2F2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                color: Color(0xFFEF4444), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                err,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brandHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _surface.withOpacity(0.95),
            _warm2.withOpacity(0.75),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.05)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _warm,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _stroke),
            ),
            alignment: Alignment.center,
            child: const Icon(CupertinoIcons.cube_box_fill, color: _text, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "RapidMiles",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: _text,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Secure sign-in for DeoDap International Pvt Ltd",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loginCard(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _stroke),
        color: _surface.withOpacity(0.98),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Login",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _text,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Enter your email and password to continue.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _muted,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 14),

            // Email
            TextFormField(
              controller: _emailCtrl,
              focusNode: _emailFocus,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [],
              enableSuggestions: false,
              autocorrect: false,
              decoration: _dec(
                "Email",
                hint: "e.g. user@example.com",
                prefixIcon: const Icon(CupertinoIcons.mail, color: _muted),
              ),
              validator: (v) {
                final s = (v ?? "").trim();
                if (s.isEmpty) return "Email is required";
                if (!s.contains("@") || !s.contains(".")) return "Enter a valid email address";
                return null;
              },
              onFieldSubmitted: (_) => _passFocus.requestFocus(),
            ),
            const SizedBox(height: 12),

            // Password
            TextFormField(
              controller: _passCtrl,
              focusNode: _passFocus,
              obscureText: !_showPass,
              textInputAction: TextInputAction.done,
              autofillHints: const [],
              enableSuggestions: false,
              autocorrect: false,
              decoration: _dec(
                "Password",
                hint: "Enter password",
                prefixIcon: const Icon(CupertinoIcons.lock, color: _muted),
                suffixIcon: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _loading ? null : () => setState(() => _showPass = !_showPass),
                  child: Icon(
                    _showPass ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                    color: _muted,
                    size: 20,
                  ),
                ),
              ),
              validator: (v) => (v ?? "").isEmpty ? "Password is required" : null,
              onFieldSubmitted: (_) => _loading ? null : _doLogin(),
            ),

            const SizedBox(height: 14),
            _errorBox(),
            const SizedBox(height: 14),

            SizedBox(
              height: 50,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                color: _primary,
                borderRadius: BorderRadius.circular(16),
                onPressed: _loading ? null : _doLogin,
                child: _loading
                    ? _loadingSpinner()
                    : const Text(
                  "Login",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _loading ? null : _forgotPasswordDialog,
              child: const Text(
                "Forgot Password?",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _text,
                  decoration: TextDecoration.none,
                ),
              ),
            ),

            const SizedBox(height: 6),
            Text(
              "By continuing, you agree to company security policies.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _muted.withOpacity(0.85),
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 14),
      child: Text(
        "Secure by DeoDap International Pvt Ltd",
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: _muted.withOpacity(0.75),
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _pageBody(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Column(
        children: [
          _brandHeader(context),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _loginCard(context),
                          _footer(context),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: _creamBg,
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle.merge(
          style: const TextStyle(decoration: TextDecoration.none),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: _pageBody(context),
          ),
        ),
      ),
    );
  }
}