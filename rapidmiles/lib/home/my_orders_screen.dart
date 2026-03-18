import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../login/login_screen.dart';
import 'package:rapidmiles/utils/date_utils.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // UI tabs (display labels)
  final List<String> _tabs = const [
    "ALL",
    "PICKED UP",
    "OUT FOR DELIVERY",
    "NDR",
    "DELIVERED",
    "RTO",
  ];

  // Cache per tab label
  final Map<String, List<dynamic>> _ordersByStatus = {};
  final Map<String, bool> _loadingByStatus = {};
  final Map<String, String?> _errorByStatus = {};

  // UI controls
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = "";
  _SortMode _sortMode = _SortMode.newest;
  String _paymentFilter = "ALL"; // ALL, COD, PREPAID

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final tab = _tabs[_tabController.index];
      if (_ordersByStatus[tab] == null && _loadingByStatus[tab] != true) {
        _fetchOrders(tabLabel: tab, force: true);
      }
    });

    _searchCtrl.addListener(() {
      final v = _searchCtrl.text.trim();
      if (v == _search) return;
      setState(() => _search = v);
    });

    _fetchOrders(tabLabel: "ALL", force: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ====== THEME (Cream + Colorful Accents) ======
  static const Color cremeBg = Color(0xFFF6F1E8);
  static const Color surface = Color(0xFFFFFBF4);
  static const Color border = Color(0xFFE8DDCF);

  static const Color titleText = Color(0xFF1F2937);
  static const Color bodyText = Color(0xFF374151);
  static const Color mutedText = Color(0xFF6B7280);

  static const Color accent = Color(0xFF7A4E2D); // warm brown
  static const Color accentSoft = Color(0xFFFFE6C7); // warm highlight

  Future<void> _fetchOrders({
    required String tabLabel,
    bool force = false,
  }) async {
    if (!force && _loadingByStatus[tabLabel] == true) return;

    setState(() {
      _loadingByStatus[tabLabel] = true;
      _errorByStatus[tabLabel] = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(SessionKeys.token) ?? "";

      if (token.isEmpty) {
        _goToLogin();
        return;
      }

      Uri uri = Uri.parse(
        "https://rapidmiles.in/api/shipment/v1/orders/my-orders",
      );

      // For API param: use normalized status (PICKED_UP, OUT_FOR_DELIVERY, etc.)
      if (tabLabel != "ALL") {
        final apiStatus = _statusToApi(tabLabel);
        uri = uri.replace(queryParameters: {"status": apiStatus});
      }

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
          _loadingByStatus[tabLabel] = false;
          _errorByStatus[tabLabel] =
              "Server error: ${res.statusCode}\n${res.body}";
        });
        return;
      }

      final decoded = json.decode(res.body);
      final success = decoded is Map && decoded["success"] == true;
      final data = (decoded is Map) ? decoded["data"] : null;

      if (!success || data is! List) {
        setState(() {
          _loadingByStatus[tabLabel] = false;
          _errorByStatus[tabLabel] = "Invalid API response format.";
        });
        return;
      }

      setState(() {
        _ordersByStatus[tabLabel] = data;
        _loadingByStatus[tabLabel] = false;
      });
    } catch (e) {
      setState(() {
        _loadingByStatus[tabLabel] = false;
        _errorByStatus[tabLabel] = "Something went wrong: $e";
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

  String _statusToApi(String tabLabel) {
    // Normalize tab labels => API values
    // Your chip helper uses underscore values; API likely expects the same.
    switch (tabLabel) {
      case "PICKED UP":
        return "PICKED_UP";
      case "OUT FOR DELIVERY":
        return "OUT_FOR_DELIVERY";
      default:
        return tabLabel; // NDR, DELIVERED, RTO are already clean
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cremeBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: surface,
        centerTitle: true,
        title: const Text(
          "My Orders",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(145),
          child: Column(
            children: [
              // Search + Sort row
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchField(
                        controller: _searchCtrl,
                        onClear: () => _searchCtrl.clear(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _SortMenu(
                      value: _sortMode,
                      onChanged: (v) => setState(() => _sortMode = v),
                    ),
                  ],
                ),
              ),

              // Payment type filter
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.filter_alt_outlined,
                      color: mutedText,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Payment:",
                      style: TextStyle(
                        color: mutedText,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _PaymentFilterChip(
                      label: "ALL",
                      isSelected: _paymentFilter == "ALL",
                      onTap: () => setState(() => _paymentFilter = "ALL"),
                    ),
                    const SizedBox(width: 8),
                    _PaymentFilterChip(
                      label: "COD",
                      isSelected: _paymentFilter == "COD",
                      onTap: () => setState(() => _paymentFilter = "COD"),
                    ),
                    const SizedBox(width: 8),
                    _PaymentFilterChip(
                      label: "PREPAID",
                      isSelected: _paymentFilter == "PREPAID",
                      onTap: () => setState(() => _paymentFilter = "PREPAID"),
                    ),
                  ],
                ),
              ),

              // Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: accent,
                labelColor: accent,
                unselectedLabelColor: Colors.brown.shade300,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tabLabel) {
          final loading = _loadingByStatus[tabLabel] ?? false;
          final error = _errorByStatus[tabLabel];
          final raw = _ordersByStatus[tabLabel] ?? const [];

          // apply client filter + sort
          final orders = _applySearchAndSort(raw);

          return RefreshIndicator(
            onRefresh: () => _fetchOrders(tabLabel: tabLabel, force: true),
            color: accent,
            child: _OrdersList(
              tabLabel: tabLabel,
              loading: loading,
              error: error,
              orders: orders,
              totalCount: raw.length,
              onOpenDetails: (orderMap) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailsScreen(order: orderMap),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Map<String, dynamic>> _applySearchAndSort(List<dynamic> raw) {
    final list = raw
        .whereType<Map<String, dynamic>>()
        .map((e) => e)
        .toList(growable: false);

    // Payment type filter
    List<Map<String, dynamic>> filtered = list;
    if (_paymentFilter != "ALL") {
      filtered = list
          .where((o) {
            final paymentType = (o["payment_type"] ?? "")
                .toString()
                .toUpperCase();
            return paymentType == _paymentFilter;
          })
          .toList(growable: false);
    }

    // Search
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered
          .where((o) {
            final orderNo = (o["order_no"] ?? "").toString().toLowerCase();
            final awb = (o["awb"] ?? "").toString().toLowerCase();
            final name = (o["ship_to_name"] ?? "").toString().toLowerCase();
            final city = (o["ship_to_city"] ?? "").toString().toLowerCase();
            final status = (o["order_status"] ?? "").toString().toLowerCase();
            return orderNo.contains(q) ||
                awb.contains(q) ||
                name.contains(q) ||
                city.contains(q) ||
                status.contains(q);
          })
          .toList(growable: false);
    }

    // Sort
    filtered = [...filtered];
    filtered.sort((a, b) {
      switch (_sortMode) {
        case _SortMode.amountHigh:
          final av = _toDouble(a["order_amount"]);
          final bv = _toDouble(b["order_amount"]);
          return bv.compareTo(av);
        case _SortMode.amountLow:
          final av = _toDouble(a["order_amount"]);
          final bv = _toDouble(b["order_amount"]);
          return av.compareTo(bv);
        case _SortMode.newest:
        default:
          final ad = _toDateTime(a["order_date"] ?? a["created_at"]);
          final bd = _toDateTime(b["order_date"] ?? b["created_at"]);
          return (bd ?? DateTime(0)).compareTo(ad ?? DateTime(0));
      }
    });

    return filtered;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    final s = v.toString().replaceAll(",", "").trim();
    return double.tryParse(s) ?? 0;
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    // Try DateTime parse; if API is custom format, it may fail (safe fallback)
    return DateTime.tryParse(s);
  }
}

// ===================== LIST UI =====================

class _OrdersList extends StatelessWidget {
  final String tabLabel;
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> orders;
  final int totalCount;
  final void Function(Map<String, dynamic> orderMap) onOpenDetails;

  const _OrdersList({
    required this.tabLabel,
    required this.loading,
    required this.error,
    required this.orders,
    required this.totalCount,
    required this.onOpenDetails,
  });

  static const Color cremeBg = _MyOrdersScreenState.cremeBg;
  static const Color surface = _MyOrdersScreenState.surface;
  static const Color border = _MyOrdersScreenState.border;

  static const Color titleText = _MyOrdersScreenState.titleText;
  static const Color bodyText = _MyOrdersScreenState.bodyText;
  static const Color mutedText = _MyOrdersScreenState.mutedText;

  static const Color accent = _MyOrdersScreenState.accent;
  static const Color accentSoft = _MyOrdersScreenState.accentSoft;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          SizedBox(height: 70),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (error != null) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _InfoBanner(
            title: "Failed to load orders",
            subtitle: error!,
            icon: Icons.error_outline,
            bg: const Color(0xFFFFE8EA),
            fg: const Color(0xFFB4232C),
            border: const Color(0xFFFFC2C8),
          ),
          const SizedBox(height: 10),
          _HintCard(text: "Pull down to retry."),
        ],
      );
    }

    if (totalCount == 0) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _InfoBanner(
            title: "No orders here",
            subtitle: "No orders found for $tabLabel.",
            icon: Icons.receipt_long_outlined,
            bg: surface,
            fg: accent,
            border: border,
          ),
          const SizedBox(height: 10),
          _HintCard(text: "Pull down to refresh."),
        ],
      );
    }

    if (orders.isEmpty) {
      // totalCount > 0 but after search 0
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _InfoBanner(
            title: "No match",
            subtitle:
                "Try a different search (order no, AWB, name, city, status).",
            icon: Icons.search_off_outlined,
            bg: const Color(0xFFFFF6E9),
            fg: const Color(0xFF8A5A2B),
            border: const Color(0xFFFFD7A6),
          ),
          const SizedBox(height: 10),
          _HintCard(text: "Pull down to refresh."),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemCount: orders.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _HeaderSummary(
            tabLabel: tabLabel,
            shown: orders.length,
            total: totalCount,
          );
        }

        final o = orders[index - 1];

        final orderNo = (o["order_no"] ?? "N/A").toString();
        final statusRaw = (o["order_status"] ?? "N/A").toString();
        final status = _StatusText.normalize(statusRaw);
        final awb = (o["awb"] ?? "N/A").toString();
        final rawOrderDate = o["order_date"] ?? o["created_at"];
        final orderDate = rawOrderDate != null
            ? AppDate.formatDateFromIso(rawOrderDate.toString())
            : "N/A";
        final amount = (o["order_amount"] ?? "N/A").toString();
        final paymentType = (o["payment_type"] ?? "N/A").toString();

        final shipToName = (o["ship_to_name"] ?? "N/A").toString();
        final shipToCity = (o["ship_to_city"] ?? "N/A").toString();
        final shipToState = (o["ship_to_state"] ?? "N/A").toString();
        final shipToPincode = (o["ship_to_pincode"] ?? "N/A").toString();

        final items = (o["items"] is List) ? (o["items"] as List) : const [];
        final itemCount = items.length;

        final chip = _StatusChip.fromAnyStatus(status);

        return InkWell(
          onTap: () => onOpenDetails(o),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: order no + chip
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        orderNo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: titleText,
                        ),
                      ),
                    ),
                    _ChipPill(
                      bg: chip.bg,
                      fg: chip.fg,
                      border: chip.border,
                      icon: chip.icon,
                      text: _StatusText.pretty(status),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Middle: compact grid-ish info
                Row(
                  children: [
                    Expanded(
                      child: _InfoLine(
                        icon: Icons.qr_code_2,
                        label: "AWB",
                        value: awb,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoLine(
                        icon: Icons.event,
                        label: "Date",
                        value: orderDate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _InfoLine(
                        icon: Icons.payments_outlined,
                        label: "Payment",
                        value: paymentType,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoLine(
                        icon: Icons.currency_rupee,
                        label: "Amount",
                        value: amount,
                        valueStyle: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Container(height: 1, color: border.withOpacity(.9)),
                const SizedBox(height: 10),

                _InfoLine(
                  icon: Icons.person_outline,
                  label: "Ship To",
                  value:
                      "$shipToName • $shipToCity, $shipToState , $shipToPincode",
                ),

                const SizedBox(height: 8),
                _InfoLine(
                  icon: Icons.inventory_2_outlined,
                  label: "Items",
                  value: "$itemCount item(s)",
                ),

                const SizedBox(height: 12),

                Row(
                  children: const [
                    Text(
                      "View Details",
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.chevron_right, color: Color(0xFFBCA48C)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderSummary extends StatelessWidget {
  final String tabLabel;
  final int shown;
  final int total;

  const _HeaderSummary({
    required this.tabLabel,
    required this.shown,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = shown == total
        ? "$total orders"
        : "Showing $shown of $total (search filter)";

    return Container(
      decoration: BoxDecoration(
        color: _MyOrdersScreenState.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _MyOrdersScreenState.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _MyOrdersScreenState.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(10),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: _MyOrdersScreenState.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tabLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _MyOrdersScreenState.titleText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _MyOrdersScreenState.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.swipe_down, color: _MyOrdersScreenState.mutedText),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _MyOrdersScreenState.mutedText),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontFamily: null),
              children: [
                TextSpan(
                  text: "$label: ",
                  style: const TextStyle(
                    color: _MyOrdersScreenState.mutedText,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                TextSpan(
                  text: value,
                  style:
                      valueStyle ??
                      const TextStyle(
                        color: _MyOrdersScreenState.bodyText,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChipPill extends StatelessWidget {
  final Color bg;
  final Color fg;
  final Color border;
  final IconData icon;
  final String text;

  const _ChipPill({
    required this.bg,
    required this.fg,
    required this.border,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color border;

  const _InfoBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: fg.withOpacity(.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final String text;
  const _HintCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _MyOrdersScreenState.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _MyOrdersScreenState.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _MyOrdersScreenState.mutedText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _MyOrdersScreenState.mutedText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== SEARCH + SORT =====================

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;

  const _SearchField({required this.controller, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: "Search: order no / AWB / name / city / status",
        hintStyle: const TextStyle(
          color: _MyOrdersScreenState.mutedText,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        prefixIcon: const Icon(
          Icons.search,
          color: _MyOrdersScreenState.mutedText,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(
                  Icons.close,
                  color: _MyOrdersScreenState.mutedText,
                ),
              ),
        filled: true,
        fillColor: _MyOrdersScreenState.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _MyOrdersScreenState.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _MyOrdersScreenState.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: _MyOrdersScreenState.accent,
            width: 1.2,
          ),
        ),
      ),
      style: const TextStyle(
        color: _MyOrdersScreenState.titleText,
        fontWeight: FontWeight.w900,
        fontSize: 13,
      ),
    );
  }
}

enum _SortMode { newest, amountHigh, amountLow }

class _SortMenu extends StatelessWidget {
  final _SortMode value;
  final ValueChanged<_SortMode> onChanged;

  const _SortMenu({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _MyOrdersScreenState.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _MyOrdersScreenState.border),
      ),
      child: PopupMenuButton<_SortMode>(
        initialValue: value,
        onSelected: onChanged,
        itemBuilder: (_) => const [
          PopupMenuItem(value: _SortMode.newest, child: Text("Newest")),
          PopupMenuItem(
            value: _SortMode.amountHigh,
            child: Text("Amount: High → Low"),
          ),
          PopupMenuItem(
            value: _SortMode.amountLow,
            child: Text("Amount: Low → High"),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.sort, color: _MyOrdersScreenState.mutedText, size: 18),
              SizedBox(width: 8),
              Text(
                "Sort",
                style: TextStyle(
                  color: _MyOrdersScreenState.titleText,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.expand_more, color: _MyOrdersScreenState.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? _MyOrdersScreenState.accent
              : _MyOrdersScreenState.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? _MyOrdersScreenState.accent
                : _MyOrdersScreenState.border,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : _MyOrdersScreenState.bodyText,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ===================== DETAILS SCREEN =====================

class OrderDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderDetailsScreen({super.key, required this.order});

  static const Color cremeBg = _MyOrdersScreenState.cremeBg;
  static const Color surface = _MyOrdersScreenState.surface;
  static const Color border = _MyOrdersScreenState.border;

  @override
  Widget build(BuildContext context) {
    final statusRaw = (order["order_status"] ?? "N/A").toString();
    final status = _StatusText.normalize(statusRaw);
    final chip = _StatusChip.fromAnyStatus(status);

    final items = (order["items"] is List)
        ? (order["items"] as List)
        : const [];
    final company = (order["company"] is Map)
        ? (order["company"] as Map<String, dynamic>)
        : null;

    return Scaffold(
      backgroundColor: cremeBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: surface,
        centerTitle: true,
        title: const Text(
          "Order Details",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Top status card
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: chip.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: chip.border),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(chip.icon, color: chip.fg, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (order["order_no"] ?? "N/A").toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _MyOrdersScreenState.titleText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _ChipPill(
                        bg: chip.bg,
                        fg: chip.fg,
                        border: chip.border,
                        icon: chip.icon,
                        text: _StatusText.pretty(status),
                      ),
                    ],
                  ),
                ),
                if ((order["awb"] ?? "").toString().trim().isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "AWB",
                        style: TextStyle(
                          color: _MyOrdersScreenState.mutedText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (order["awb"] ?? "N/A").toString(),
                        style: const TextStyle(
                          color: _MyOrdersScreenState.titleText,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (company != null) ...[
            _SectionCard(
              title: "Company",
              child: Column(
                children: [
                  //  _kv("Company ID", (order["company_id"] ?? "N/A").toString()),
                  _kv("Code", (company["code"] ?? "N/A").toString()),
                  _kv("Name", (company["name"] ?? "N/A").toString()),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          _SectionCard(
            title: "Order",
            child: Column(
              children: [
                //    _kv("ID", (order["id"] ?? "N/A").toString()),
                _kv(
                  "Order Date",
                  order["order_date"] != null
                      ? AppDate.formatDateFromIso(
                          order["order_date"].toString(),
                        )
                      : "N/A",
                ),
                _kv(
                  "Payment Type",
                  (order["payment_type"] ?? "N/A").toString(),
                ),
                _kv(
                  "Order Amount",
                  (order["order_amount"] ?? "N/A").toString(),
                ),
                _kv(
                  "Collectable Amount",
                  (order["collectable_amount"] ?? "N/A").toString(),
                ),
                _kv(
                  "Picked Up At",
                  order["picked_up_at"] != null
                      ? AppDate.formatDateTimeFromIso(
                          order["picked_up_at"].toString(),
                        )
                      : "N/A",
                ),
                _kv(
                  "Delivered At",
                  order["delivered_at"] != null
                      ? AppDate.formatDateTimeFromIso(
                          order["delivered_at"].toString(),
                        )
                      : "N/A",
                ),
                _kv("Is NDR", (order["is_ndr"] ?? "N/A").toString()),
                _kv("NDR Reason", (order["ndr_reason"] ?? "N/A").toString()),
                _kv(
                  "Attempt Count",
                  (order["attempt_count"] ?? "N/A").toString(),
                ),
                _kv("Is RTO", (order["is_rto"] ?? "N/A").toString()),
                _kv(
                  "RTO Initiated At",
                  order["rto_initiated_at"] != null
                      ? AppDate.formatDateTimeFromIso(
                          order["rto_initiated_at"].toString(),
                        )
                      : "N/A",
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _SectionCard(
            title: "Package",
            child: Column(
              children: [
                _kv(
                  "Total Weight (kg)",
                  (order["total_weight_kg"] ?? "N/A").toString(),
                ),
                _kv(
                  "Length (cm)",
                  (order["package_length_cm"] ?? "N/A").toString(),
                ),
                _kv(
                  "Width (cm)",
                  (order["package_width_cm"] ?? "N/A").toString(),
                ),
                _kv(
                  "Height (cm)",
                  (order["package_height_cm"] ?? "N/A").toString(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _SectionCard(
            title: "Ship From",
            child: Column(
              children: [
                _kv("Name", (order["ship_from_name"] ?? "N/A").toString()),
                _kv(
                  "Address 1",
                  (order["ship_from_address_line_1"] ?? "N/A").toString(),
                ),
                _kv(
                  "Address 2",
                  (order["ship_from_address_line_2"] ?? "N/A").toString(),
                ),
                _kv("City", (order["ship_from_city"] ?? "N/A").toString()),
                _kv("State", (order["ship_from_state"] ?? "N/A").toString()),
                _kv(
                  "Pincode",
                  (order["ship_from_pincode"] ?? "N/A").toString(),
                ),
                _kv(
                  "Contact",
                  (order["ship_from_contact"] ?? "N/A").toString(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _SectionCard(
            title: "Ship To",
            child: Column(
              children: [
                _kv("Name", (order["ship_to_name"] ?? "N/A").toString()),
                _kv(
                  "Address 1",
                  (order["ship_to_address_line_1"] ?? "N/A").toString(),
                ),
                _kv(
                  "Address 2",
                  (order["ship_to_address_line_2"] ?? "N/A").toString(),
                ),
                _kv("City", (order["ship_to_city"] ?? "N/A").toString()),
                _kv("State", (order["ship_to_state"] ?? "N/A").toString()),
                _kv("Pincode", (order["ship_to_pincode"] ?? "N/A").toString()),
                _kv("Contact", (order["ship_to_contact"] ?? "N/A").toString()),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _SectionCard(
            title: "Items (${items.length})",
            child: items.isEmpty
                ? const Text(
                    "No items found.",
                    style: TextStyle(
                      color: _MyOrdersScreenState.mutedText,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : ExpansionPanelList.radio(
                    elevation: 0,
                    expandedHeaderPadding: EdgeInsets.zero,
                    dividerColor: border,
                    children: [
                      for (int i = 0; i < items.length; i++)
                        _buildItemPanel(items[i], i),
                    ],
                  ),
          ),

          const SizedBox(height: 18),
        ],
      ),
    );
  }

  ExpansionPanelRadio _buildItemPanel(dynamic it, int index) {
    final item = (it is Map<String, dynamic>) ? it : <String, dynamic>{};
    final title =
        (item["item_description"] ??
                item["item_identifier"] ??
                "Item ${index + 1}")
            .toString();

    return ExpansionPanelRadio(
      value: "item_$index",
      canTapOnHeader: true,
      headerBuilder: (context, isExpanded) {
        return ListTile(
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: _MyOrdersScreenState.titleText,
            ),
          ),
          subtitle: Text(
            "Qty: ${(item["item_qty"] ?? "N/A")} • Amount: ${(item["item_amount"] ?? "N/A")}",
            style: const TextStyle(
              color: _MyOrdersScreenState.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          children: [
            _kv("Identifier", (item["item_identifier"] ?? "N/A").toString()),
            _kv("HSN", (item["item_sac_hsn"] ?? "N/A").toString()),
            _kv("Qty", (item["item_qty"] ?? "N/A").toString()),
            _kv("Weight", (item["item_weight"] ?? "N/A").toString()),
            _kv("Amount", (item["item_amount"] ?? "N/A").toString()),
            _kv("Length (cm)", (item["item_length_cm"] ?? "N/A").toString()),
            _kv("Width (cm)", (item["item_width_cm"] ?? "N/A").toString()),
            _kv("Height (cm)", (item["item_height_cm"] ?? "N/A").toString()),
            _kv("Order ID", (item["order_id"] ?? "N/A").toString()),
            _kv("Item ID", (item["id"] ?? "N/A").toString()),
          ],
        ),
      ),
    );
  }

  static Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: const TextStyle(
                color: _MyOrdersScreenState.mutedText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                color: _MyOrdersScreenState.bodyText,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _MyOrdersScreenState.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _MyOrdersScreenState.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: _MyOrdersScreenState.titleText,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ===================== STATUS NORMALIZATION + CHIP =====================

class _StatusText {
  static String normalize(String s) {
    // Handle "PICKED UP" / "PICKED_UP" / "picked_up" etc.
    final t = s.trim().toUpperCase().replaceAll("-", "_").replaceAll(" ", "_");
    // Some APIs return OUTFORDELIVERY or similar; keep minimal normalization
    if (t == "PICKEDUP") return "PICKED_UP";
    if (t == "OUTFORDELIVERY") return "OUT_FOR_DELIVERY";
    return t;
  }

  static String pretty(String normalized) {
    switch (normalized) {
      case "PICKED_UP":
        return "Picked Up";
      case "OUT_FOR_DELIVERY":
        return "Out for Delivery";
      case "DELIVERED":
        return "Delivered";
      case "NDR":
        return "NDR";
      case "RTO":
        return "RTO";
      default:
        // fallback: make underscore readable
        return normalized.replaceAll("_", " ").trim();
    }
  }
}

class _StatusChip {
  final Color bg;
  final Color fg;
  final Color border;
  final IconData icon;

  _StatusChip({
    required this.bg,
    required this.fg,
    required this.border,
    required this.icon,
  });

  static _StatusChip fromAnyStatus(String normalizedStatus) {
    switch (normalizedStatus) {
      case "PICKED_UP":
        return _StatusChip(
          bg: const Color(0xFFE7F1FF),
          fg: const Color(0xFF1E63B5),
          border: const Color(0xFFB9D4FF),
          icon: Icons.inventory_2_outlined,
        );
      case "OUT_FOR_DELIVERY":
        return _StatusChip(
          bg: const Color(0xFFFFF3D6),
          fg: const Color(0xFFB26A00),
          border: const Color(0xFFFFD89A),
          icon: Icons.local_shipping_outlined,
        );
      case "DELIVERED":
        return _StatusChip(
          bg: const Color(0xFFE5F8EA),
          fg: const Color(0xFF1E7A3A),
          border: const Color(0xFFBFEBCB),
          icon: Icons.check_circle_outline,
        );
      case "NDR":
        return _StatusChip(
          bg: const Color(0xFFFFE4E7),
          fg: const Color(0xFFB4232C),
          border: const Color(0xFFFFBCC4),
          icon: Icons.error_outline,
        );
      case "RTO":
        return _StatusChip(
          bg: const Color(0xFFF0E9FF),
          fg: const Color(0xFF5B2DB7),
          border: const Color(0xFFD8C8FF),
          icon: Icons.undo_outlined,
        );
      default:
        return _StatusChip(
          bg: const Color(0xFFF1F5F9),
          fg: const Color(0xFF334155),
          border: const Color(0xFFE2E8F0),
          icon: Icons.receipt_long_outlined,
        );
    }
  }
}
