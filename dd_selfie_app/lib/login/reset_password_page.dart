import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dd_selfie_app/home/home_screen.dart';

class ApiConfig {
  static const String changePasswordUrl =
      "https://customprint.deodap.com/api_selfie_app/reset_password.php";
}

class SessionKeys {
  static const String isLoggedIn = "isLoggedIn";
  static const String mustResetPassword = "must_reset_password";
}

class ResetPasswordPage extends StatefulWidget {
  final String empCode;
  final String token;

  const ResetPasswordPage({
    super.key,
    required this.empCode,
    required this.token,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _new2Ctrl = TextEditingController();

  final _oldFocus = FocusNode();
  final _newFocus = FocusNode();
  final _new2Focus = FocusNode();

  bool _loading = false;
  String? _error;

  bool _showOld = false;
  bool _showNew = false;
  bool _showNew2 = false;

  static const Color _creamBg = Color(0xFFFFF8E6);

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _new2Ctrl.dispose();
    _oldFocus.dispose();
    _newFocus.dispose();
    _new2Focus.dispose();
    super.dispose();
  }

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
      return {"ok": false, "error": "Invalid JSON response"};
    } catch (_) {
      return {"ok": false, "error": "Invalid JSON response"};
    }
  }

  Future<void> _showWelcomeAndGoHome() async {
    if (!mounted) return;

    showCupertinoDialog<void>(
      context: context,
      builder: (_) => const CupertinoAlertDialog(
        title: Text("Welcome"),
        content: Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text("Welcome to app"),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    Navigator.pop(context); // close dialog

    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(builder: (_) => const AppShell()),
    );
  }

  Future<void> _doChangePassword() async {
    FocusScope.of(context).unfocus();
    if (_loading) return;

    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final oldPass = _oldCtrl.text;
    final newPass = _newCtrl.text;
    final newPass2 = _new2Ctrl.text;

    if (newPass != newPass2) {
      setState(() => _error = "New password and confirm password do not match.");
      return;
    }

    setState(() => _loading = true);

    try {
      final jsonRes = await _postForm(ApiConfig.changePasswordUrl, {
        "emp_code": widget.empCode,
        "token": widget.token,
        "old_password": oldPass,
        "new_password": newPass,
      });

      if (jsonRes["ok"] == true) {
        final sp = await SharedPreferences.getInstance();

        // Unlock app only after successful reset
        await sp.setBool(SessionKeys.mustResetPassword, false);
        await sp.setBool(SessionKeys.isLoggedIn, true);

        if (!mounted) return;
        await _showWelcomeAndGoHome();
      } else {
        setState(() => _error = (jsonRes["error"] ?? "Failed").toString());
      }
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
        borderSide: BorderSide(color: Colors.black.withOpacity(0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.35), width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

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

  Widget _loadingSpinner() => const CupertinoActivityIndicator();

  Widget _brandHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        color: Colors.white.withOpacity(0.65),
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Reset Password",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.black,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "You must set a new password before continuing.",
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

  Widget _card(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
        color: Colors.white.withOpacity(0.92),
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
                "Set a new password",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Use at least 6 characters. Do not share your password with anyone.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _oldCtrl,
                focusNode: _oldFocus,
                obscureText: !_showOld,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.password],
                decoration: _dec(
                  "Old Password (Current)",
                  hint: "Enter current password",
                  prefixIcon: const Icon(CupertinoIcons.lock),
                  suffixIcon: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _loading ? null : () => setState(() => _showOld = !_showOld),
                    child: Icon(_showOld ? CupertinoIcons.eye_slash : CupertinoIcons.eye),
                  ),
                ),
                validator: (v) => (v ?? "").isEmpty ? "Old password is required" : null,
                onFieldSubmitted: (_) => _newFocus.requestFocus(),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _newCtrl,
                focusNode: _newFocus,
                obscureText: !_showNew,
                textInputAction: TextInputAction.next,
                inputFormatters: [LengthLimitingTextInputFormatter(64)],
                decoration: _dec(
                  "New Password",
                  hint: "Minimum 6 characters",
                  prefixIcon: const Icon(CupertinoIcons.padlock),
                  suffixIcon: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _loading ? null : () => setState(() => _showNew = !_showNew),
                    child: Icon(_showNew ? CupertinoIcons.eye_slash : CupertinoIcons.eye),
                  ),
                ),
                validator: (v) {
                  final s = (v ?? "");
                  if (s.isEmpty) return "New password is required";
                  if (s.length < 6) return "New password must be at least 6 characters";
                  return null;
                },
                onFieldSubmitted: (_) => _new2Focus.requestFocus(),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _new2Ctrl,
                focusNode: _new2Focus,
                obscureText: !_showNew2,
                textInputAction: TextInputAction.done,
                inputFormatters: [LengthLimitingTextInputFormatter(64)],
                decoration: _dec(
                  "Confirm New Password",
                  hint: "Re-enter new password",
                  prefixIcon: const Icon(CupertinoIcons.check_mark_circled),
                  suffixIcon: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _loading ? null : () => setState(() => _showNew2 = !_showNew2),
                    child: Icon(_showNew2 ? CupertinoIcons.eye_slash : CupertinoIcons.eye),
                  ),
                ),
                validator: (v) => (v ?? "").isEmpty ? "Confirm password is required" : null,
                onFieldSubmitted: (_) => _loading ? null : _doChangePassword(),
              ),

              const SizedBox(height: 14),
              _errorBox(),
              const SizedBox(height: 14),

              SizedBox(
                height: 48,
                child: CupertinoButton.filled(
                  onPressed: _loading ? null : _doChangePassword,
                  borderRadius: BorderRadius.circular(14),
                  child: _loading
                      ? _loadingSpinner()
                      : const Text(
                    "Change Password",
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

  Widget _footer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 14),
      child: Text(
        "Secure by DeoDap International Pvt Ltd",
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.black45,
          fontWeight: FontWeight.w700,
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
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 10 + bottomInset),
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 26),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _card(context),
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
          child: _pageBody(context),
        ),
      ),
    );
  }
}
