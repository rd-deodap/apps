import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType, Theme, TextFormField, InputDecoration, OutlineInputBorder, BorderSide, Border, BoxConstraints, BoxDecoration, BoxShadow, Offset;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:dd_selfie_app/home/home_screen.dart';
import 'package:dd_selfie_app/home/session_manager.dart';

class ApiConfig {
  static const String loginUrl = "https://staff.deodap.in/api/admin/login";
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _empCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  final _empFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _loading = false;
  String? _error;
  bool _showPass = false;

  static final RegExp _empAllowed = RegExp(r"^[A-Za-z0-9_-]+$");

  // White + soft cream theme
  static const _creamBg = Color(0xFFFFF8E6);
  static const _cardBorder = Color(0x1A000000);

  @override
  void dispose() {
    _empCtrl.dispose();
    _passCtrl.dispose();
    _empFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Map<String, dynamic> _decodeJsonObject(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return const {"status": false, "message": "Invalid JSON response"};
    } catch (_) {
      return const {"status": false, "message": "Invalid JSON response"};
    }
  }

  Future<Map<String, dynamic>> _postLogin(String url, Map<String, String> body) async {
    final uri = Uri.parse(url);
    final jsonRes = await http.post(
      uri,
      headers: const {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    final firstPayload = _decodeJsonObject(jsonRes.body);
    if (jsonRes.statusCode >= 200 && jsonRes.statusCode < 300) {
      return firstPayload;
    }

    // Some backends still expect form-urlencoded; retry once before failing.
    if (jsonRes.statusCode == 400 ||
        jsonRes.statusCode == 401 ||
        jsonRes.statusCode == 415 ||
        jsonRes.statusCode == 422) {
      final formRes = await http.post(
        uri,
        headers: const {
          "Accept": "application/json",
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: body,
      );
      final formPayload = _decodeJsonObject(formRes.body);
      if (formRes.statusCode >= 200 && formRes.statusCode < 300) {
        return formPayload;
      }
      return {
        "status": false,
        "message":
            (formPayload["message"] ?? firstPayload["message"] ?? "HTTP ${formRes.statusCode}")
                .toString(),
      };
    }

    return {
      "status": false,
      "message": (firstPayload["message"] ?? "HTTP ${jsonRes.statusCode}").toString(),
    };
  }

  Future<void> _doLogin() async {
    FocusScope.of(context).unfocus();
    if (_loading) return;

    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final loginCode = _empCtrl.text.trim();
      final password = _passCtrl.text;

      // ✅ YOUR API expects: login_code + password
      final jsonRes = await _postLogin(ApiConfig.loginUrl, {
        "login_code": loginCode,
        "password": password,
      });

      final ok = jsonRes["status"] == true;
      if (!ok) {
        setState(() => _error = (jsonRes["message"] ?? "Login failed").toString());
        return;
      }

      // ✅ Validate required fields
      final token = (jsonRes["token"] ?? "").toString();
      final user = jsonRes["user"];

      if (token.isEmpty || user == null) {
        setState(() => _error = "Invalid response: missing token/user");
        return;
      }

      // ✅ SAVE FULL PAYLOAD (ALL DETAILS)
      await SessionManager.saveLoginPayload(jsonRes);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (_) => const AppShell()),
      );
    } catch (e) {
      setState(() => _error = "Something went wrong: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.35), width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _loadingSpinner() => const CupertinoActivityIndicator();

  Widget _errorBox() {
    final err = _error;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: (err == null)
          ? const SizedBox.shrink()
          : Container(
        key: const ValueKey("error"),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.redAccent.withOpacity(0.9)),
          borderRadius: BorderRadius.circular(12),
          color: Colors.redAccent.withOpacity(0.06),
        ),
        child: Text(
          err,
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
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
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        color: Colors.white.withOpacity(0.70),
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Selfie Attendance",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.black,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Secure sign-in for DeoDap International Pvt Ltd",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
        color: Colors.white.withOpacity(0.93),
        boxShadow: [
          BoxShadow(
            blurRadius: 26,
            offset: const Offset(0, 12),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: AutofillGroup(
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
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Enter your Login Code and password to continue.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 14),

              // Login Code
              TextFormField(
                controller: _empCtrl,
                focusNode: _empFocus,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(20),
                  FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z0-9_-]")),
                ],
                decoration: _dec(
                  "Login Code",
                  hint: "e.g. 0717",
                  prefixIcon: const Icon(CupertinoIcons.person_badge_plus),
                ),
                validator: (v) {
                  final s = (v ?? "").trim();
                  if (s.isEmpty) return "Login Code is required";
                  if (!_empAllowed.hasMatch(s)) return "Only A-Z, 0-9, _ and - allowed";
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
                autofillHints: const [AutofillHints.password],
                decoration: _dec(
                  "Password",
                  hint: "Enter password",
                  prefixIcon: const Icon(CupertinoIcons.lock),
                  suffixIcon: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _loading ? null : () => setState(() => _showPass = !_showPass),
                    child: Icon(_showPass ? CupertinoIcons.eye_slash : CupertinoIcons.eye),
                  ),
                ),
                validator: (v) => (v ?? "").isEmpty ? "Password is required" : null,
                onFieldSubmitted: (_) => _loading ? null : _doLogin(),
              ),

              const SizedBox(height: 14),
              _errorBox(),
              const SizedBox(height: 14),

              SizedBox(
                height: 48,
                child: CupertinoButton.filled(
                  onPressed: _loading ? null : _doLogin,
                  borderRadius: BorderRadius.circular(14),
                  child: _loading
                      ? _loadingSpinner()
                      : const Text(
                    "Login",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 10 + bottomInset),
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 26),
                    child: Center(child: _loginCard(context)),
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
          child: _pageBody(context),
        ),
      ),
    );
  }
}
