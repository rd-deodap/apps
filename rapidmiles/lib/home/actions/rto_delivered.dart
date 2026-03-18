import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rapidmiles/login/login_screen.dart';
import 'package:rapidmiles/utils/date_utils.dart';

/// RTO Delivered Screen: marks an RTO package as delivered back to origin.
/// Sends action=rto_delivered, reason (required), remarks (optional).
class RTODeliveredScreen extends StatefulWidget {
  final String awb;
  final Map<String, dynamic>? payload;

  const RTODeliveredScreen({super.key, required this.awb, this.payload});

  @override
  State<RTODeliveredScreen> createState() => _RTODeliveredScreenState();
}

class _RTODeliveredScreenState extends State<RTODeliveredScreen> {
  // ===== Premium Cream Theme =====
  static const Color cremeBg = Color(0xFFF6F1E8);
  static const Color cardBg = Color(0xFFFFFBF4);
  static const Color stroke = Color(0xFFE8DDCF);
  static const Color titleText = Color(0xFF111827);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color accent = Color(0xFF7A4E2D);

  // Orange/amber accent for RTO Delivered
  static const Color actionColor = Color(0xFFB26A00);
  static const Color actionBg = Color(0xFFFFF3DC);
  static const Color actionBorder = Color(0xFFFFD97A);

  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();
  final _manualReasonController = TextEditingController();

  String? _selectedReason;
  bool _confirmDelivered = false;
  bool _isLoading = false;
  bool? _hasPermission; // null = checking, false = denied, true = allowed

  DateTime _now = DateTime.now();
  Timer? _ticker;

  Map<String, dynamic>? _lastResponse;

  final List<Map<String, String>> _reasons = const [
    {"value": "customer_refused", "label": "Customer refused to accept"},
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
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final sp = await SharedPreferences.getInstance();
    final has = sp.getBool(SessionKeys.hasRtoDelivered) ?? false;
    if (mounted) setState(() => _hasPermission = has);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _remarksController.dispose();
    _manualReasonController.dispose();
    super.dispose();
  }

  void _startClock() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  String _dateText() => AppDate.formatDate(_now);
  String _timeText() => AppDate.formatTime(_now, withSeconds: true);

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
        backgroundColor: success ? actionColor : Colors.red,
      ),
    );
  }

  String _v(dynamic x) {
    if (x is bool) return x ? "Yes" : "No";
    final s = (x ?? "").toString().trim();
    if (s.isEmpty) return "-";
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

  // ---------------- API ----------------
  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedReason == null) {
      _toast("Please select a reason");
      return;
    }

    if (!_confirmDelivered) {
      _toast("Please confirm RTO delivery");
      return;
    }

    final manual = _manualReasonController.text.trim();
    if (_selectedReason == "other" && manual.isEmpty) {
      _toast("Please enter a manual reason");
      return;
    }

    final reasonToSend =
        (_selectedReason == "other") ? manual : _selectedReason!;

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
          "action": "rto_delivered",
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
        };
      }

      if (!mounted) return;
      setState(() => _lastResponse = body);

      final ok = body["success"] == true;
      _toast(
        body["message"]?.toString() ??
            (ok ? "RTO delivered successfully" : "RTO delivery failed"),
        success: ok,
      );

      if (ok) HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastResponse = {"success": false, "message": "Error: $e"});
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
    final company = order["company"] is Map
        ? order["company"] as Map<String, dynamic>
        : const <String, dynamic>{};

    final headerBg = success ? actionBg : const Color(0xFFFFE4E7);
    final headerFg = success ? actionColor : const Color(0xFFB4232C);
    final headerIcon =
        success ? Icons.inventory_2_outlined : Icons.error_outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: headerBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: headerFg.withValues(alpha: 0.25)),
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
                        success ? "RTO Delivered" : "RTO Delivery Failed",
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
                _kv("order no", order["order_no"]),
                _kv("order date", AppDate.formatDateFromIso(order["order_date"])),
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

        if (order["ship_from_name"] != null) ...[
          _sectionCard(
            "Ship From (Origin)",
            Column(
              children: [
                _kv("name", order["ship_from_name"]),
                _kv("address line 1", order["ship_from_address_line_1"]),
                _kv("address line 2", order["ship_from_address_line_2"]),
                _kv("city", order["ship_from_city"]),
                _kv("state", order["ship_from_state"]),
                _kv("pincode", order["ship_from_pincode"]),
                _kv("contact", order["ship_from_contact"]),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (company.isNotEmpty) ...[
          _sectionCard(
            "Company",
            Column(
              children: [_kv("name", company["name"])],
            ),
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 4),

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

  Widget _buildNoPermission() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE4E7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFBCC4)),
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 40,
                color: Color(0xFFB4232C),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Access Denied",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: titleText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "You do not have permission to perform RTO Delivered. Contact your admin.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
              ),
              child: const Text(
                "Go Back",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showManual = _selectedReason == "other";

    // Still checking permission
    if (_hasPermission == null) {
      return Scaffold(
        backgroundColor: cremeBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: cardBg,
          surfaceTintColor: cardBg,
          centerTitle: true,
          title: const Text(
            "RTO Delivered",
            style: TextStyle(fontWeight: FontWeight.w900, color: titleText),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // No permission
    if (_hasPermission == false) {
      return Scaffold(
        backgroundColor: cremeBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: cardBg,
          surfaceTintColor: cardBg,
          centerTitle: true,
          title: const Text(
            "RTO Delivered",
            style: TextStyle(fontWeight: FontWeight.w900, color: titleText),
          ),
        ),
        body: _buildNoPermission(),
      );
    }

    return Scaffold(
      backgroundColor: cremeBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cardBg,
        surfaceTintColor: cardBg,
        centerTitle: true,
        title: const Text(
          "RTO Delivered",
          style: TextStyle(fontWeight: FontWeight.w900, color: titleText),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Header card
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
                      color: actionBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: actionBorder),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: actionColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "RTO Delivery For",
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

          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: actionBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: actionBorder),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: actionColor),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "This will mark the RTO package as delivered back to the origin warehouse.",
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
                      initialValue: _selectedReason,
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
                      items: _reasons
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
                          if (_selectedReason != "other") {
                            _manualReasonController.clear();
                          }
                        });
                      },
                      validator: (v) =>
                          v == null ? "Please select a reason" : null,
                    ),

                    if (showManual) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _manualReasonController,
                        decoration: InputDecoration(
                          labelText: "Manual Reason *",
                          hintText: "Enter reason",
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

                    // Confirmation checkbox
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              _confirmDelivered ? actionColor : stroke,
                          width: 2,
                        ),
                        color: Colors.white,
                      ),
                      child: CheckboxListTile(
                        value: _confirmDelivered,
                        onChanged: _isLoading
                            ? null
                            : (v) =>
                                setState(() => _confirmDelivered = v ?? false),
                        activeColor: actionColor,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          "I confirm RTO delivery to origin",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: titleText,
                          ),
                        ),
                        subtitle: const Text(
                          "Package will be marked as RTO_DELIVERED",
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
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: actionColor,
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
                                "Mark as RTO Delivered",
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
