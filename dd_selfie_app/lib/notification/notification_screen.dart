import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class NotificationEndpoints {
  static const String notificationsUrl =
      "https://customprint.deodap.com/api_selfie_app/notifications.php";

  /// If selfie_path from API is relative (e.g. "uploads/.."),
  /// this prefix will be used to build full URL.
  static const String selfieBaseUrl = "https://customprint.deodap.com/";
}

class NotificationScreen extends StatefulWidget {
  final String empCode;
  final String token;

  const NotificationScreen({
    super.key,
    required this.empCode,
    required this.token,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // ---------------- UI THEME ----------------
  static const Color _pageBg = Colors.white;

  /// Soft cream for shadows / accents only.
  static const Color _cream = Color(0xFFFFF7EE);

  static Color get _border => Colors.black.withOpacity(0.06);

  static List<BoxShadow> get _creamShadow => [
    BoxShadow(
      blurRadius: 18,
      offset: const Offset(0, 10),
      color: _cream.withOpacity(0.55),
    ),
    BoxShadow(
      blurRadius: 10,
      offset: const Offset(0, 6),
      color: Colors.black.withOpacity(0.035),
    ),
  ];

  // ---------------- STATE ----------------
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  // counts (for tab badges)
  int _absent = 0;
  int _missPunch = 0;
  int _pending = 0;
  int _rejected = 0;
  int _total = 0;

  List<Map<String, dynamic>> _items = [];

  final DateFormat _dFmt = DateFormat("dd MMM yyyy");
  final DateFormat _tFmt = DateFormat("hh:mm a");

  @override
  void initState() {
    super.initState();
    _load(showLoader: true);
  }

  Future<void> _load({required bool showLoader}) async {
    final emp = widget.empCode.trim();
    final tok = widget.token.trim();

    if (emp.isEmpty || tok.isEmpty) {
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = "Session expired. Please login again.";
      });
      return;
    }

    if (showLoader) {
      setState(() {
        _loading = true;
        _refreshing = false;
        _error = null;
      });
    } else {
      setState(() {
        _refreshing = true;
        _error = null;
      });
    }

    try {
      final resp = await http
          .post(
        Uri.parse(NotificationEndpoints.notificationsUrl),
        body: {
          "action": "notifications",
          "emp_code": emp,
          "token": tok,
        },
      )
          .timeout(const Duration(seconds: 20));

      final obj = jsonDecode(resp.body);

      if (obj is! Map<String, dynamic>) {
        throw Exception("Invalid JSON root");
      }

      if (resp.statusCode != 200 || obj["ok"] != true) {
        setState(() {
          _loading = false;
          _refreshing = false;
          _error = "Unable to load notifications. Please try again.";
        });
        return;
      }

      final data = (obj["data"] as Map?)?.cast<String, dynamic>() ?? {};
      final counts = (data["counts"] as Map?)?.cast<String, dynamic>() ?? {};
      final list = data["notifications"];

      final items = <Map<String, dynamic>>[];
      if (list is List) {
        for (final it in list) {
          if (it is Map) items.add(it.cast<String, dynamic>());
        }
      }

      setState(() {
        _absent = _toInt(counts["absent"]);
        _missPunch = _toInt(counts["miss_punch"]);
        _pending = _toInt(counts["pending_approval"]);
        _rejected = _toInt(counts["rejected"]);
        _total = _toInt(counts["total_notifications"]);

        _items = items;

        _loading = false;
        _refreshing = false;
        _error = null;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = "Network error. Please try again.";
      });
    }
  }

  int _toInt(dynamic v) => int.tryParse((v ?? 0).toString()) ?? 0;

  String _niceDate(String ymd) {
    try {
      final dt = DateTime.parse(ymd);
      return _dFmt.format(dt);
    } catch (_) {
      return ymd;
    }
  }

  String _niceTime(dynamic t) {
    if (t == null) return "";
    final s = t.toString().trim();
    if (s.isEmpty) return "";
    try {
      final parts = s.split(":");
      if (parts.length >= 2) {
        final hh = int.parse(parts[0]);
        final mm = int.parse(parts[1]);
        final dt = DateTime(2000, 1, 1, hh, mm);
        return _tFmt.format(dt);
      }
    } catch (_) {}
    return s;
  }

  String _type(dynamic v) => (v ?? "").toString().trim().toUpperCase();

  List<Map<String, dynamic>> _filterItems(String typeKey) {
    // typeKey = "ALL" / "ABSENT" / "MISS_PUNCH" / "PENDING_APPROVAL" / "REJECTED"
    if (typeKey == "ALL") return _items;
    final out = <Map<String, dynamic>>[];
    for (final it in _items) {
      final t = _type(it["type"]);
      if (t == typeKey) out.add(it);
    }
    return out;
  }

  IconData _iconFor(String type) {
    switch (type) {
      case "MISS_PUNCH":
        return Icons.report_problem_outlined;
      case "ABSENT":
        return Icons.event_busy_rounded;
      case "PENDING_APPROVAL":
        return Icons.hourglass_top_rounded;
      case "REJECTED":
        return Icons.cancel_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _accentFor(String type) {
    switch (type) {
      case "MISS_PUNCH":
        return const Color(0xFFEF4444);
      case "ABSENT":
        return const Color(0xFF6366F1);
      case "PENDING_APPROVAL":
        return const Color(0xFFF59E0B);
      case "REJECTED":
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF2563EB);
    }
  }

  String _badgeText(String type) {
    switch (type) {
      case "MISS_PUNCH":
        return "MISS";
      case "ABSENT":
        return "ABSENT";
      case "PENDING_APPROVAL":
        return "PENDING";
      case "REJECTED":
        return "REJECTED";
      default:
        return "INFO";
    }
  }

  String _resolveSelfieUrl(String path) {
    final p = path.trim();
    if (p.isEmpty) return "";
    if (p.startsWith("http://") || p.startsWith("https://")) return p;
    return "${NotificationEndpoints.selfieBaseUrl}$p";
  }

  // ---------------- AppBar + TabBar ----------------

  PreferredSizeWidget _iosAppBarWithTabs() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        tooltip: "Back",
        icon: const Icon(CupertinoIcons.back, size: 22),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: const Text(
        "Notifications",
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      actions: [
        IconButton(
          tooltip: "Refresh",
          onPressed: _refreshing ? null : () => _load(showLoader: false),
          icon: _refreshing
              ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(CupertinoIcons.refresh, size: 22),
        ),
        const SizedBox(width: 6),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Container(
          decoration: BoxDecoration(
            color: _pageBg,
            boxShadow: _creamShadow,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(22),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _tabBar(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBar() {
    // counts visible on tabs => instantly know which tab has notifications
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _cream.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: TabBar(
        isScrollable: true,
        indicator: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(999),
        ),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black.withOpacity(0.70),
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        unselectedLabelStyle:
        const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        tabs: [
          _tabPill("All", _total),
          _tabPill("Absent", _absent),
          _tabPill("Miss", _missPunch),
          _tabPill("Pending", _pending),
          _tabPill("Rejected", _rejected),
        ],
      ),
    );
  }

  Tab _tabPill(String label, int count) {
    final show = count > 0;
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (show) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Text(
                count > 999 ? "999+" : count.toString(),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- Page ----------------

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: _pageBg,
        appBar: _iosAppBarWithTabs(),
        body: SafeArea(
          top: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _errorCard(context),
            ),
          )
              : TabBarView(
            children: [
              _tabBody("ALL"),
              _tabBody("ABSENT"),
              _tabBody("MISS_PUNCH"),
              _tabBody("PENDING_APPROVAL"),
              _tabBody("REJECTED"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBody(String typeKey) {
    final items = _filterItems(typeKey);

    return RefreshIndicator(
      onRefresh: () => _load(showLoader: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
        children: [
          Text(
            "Pull down to refresh • Tap an item for details",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty) _emptyCard(context) else ..._buildItems(items),
        ],
      ),
    );
  }

  List<Widget> _buildItems(List<Map<String, dynamic>> list) {
    final out = <Widget>[];
    for (final it in list) {
      out.add(_itemCard(it));
      out.add(const SizedBox(height: 10));
    }
    if (out.isNotEmpty) out.removeLast();
    return out;
  }

  Widget _errorCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: _creamShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error ?? "Unable to load",
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            "Check internet connection or login again.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.65),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => _load(showLoader: true),
            icon: const Icon(CupertinoIcons.refresh),
            label: const Text("Retry"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: _creamShadow,
      ),
      child: Column(
        children: [
          Icon(
            Icons.verified_rounded,
            size: 40,
            color: Colors.green.withOpacity(0.85),
          ),
          const SizedBox(height: 10),
          const Text(
            "No notifications",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            "No matching records found for this tab.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.65),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> it) {
    final type = _type(it["type"]);
    final title = (it["title"] ?? "Notification").toString();
    final message = (it["message"] ?? "").toString();
    final date = (it["date"] ?? "").toString();

    final punchType = (it["punch_type"] ?? "").toString();
    final punchTime = _niceTime(it["punch_time"]);
    final remark = (it["remark"] ?? "").toString();
    final selfiePath = (it["selfie_path"] ?? "").toString();

    final icon = _iconFor(type);
    final accent = _accentFor(type);

    final subtitle = <String>[];
    if (message.trim().isNotEmpty) subtitle.add(message.trim());
    if (punchType.trim().isNotEmpty || punchTime.trim().isNotEmpty) {
      final pt = punchType.trim().isEmpty ? "Punch" : punchType.trim();
      final tm = punchTime.trim().isEmpty ? "" : " • $punchTime";
      subtitle.add("$pt$tm");
    }

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openDetailsSheet(
        title: title,
        type: type,
        date: date,
        message: message,
        punchType: punchType,
        punchTime: punchTime,
        remark: remark,
        selfiePath: selfiePath,
        accent: accent,
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
          boxShadow: _creamShadow,
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _badge(type, accent),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _niceDate(date),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.black.withOpacity(0.60),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle.isEmpty ? "-" : subtitle.join("  •  "),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withOpacity(0.75),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (remark.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      "Remark: $remark",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black.withOpacity(0.70),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (selfiePath.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      "Selfie attached",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: accent.withOpacity(0.95),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_forward,
              color: Colors.black.withOpacity(0.35),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String type, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Text(
        _badgeText(type),
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: accent.withOpacity(0.95),
          fontSize: 12,
        ),
      ),
    );
  }

  void _openDetailsSheet({
    required String title,
    required String type,
    required String date,
    required String message,
    required String punchType,
    required String punchTime,
    required String remark,
    required String selfiePath,
    required Color accent,
  }) {
    final selfieUrl = _resolveSelfieUrl(selfiePath);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(_iconFor(type), color: accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 16),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _badge(type, accent),
                                const SizedBox(width: 8),
                                Text(
                                  _niceDate(date),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black.withOpacity(0.60),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _detailRow("Message", message.trim().isEmpty ? "-" : message.trim()),
                  if (punchType.trim().isNotEmpty) _detailRow("Punch Type", punchType.trim()),
                  if (punchTime.trim().isNotEmpty) _detailRow("Punch Time", punchTime.trim()),
                  if (remark.trim().isNotEmpty) _detailRow("Remark", remark.trim()),
                  if (selfieUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      "Selfie",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.black.withOpacity(0.80),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.network(
                          selfieUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              color: Colors.black.withOpacity(0.04),
                              child: Center(
                                child: Text(
                                  "Unable to load selfie",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black.withOpacity(0.60),
                                  ),
                                ),
                              ),
                            );
                          },
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: Colors.black.withOpacity(0.04),
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: Colors.black.withOpacity(0.12)),
                      ),
                      child: const Text(
                        "Close",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cream.withOpacity(0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              k,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              v,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black.withOpacity(0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
