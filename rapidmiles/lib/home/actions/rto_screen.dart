import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rapidmiles/login/login_screen.dart';
import 'package:rapidmiles/utils/date_utils.dart';

/// RTO Screen: sends action=rto, reason, remarks and shows full response.
class RTOScreen extends StatefulWidget {
  final String awb; // used in URL path
  final Map<String, dynamic>? payload;

  const RTOScreen({super.key, required this.awb, this.payload});

  @override
  State<RTOScreen> createState() => _RTOScreenState();
}

class _RTOScreenState extends State<RTOScreen> {
  // ===== Premium Cream Theme =====
  static const Color cremeBg = Color(0xFFF6F1E8);
  static const Color cardBg = Color(0xFFFFFBF4);
  static const Color stroke = Color(0xFFE8DDCF);
  static const Color titleText = Color(0xFF111827);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color accent = Color(0xFF7A4E2D);

  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();
  final _manualReasonController = TextEditingController();

  String? _selectedReason;
  bool _confirmRTO = false;
  bool _isLoading = false;

  // Time
  DateTime _now = DateTime.now();
  Timer? _ticker;

  Map<String, dynamic>? _lastResponse;

  final List<Map<String, String>> _rtoReasons = const [
    {"value": "customer_refused", "label": "Customer refused"},
    {"value": "not_reachable", "label": "Customer not reachable"},
    {"value": "address_issue", "label": "Address issue"},
    {"value": "door_closed", "label": "Door / premises closed"},
    {"value": "out_of_area", "label": "Out of delivery area"},
    {"value": "multiple_failed_attempts", "label": "Multiple failed attempts"},
    {"value": "other", "label": "Other (Manual)"},
  ];

  @override
  void initState() {
    super.initState();
    _startClock();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _remarksController.dispose();
    _manualReasonController.dispose();
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
        backgroundColor: success ? const Color(0xFFB4232C) : Colors.red,
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

  // ---------------- API: RTO ----------------
  Future<void> _submitRTO() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedReason == null) {
      _toast("Please select an RTO reason");
      return;
    }

    if (!_confirmRTO) {
      _toast("Please confirm RTO initiation");
      return;
    }

    final manual = _manualReasonController.text.trim();
    final reasonToSend = (_selectedReason == "other")
        ? manual
        : _selectedReason!;

    if (_selectedReason == "other" && manual.isEmpty) {
      _toast("Please enter manual reason");
      return;
    }

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
        "https://rapidmiles.in/api/shipment/v1/orders/${widget.awb}/action",
      );

      final res = await http.post(
        uri,
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
        body: {
          "action": "rto",
          "reason": reasonToSend,
          "remarks": _remarksController.text.trim(),
        },
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
        body["message"]?.toString() ?? (ok ? "RTO initiated" : "RTO failed"),
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
        ? const Color(0xFFFFE4E7)
        : const Color(0xFFEFEFEF);
    final headerFg = success
        ? const Color(0xFFB4232C)
        : const Color(0xFF444444);
    final headerIcon = success
        ? Icons.assignment_return_rounded
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
                        success ? "RTO Initiated" : "RTO Failed",
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
                _kv("is ndr", order["is_ndr"]),
                _kv("ndr reason", order["ndr_reason"]),
                _kv("is rto", order["is_rto"]),
                _kv(
                  "rto initiated at",
                  AppDate.formatDateTimeFromIso(order["rto_initiated_at"]),
                ),
                _kv(
                  "picked up at",
                  AppDate.formatDateTimeFromIso(order["picked_up_at"]),
                ),
                _kv(
                  "delivered at",
                  AppDate.formatDateTimeFromIso(order["delivered_at"]),
                ),
                //  _kv("id", order["id"]),
                _kv(
                  "created at",
                  AppDate.formatDateTimeFromIso(order["created_at"]),
                ),
                _kv(
                  "updated at",
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
    final showManual = _selectedReason == "other";

    return Scaffold(
      backgroundColor: cremeBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cardBg,
        surfaceTintColor: cardBg,
        centerTitle: true,
        title: const Text(
          "Return to Origin",
          style: TextStyle(fontWeight: FontWeight.w900, color: titleText),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Header
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
                      color: const Color(0xFFFFE4E7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFBCC4)),
                    ),
                    child: const Icon(
                      Icons.assignment_return_rounded,
                      color: Color(0xFFB4232C),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "RTO For",
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

          // Warning
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4E7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFBCC4)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFB4232C)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "This will initiate RTO. Package will be sent back to origin.",
                    style: TextStyle(
                      color: titleText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Form card
          Card(
            color: cardBg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: stroke),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedReason,
                      decoration: InputDecoration(
                        labelText: "Select Reason *",
                        prefixIcon: const Icon(Icons.list),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: stroke),
                        ),
                      ),
                      items: _rtoReasons
                          .map(
                            (r) => DropdownMenuItem<String>(
                              value: r["value"],
                              child: Text(r["label"] ?? "-"),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedReason = v;
                          if (_selectedReason != "other")
                            _manualReasonController.clear();
                        });
                      },
                      validator: (v) =>
                          v == null ? "Please select an RTO reason" : null,
                    ),

                    if (showManual) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _manualReasonController,
                        decoration: InputDecoration(
                          labelText: "Manual Reason *",
                          hintText: "Example: Customer don't want",
                          prefixIcon: const Icon(Icons.edit),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: stroke),
                          ),
                        ),
                        validator: (v) {
                          if (_selectedReason == "other" &&
                              (v ?? "").trim().isEmpty) {
                            return "Manual reason is required";
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _remarksController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "Remarks",
                        hintText: "Write short remarks (optional)",
                        prefixIcon: const Icon(Icons.note),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: stroke),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Confirmation
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _confirmRTO ? const Color(0xFFB4232C) : stroke,
                          width: 2,
                        ),
                        color: Colors.white,
                      ),
                      child: CheckboxListTile(
                        value: _confirmRTO,
                        onChanged: _isLoading
                            ? null
                            : (v) => setState(() => _confirmRTO = v ?? false),
                        activeColor: const Color(0xFFB4232C),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          "I confirm to initiate RTO for this order",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: titleText,
                          ),
                        ),
                        subtitle: const Text(
                          "This action cannot be easily reversed",
                          style: TextStyle(
                            color: mutedText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitRTO,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB4232C),
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
                                "Initiate RTO",
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                  ],
                ),
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
