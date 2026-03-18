import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:rapidmiles/login/login_screen.dart';
import 'package:rapidmiles/utils/date_utils.dart';

class DeliverScreen extends StatefulWidget {
  final String awb;
  final Map<String, dynamic>? payload;

  const DeliverScreen({super.key, required this.awb, this.payload});

  @override
  State<DeliverScreen> createState() => _DeliverScreenState();
}

class _DeliverScreenState extends State<DeliverScreen> {
  // ===== Premium Cream Theme =====
  static const Color cremeBg = Color(0xFFF6F1E8);
  static const Color cardBg = Color(0xFFFFFBF4);
  static const Color stroke = Color(0xFFE8DDCF);
  static const Color titleText = Color(0xFF111827);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color accent = Color(0xFF7A4E2D);

  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();
  final _collectableController = TextEditingController();

  bool _isLoading = false;

  double? _lat;
  double? _lng;
  String? _locationError;

  // Time
  DateTime _now = DateTime.now();
  Timer? _ticker;

  Map<String, dynamic>? _lastResponse;

  dynamic _readMapValue(dynamic source, String key) {
    if (source is Map && source.containsKey(key)) return source[key];
    return null;
  }

  dynamic _payloadValue(String key) {
    final payload = widget.payload;
    if (payload == null) return null;

    final direct = _readMapValue(payload, key);
    if (direct != null) return direct;

    final data = _readMapValue(payload, "data");
    final dataValue = _readMapValue(data, key);
    if (dataValue != null) return dataValue;

    final order = _readMapValue(payload, "order");
    final orderValue = _readMapValue(order, key);
    if (orderValue != null) return orderValue;

    final dataOrder = _readMapValue(data, "order");
    return _readMapValue(dataOrder, key);
  }

  String _normalizedPaymentType() {
    final raw = (_payloadValue('payment_type') ?? "")
        .toString()
        .trim()
        .toUpperCase();
    return raw.replaceAll(RegExp(r'[^A-Z]'), '');
  }

  bool _isCodType(String normalizedType) {
    return normalizedType == "COD" ||
        normalizedType == "CASHONDELIVERY" ||
        normalizedType == "CASHONDEL";
  }

  bool get _isPrepaid {
    final normalizedType = _normalizedPaymentType();
    if (normalizedType.isNotEmpty) {
      return !_isCodType(normalizedType);
    }

    final collectableRaw = _payloadValue('collectable_amount');
    final collectable = num.tryParse((collectableRaw ?? '').toString());
    if (collectable != null) {
      return collectable <= 0;
    }

    // Keep COD-safe default when payment details are missing.
    return false;
  }

  @override
  void initState() {
    super.initState();

    _startClock();

    if (!_isPrepaid) {
      // Prefill collectable amount if available
      final payloadAmount =
          _payloadValue('collectable_amount') ?? _payloadValue('order_amount');
      if (payloadAmount != null) {
        _collectableController.text = payloadAmount.toString();
      }
    }

    _fetchLocation(); // optional
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _remarksController.dispose();
    _collectableController.dispose();
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

  // ------------ GPS (Optional) ------------
  Future<void> _fetchLocation() async {
    setState(() => _locationError = null);

    try {
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        setState(
          () => _locationError = "Location permission denied (optional)",
        );
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError = "GPS OFF (optional)");
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (_) {
      setState(() => _locationError = "GPS fetch failed (optional)");
    }
  }

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
        backgroundColor: success ? Colors.green : Colors.red,
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

  // ---------------- API: Deliver ----------------
  Future<void> _submitDelivery() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    // GPS location is mandatory
    if (_lat == null || _lng == null) {
      _toast("GPS location is required. Please enable location and try again.");
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
        _toast('Session expired — please login');
        _goToLogin();
        return;
      }

      final uri = Uri.parse(
        'https://rapidmiles.in/api/shipment/v1/orders/${widget.awb}/action',
      );

      final fields = <String, String>{
        "action": "deliver",
      };
      if (!_isPrepaid) {
        fields["collectable_amount"] = _collectableController.text.trim();
      }

      final remarks = _remarksController.text.trim();
      if (remarks.isNotEmpty) fields["remarks"] = remarks;

      // GPS location is mandatory
      fields["latitude"] = _lat!.toString();
      fields["longitude"] = _lng!.toString();

      // NOTE: This sends as application/x-www-form-urlencoded (good for your API)
      final res = await http.post(
        uri,
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
        body: fields,
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

      // Special handling for validation errors
      if (!ok && res.statusCode == 422) {
        // Usually: {success:false, message:"Validation Error", data:{collectable_amount:[...]}}
        _toast(body["message"]?.toString() ?? "Validation Error");
        return;
      }

      _toast(
        body["message"]?.toString() ?? (ok ? "Delivered" : "Failed"),
        success: ok,
      );

      if (ok) {
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (!mounted) return;
      final errBody = {"success": false, "message": "Error: $e"};
      setState(() => _lastResponse = errBody);
      _toast("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- Summary UI ----------------
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
    final wallet = data["wallet"] is Map
        ? data["wallet"] as Map<String, dynamic>
        : const <String, dynamic>{};
    final company = order["company"] is Map
        ? order["company"] as Map<String, dynamic>
        : const <String, dynamic>{};

    final headerBg = success
        ? const Color(0xFFE5F8EA)
        : const Color(0xFFFFE4E7);
    final headerFg = success
        ? const Color(0xFF1E7A3A)
        : const Color(0xFFB4232C);
    final headerIcon = success
        ? Icons.check_circle_outline
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
                        success ? "Delivery Completed" : "Delivery Failed",
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

        _sectionCard(
          "Order",
          Column(
            children: [
              // _kv("company_id", order["company_id"]),
              _kv("order no", order["order_no"]),
              _kv("order date", AppDate.formatDateFromIso(order["order_date"])),
              _kv("awb", order["awb"]),
              _kv("order status", order["order_status"]),
              _kv("payment type", order["payment_type"]),
              _kv("order amount", order["order_amount"]),
              _kv("collectable amount", order["collectable_amount"]),
              _kv("attempt count", order["attempt_count"]),
              _kv(
                "picked up at",
                AppDate.formatDateTimeFromIso(order["picked_up_at"]),
              ),
              _kv(
                "delivered at",
                AppDate.formatDateTimeFromIso(order["delivered_at"]),
              ),
              _kv("is ndr", order["is_ndr"]),
              _kv("ndr reason", order["ndr_reason"]),
              _kv("is rto", order["is_rto"]),
              _kv(
                "rto initiated at",
                AppDate.formatDateTimeFromIso(order["rto_initiated_at"]),
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

        _sectionCard(
          "Ship From",
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

        _sectionCard(
          "Ship To",
          Column(
            children: [
              _kv("name", order["ship_to_name"]),
              _kv("address line 1", order["ship_to_address_line_1"]),
              _kv("address line 2", order["ship_to_address_line_2"]),
              _kv("city", order["ship_to_city"]),
              _kv("state", order["ship_to_state"]),
              _kv("pincode", order["ship_to_pincode"]),
              _kv("contact", order["ship_to_contact"]),
            ],
          ),
        ),

        const SizedBox(height: 12),

        _sectionCard(
          "Package",
          Column(
            children: [
              _kv("total weight kg", order["total_weight_kg"]),
              _kv("length cm", order["package_length_cm"]),
              _kv("width cm", order["package_width_cm"]),
              _kv("height cm", order["package_height_cm"]),
            ],
          ),
        ),

        const SizedBox(height: 12),

        _sectionCard(
          "Company",
          Column(
            children: [_kv("name", company["name"])],
          ),
        ),

        const SizedBox(height: 12),

        _sectionCard(
          "Wallet",
          Column(
            children: [
              _kv("balance", wallet["balance"]),
              _kv("outstanding", wallet["outstanding"]),
            ],
          ),
        ),

        const SizedBox(height: 12),

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
    final hasGps = _lat != null && _lng != null;

    return Scaffold(
      backgroundColor: cremeBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cardBg,
        surfaceTintColor: cardBg,
        centerTitle: true,
        title: const Text(
          "Deliver Order",
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
                      color: const Color(0xFFE5F8EA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBFEBCB)),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Color(0xFF1E7A3A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Delivering AWB",
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

          // GPS card
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
                  Icon(
                    hasGps ? Icons.location_on : Icons.location_off,
                    color: hasGps
                        ? const Color(0xFF1E7A3A)
                        : const Color(0xFFB26A00),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "GPS Location - required",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: titleText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (hasGps)
                          Text(
                            "Lat: ${_lat!.toStringAsFixed(6)} | Lng: ${_lng!.toStringAsFixed(6)}",
                            style: const TextStyle(
                              color: mutedText,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else
                          Text(
                            _locationError ?? "Fetching location...",
                            style: const TextStyle(
                              color: mutedText,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: _isLoading ? null : _fetchLocation,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Refresh"),
                    style: TextButton.styleFrom(foregroundColor: accent),
                  ),
                ],
              ),
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
                    if (!_isPrepaid) ...[
                      TextFormField(
                        controller: _collectableController,
                        decoration: InputDecoration(
                          labelText: 'Collectable Amount *',
                          hintText: 'Enter amount to collect (COD)',
                          prefixIcon: const Icon(Icons.currency_rupee),
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
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final v = (value ?? "").trim();
                          if (v.isEmpty)
                            return 'Collectable amount field is required';
                          final numVal = num.tryParse(v);
                          if (numVal == null) return 'Enter a valid number';
                          if (numVal < 0) return 'Amount cannot be negative';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _remarksController,
                      decoration: InputDecoration(
                        labelText: 'Remarks (Optional)',
                        hintText: 'Optional delivery notes',
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
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitDelivery,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E7A3A),
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
                                "Complete Delivery",
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
