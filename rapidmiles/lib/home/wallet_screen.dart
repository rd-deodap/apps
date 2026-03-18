import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../login/login_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  // Theme (light crème)
  static const Color cremeBg = Color(0xFFF6F1E8);
  static const Color cardBg = Color(0xFFFFFBF4);
  static const Color border = Color(0xFFE8DDCF);

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _wallet; // data object
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchWallet();
  }

  Future<void> _fetchWallet() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(SessionKeys.token) ?? "";

      if (token.isEmpty) {
        _goToLogin();
        return;
      }

      final uri = Uri.parse("https://rapidmiles.in/api/shipment/v1/wallet");

      final res = await http.get(
        uri,
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (res.statusCode == 401) {
        _goToLogin();
        return;
      }

      if (res.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = "Server error: ${res.statusCode}\n${res.body}";
        });
        return;
      }

      final decoded = json.decode(res.body);
      final success = decoded is Map && decoded["success"] == true;
      final data = (decoded is Map) ? decoded["data"] : null;

      if (!success || data is! Map) {
        setState(() {
          _loading = false;
          _error = "Invalid wallet API response format.";
        });
        return;
      }

      final tx = (data["transactions"] is List) ? data["transactions"] as List : [];

      setState(() {
        _wallet = Map<String, dynamic>.from(data);
        _transactions = tx;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = "Something went wrong: $e";
      });
    }
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cremeBg,
      appBar: AppBar(
        title: const Text("Wallet"),
        centerTitle: true,
        backgroundColor: cardBg,
        surfaceTintColor: cardBg,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchWallet,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchWallet,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CreamCard(
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _fetchWallet,
            child: const Text("Retry"),
          ),
        ],
      );
    }

    final w = _wallet ?? {};
    final balance = (w["balance"] ?? 0);
    final outstanding = (w["outstanding"] ?? 0);
    final totalToSubmit = (w["total_to_submit"] ?? 0);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _summaryHeader(
          balance: balance,
          outstanding: outstanding,
          totalToSubmit: totalToSubmit,
        ),
        const SizedBox(height: 12),
        Text(
          "Transactions (${_transactions.length})",
          style: TextStyle(
            color: Colors.brown.shade900,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        if (_transactions.isEmpty)
          _CreamCard(child: const Text("No transactions found."))
        else
          ..._transactions.map((t) => _transactionCard(t as Map<String, dynamic>)).toList(),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _summaryHeader({
    required dynamic balance,
    required dynamic outstanding,
    required dynamic totalToSubmit,
  }) {
    final balNum = _toNum(balance);
    final balUi = _MoneyUI.fromAmount(balNum);

    return _CreamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Wallet Summary",
            style: TextStyle(
              color: Colors.brown.shade900,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: balUi.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: balUi.border),
            ),
            child: Row(
              children: [
                Icon(balUi.icon, color: balUi.fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Balance",
                    style: TextStyle(
                      color: Colors.brown.shade800,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  "₹${balNum.toStringAsFixed(0)}",
                  style: TextStyle(
                    color: balUi.fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniSummaryBox(
                  title: "Outstanding",
                  value: "₹${_toNum(outstanding).toStringAsFixed(0)}",
                  icon: Icons.warning_amber_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniSummaryBox(
                  title: "To Submit",
                  value: "₹${_toNum(totalToSubmit).toStringAsFixed(0)}",
                  icon: Icons.upload_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniSummaryBox({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.brown.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: Colors.brown.shade600,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    )),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                      color: Colors.brown.shade900,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    )),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _transactionCard(Map<String, dynamic> t) {
    final type = (t["type"] ?? "N/A").toString();
    final amount = _toNum(t["amount"]);
    final before = _toNum(t["balance_before"]);
    final after = _toNum(t["balance_after"]);
    final desc = (t["description"] ?? "").toString();
    final createdAt = (t["created_at"] ?? "N/A").toString();

    final verifiedBy = t["verified_by"];
    final verifiedAt = t["verified_at"];

    final moneyUi = _MoneyUI.fromAmount(amount);

    final order = (t["order"] is Map) ? Map<String, dynamic>.from(t["order"]) : null;
    final orderNo = order == null ? "N/A" : (order["order_no"] ?? "N/A").toString();
    final awb = order == null ? "N/A" : (order["awb"] ?? "N/A").toString();
    final orderStatus = order == null ? "N/A" : (order["order_status"] ?? "N/A").toString();
    final paymentType = order == null ? "N/A" : (order["payment_type"] ?? "N/A").toString();
    final collectable = order == null ? "N/A" : (order["collectable_amount"] ?? "N/A").toString();
    final shipTo = order == null
        ? "N/A"
        : "${(order["ship_to_name"] ?? "N/A")} • ${(order["ship_to_city"] ?? "")}, ${(order["ship_to_state"] ?? "")}";
    final companyName = (order != null && order["company"] is Map)
        ? ((order["company"]["name"] ?? "N/A").toString())
        : "N/A";

    final statusUi = StatusUI.fromStatus(orderStatus);

    return _CreamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: moneyUi.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: moneyUi.border),
                ),
                child: Icon(moneyUi.icon, color: moneyUi.fg, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      style: TextStyle(
                        color: Colors.brown.shade900,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      createdAt,
                      style: TextStyle(
                        color: Colors.brown.shade600,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "₹${amount.toStringAsFixed(0)}",
                style: TextStyle(
                  color: moneyUi.fg,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          if (desc.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              desc,
              style: TextStyle(
                color: Colors.brown.shade800,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Balance before/after
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Expanded(child: _kvSmall("Before", "₹${before.toStringAsFixed(0)}")),
                Expanded(child: _kvSmall("After", "₹${after.toStringAsFixed(0)}")),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Verified
          Row(
            children: [
              Icon(
                (verifiedBy == null && verifiedAt == null)
                    ? Icons.hourglass_bottom_outlined
                    : Icons.verified_outlined,
                size: 18,
                color: (verifiedBy == null && verifiedAt == null)
                    ? Colors.orange.shade700
                    : Colors.green.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                (verifiedBy == null && verifiedAt == null)
                    ? "Not Verified"
                    : "Verified",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.brown.shade900,
                ),
              ),
            ],
          ),

          // Order block (if present)
          if (order != null) ...[
            const SizedBox(height: 14),
            Text(
              "Order",
              style: TextStyle(
                color: Colors.brown.shade900,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB9D4FF)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          orderNo,
                          style: TextStyle(
                            color: Colors.brown.shade900,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _StatusPill(chip: statusUi, label: orderStatus),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _kvLine("Company", companyName),
                  _kvLine("AWB", awb),
                  _kvLine("Payment", paymentType),
                  _kvLine("Collectable", "₹$collectable"),
                  _kvLine("Ship To", shipTo),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kvSmall(String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k,
            style: TextStyle(
              color: Colors.brown.shade600,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            )),
        const SizedBox(height: 4),
        Text(v,
            style: TextStyle(
              color: Colors.brown.shade900,
              fontWeight: FontWeight.w900,
            )),
      ],
    );
  }

  Widget _kvLine(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              k,
              style: TextStyle(
                color: Colors.brown.shade600,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                color: Colors.brown.shade900,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

/// ===== UI Helpers =====

class _CreamCard extends StatelessWidget {
  final Widget child;
  const _CreamCard({required this.child});

  static const Color cardBg = Color(0xFFFFFBF4);
  static const Color border = Color(0xFFE8DDCF);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final StatusUI chip;
  final String label;

  const _StatusPill({required this.chip, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: chip.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chip.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, size: 16, color: chip.fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: chip.fg,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status color mapping
class StatusUI {
  final Color bg;
  final Color fg;
  final Color border;
  final IconData icon;

  const StatusUI({
    required this.bg,
    required this.fg,
    required this.border,
    required this.icon,
  });

  static StatusUI fromStatus(String status) {
    switch (status) {
      case "PICKED_UP":
        return const StatusUI(
          bg: Color(0xFFE7F1FF),
          fg: Color(0xFF1E63B5),
          border: Color(0xFFB9D4FF),
          icon: Icons.inventory_2_outlined,
        );
      case "OUT_FOR_DELIVERY":
        return const StatusUI(
          bg: Color(0xFFFFF3D6),
          fg: Color(0xFFB26A00),
          border: Color(0xFFFFD89A),
          icon: Icons.local_shipping_outlined,
        );
      case "DELIVERED":
        return const StatusUI(
          bg: Color(0xFFE5F8EA),
          fg: Color(0xFF1E7A3A),
          border: Color(0xFFBFEBCB),
          icon: Icons.check_circle_outline,
        );
      case "NDR":
        return const StatusUI(
          bg: Color(0xFFFFE4E7),
          fg: Color(0xFFB4232C),
          border: Color(0xFFFFBCC4),
          icon: Icons.error_outline,
        );
      case "RTO":
        return const StatusUI(
          bg: Color(0xFFF0E9FF),
          fg: Color(0xFF5B2DB7),
          border: Color(0xFFD8C8FF),
          icon: Icons.undo_outlined,
        );
      case "PENDING":
        return const StatusUI(
          bg: Color(0xFFEFEFEF),
          fg: Color(0xFF444444),
          border: Color(0xFFD5D5D5),
          icon: Icons.hourglass_bottom_outlined,
        );
      default:
        return const StatusUI(
          bg: Color(0xFFEFEFEF),
          fg: Color(0xFF444444),
          border: Color(0xFFD5D5D5),
          icon: Icons.receipt_long_outlined,
        );
    }
  }
}

/// Amount color mapping (wallet)
class _MoneyUI {
  final Color bg;
  final Color fg;
  final Color border;
  final IconData icon;

  const _MoneyUI({
    required this.bg,
    required this.fg,
    required this.border,
    required this.icon,
  });

  static _MoneyUI fromAmount(double amount) {
    // In your API: COD collection amounts are negative (money to submit)
    if (amount < 0) {
      return _MoneyUI(
        bg: const Color(0xFFFFE4E7),
        fg: const Color(0xFFB4232C),
        border: const Color(0xFFFFBCC4),
        icon: Icons.call_received_rounded,
      );
    }
    if (amount > 0) {
      return _MoneyUI(
        bg: const Color(0xFFE5F8EA),
        fg: const Color(0xFF1E7A3A),
        border: const Color(0xFFBFEBCB),
        icon: Icons.call_made_rounded,
      );
    }
    return const _MoneyUI(
      bg: Color(0xFFEFEFEF),
      fg: Color(0xFF444444),
      border: Color(0xFFD5D5D5),
      icon: Icons.remove_rounded,
    );
  }
}
