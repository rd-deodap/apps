import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rapidmiles/login/login_screen.dart';
import 'package:rapidmiles/utils/date_utils.dart';

/// Retry Screen: sends action=retry and shows full output.
class RetryScreen extends StatefulWidget {
  final String awb; // used in URL path
  final Map<String, dynamic>? payload;

  const RetryScreen({super.key, required this.awb, this.payload});

  @override
  State<RetryScreen> createState() => _RetryScreenState();
}

class _RetryScreenState extends State<RetryScreen> {
  @override
  void initState() {
    super.initState();
    _startClock();
  }

  // ===== Premium Cream Theme =====
  static const Color cremeBg = Color(0xFFF6F1E8);
  static const Color cardBg = Color(0xFFFFFBF4);
  static const Color stroke = Color(0xFFE8DDCF);
  static const Color titleText = Color(0xFF111827);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color accent = Color(0xFF7A4E2D);

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ------------ Clock ------------
  void _startClock() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  // ------------ Time Formatters ------------
  String _dateText() => AppDate.formatDate(_now);
  String _timeText() => AppDate.formatTime(_now, withSeconds: true);

  bool _isLoading = false;

  // Time
  DateTime _now = DateTime.now();
  Timer? _ticker;

  Map<String, dynamic>? _lastResponse;

  // ---------------- Helpers ----------------
  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (r) => false,
    );
  }

  void _toast(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? const Color(0xFF1E63B5) : Colors.red,
      ),
    );
  }

  String _v(dynamic x) {
    // Handle booleans
    if (x is bool) {
      return x ? "Yes" : "No";
    }
    // Handle ISO date strings
    final s = (x ?? "").toString().trim();
    if (s.isEmpty) return "-";
    // Check if it looks like an ISO date (contains 'T' and '-')
    if (s.contains('T') && s.contains('-')) {
      final formatted = AppDate.formatDateTimeFromIso(s);
      return formatted != s ? formatted : s;
    }
    return s;
  }

  Widget _kv(String k, dynamic v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              k,
              style: const TextStyle(
                color: mutedText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _v(v),
              style: const TextStyle(
                color: titleText,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, Widget child) {
    return Card(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: titleText,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // ---------------- API: Retry ----------------
  Future<void> _submitRetry() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _lastResponse = null;
    });

    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString(SessionKeys.token) ?? "";

      if (token.isEmpty) {
        _toast("Session expired — please login");
        _goToLogin();
        return;
      }

      final uri = Uri.parse(
        'https://rapidmiles.in/api/shipment/v1/orders/${widget.awb}/action',
      );

      final res = await http.post(
        uri,
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
        body: {"action": "retry"},
      );

      if (res.statusCode == 401) {
        _toast("Unauthorized — login again");
        _goToLogin();
        return;
      }

      Map<String, dynamic> body;
      try {
        final decoded = jsonDecode(res.body);
        body = decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{};
      } catch (_) {
        body = {
          "success": false,
          "message": "Invalid JSON from server (HTTP ${res.statusCode})",
          "status_code": res.statusCode,
          "raw": res.body,
        };
      }

      if (!mounted) return;

      setState(() => _lastResponse = body);

      final ok = body["success"] == true;
      _toast(
        body["message"]?.toString() ??
            (ok ? "Retry initiated" : "Retry failed"),
        success: ok,
      );

      if (ok) HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      final errBody = {"success": false, "message": "Error: $e"};
      setState(() => _lastResponse = errBody);
      _toast("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- Summary ----------------
  Widget _buildSummary(Map<String, dynamic> body) {
    final success = body["success"] == true;
    final message = body["message"];
    final dataErrors = body["data"] is List
        ? (body["data"] as List)
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];

    final data = body["data"] is Map
        ? body["data"] as Map<String, dynamic>
        : const <String, dynamic>{};
    final order = data["order"] is Map
        ? data["order"] as Map<String, dynamic>
        : const <String, dynamic>{};

    final headerBg = success
        ? const Color(0xFFE7F1FF)
        : const Color(0xFFFFE4E7);
    final headerFg = success
        ? const Color(0xFF1E63B5)
        : const Color(0xFFB4232C);
    final headerIcon = success
        ? Icons.replay_circle_filled
        : Icons.error_outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: headerBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: headerFg.withOpacity(0.25)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(headerIcon, color: headerFg, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        success ? "Retry Initiated" : "Retry Failed",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: headerFg,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _v(message),
                        style: const TextStyle(
                          color: titleText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (dataErrors.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ...dataErrors.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 14,
                                  color: headerFg,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    e,
                                    style: TextStyle(
                                      color: headerFg,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        if (order.isNotEmpty) ...[
          _sectionCard(
            "Order",
            Column(
              children: [
                //_kv("company_id", order["company_id"]),
                _kv("order no", order["order_no"]),
                _kv(
                  "order date",
                  AppDate.formatDateFromIso(order["order_date"]),
                ),
                _kv("awb", order["awb"]),
                _kv("order status", order["order_status"]),
                _kv("payment type", order["payment_type"]),
                _kv("order amount", order["order_amount"]),
                _kv("collectable amount", order["collectable_amount"]),
                _kv("attempt count", order["attempt_count"]),
                _kv("is ndr", order["is ndr"]),
                _kv("ndr reason", order["ndr_reason"]),
                _kv(
                  "picked up at",
                  AppDate.formatDateTimeFromIso(order["picked_up_at"]),
                ),
                _kv(
                  "delivered at",
                  AppDate.formatDateTimeFromIso(order["delivered_at"]),
                ),
                _kv("is rto", order["is_rto"]),
                _kv(
                  "rto initiated at",
                  AppDate.formatDateTimeFromIso(order["rto_initiated_at"]),
                ),
                //  _kv("id", order["id"]),
                _kv(
                  "created_at",
                  AppDate.formatDateTimeFromIso(order["created_at"]),
                ),
                _kv(
                  "updated_at",
                  AppDate.formatDateTimeFromIso(order["updated_at"]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // OutlinedButton.icon(
        //   onPressed: () => _showRawJsonDialog(body),
        //   icon: const Icon(Icons.code),
        //   label: const Text("Show Raw JSON"),
        //   style: OutlinedButton.styleFrom(
        //     foregroundColor: accent,
        //     side: const BorderSide(color: stroke),
        //     shape: RoundedRectangleBorder(
        //       borderRadius: BorderRadius.circular(14),
        //     ),
        //     padding: const EdgeInsets.symmetric(vertical: 12),
        //   ),
        // ),
        const SizedBox(height: 10),

        ElevatedButton(
          onPressed: () =>
              Navigator.of(context).pop({"success": success, "data": body}),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text(
            "Back",
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cremeBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cardBg,
        surfaceTintColor: cardBg,
        centerTitle: true,
        title: const Text(
          "Retry Delivery",
          style: TextStyle(fontWeight: FontWeight.w900, color: titleText),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            color: cardBg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: stroke),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F1FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFB9D4FF)),
                    ),
                    child: const Icon(
                      Icons.replay_rounded,
                      color: Color(0xFF1E63B5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Retry Attempt For",
                          style: TextStyle(
                            color: mutedText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.awb,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: titleText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${_dateText()} • ${_timeText()}",
                          style: const TextStyle(
                            color: mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Info box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3D6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD89A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFFB26A00)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "This will start a new delivery attempt immediately.",
                    style: TextStyle(
                      color: titleText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E63B5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Start Retry Attempt",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
          ),

          const SizedBox(height: 12),

          if (_lastResponse != null) _buildSummary(_lastResponse!),
        ],
      ),
    );
  }
}
