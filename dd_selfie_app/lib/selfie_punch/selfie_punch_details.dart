import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// CHANGE THIS IMPORT PATH AS PER YOUR PROJECT
import 'package:dd_selfie_app/home/home_screen.dart';

/// Uses same keys as your LoginPage
class SessionKeys {
  static const String token = "token";
  static const String empCode = "emp_code";
}


class PunchLogApiConfig {
  static const String punchLogsUrl =
      "https://customprint.deodap.com/api_selfie_app/punch_filter.php";


  static const String baseDomain = "https://customprint.deodap.com";
}

/// ===============================
/// MODEL
/// ===============================
class PunchLogRow {
  final int id;
  final String attendanceDate; // yyyy-mm-dd
  final String punchType; // IN/OUT
  final String punchTime; // yyyy-mm-dd HH:mm:ss
  final String? remark;
  final String approvalStatus; // APPROVED/PENDING/REJECTED
  final String? selfiePath; // /uploads/selfies/....
  final double? liveLat;
  final double? liveLng;
  final String? liveAddress;
  final String? deviceId;
  final String? createdAt;

  PunchLogRow({
    required this.id,
    required this.attendanceDate,
    required this.punchType,
    required this.punchTime,
    required this.approvalStatus,
    this.remark,
    this.selfiePath,
    this.liveLat,
    this.liveLng,
    this.liveAddress,
    this.deviceId,
    this.createdAt,
  });

  String? get selfieUrl {
    final p = selfiePath?.trim();
    if (p == null || p.isEmpty) return null;
    if (p.startsWith("http://") || p.startsWith("https://")) return p;
    return "${PunchLogApiConfig.baseDomain}$p";
  }

  factory PunchLogRow.fromJson(Map<String, dynamic> j) {
    return PunchLogRow(
      id: (j['id'] ?? 0) is int
          ? (j['id'] as int)
          : int.tryParse("${j['id']}") ?? 0,
      attendanceDate: (j['attendance_date'] ?? "").toString(),
      punchType: (j['punch_type'] ?? "").toString().toUpperCase(),
      punchTime: (j['punch_time'] ?? "").toString(),
      approvalStatus:
      (j['approval_status'] ?? "APPROVED").toString().toUpperCase(),
      remark: j['remark']?.toString(),
      selfiePath: j['selfie_path']?.toString(),
      liveLat:
      (j['live_lat'] == null) ? null : double.tryParse("${j['live_lat']}"),
      liveLng:
      (j['live_lng'] == null) ? null : double.tryParse("${j['live_lng']}"),
      liveAddress: j['live_location_address']?.toString(),
      deviceId: j['device_id']?.toString(),
      createdAt: j['created_at']?.toString(),
    );
  }
}

/// ===============================
/// API CLIENT
/// - Supports Date Range by looping day-by-day (works even if backend only accepts single date)
/// ===============================
class PunchLogApi {
  static Future<Map<String, dynamic>> _postForm(
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

  static Future<List<PunchLogRow>> _fetchSingleDate({
    required String empCode,
    required String token,
    required String dateYmd,
    required String approvalStatus, // PENDING/APPROVED/REJECTED
    String punchType = "ALL",
    int limit = 500,
    int offset = 0,
  }) async {
    final jsonRes = await _postForm(PunchLogApiConfig.punchLogsUrl, {
      "action": "punch_logs",
      "emp_code": empCode,
      "token": token,
      "date": dateYmd,
      "approval_status": approvalStatus,
      "punch_type": punchType,
      "limit": "$limit",
      "offset": "$offset",
    });

    if (jsonRes["ok"] != true) {
      final err = (jsonRes["error"] is Map)
          ? ((jsonRes["error"]["message"] ?? "Fetch failed").toString())
          : (jsonRes["error"] ?? "Fetch failed").toString();
      throw Exception(err);
    }

    final data = (jsonRes["data"] as Map?)?.cast<String, dynamic>();
    if (data == null) throw Exception("Invalid response: missing data");

    final rowsJson = (data["rows"] as List?) ?? [];
    return rowsJson
        .whereType<Map>()
        .map((e) => PunchLogRow.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Date range (inclusive). If from==to it behaves like normal.
  /// Safety: hard cap days to avoid huge network calls.
  static Future<List<PunchLogRow>> fetchLogsRange({
    required String empCode,
    required String token,
    required DateTime fromDate,
    required DateTime toDate,
    required String approvalStatus, // PENDING/APPROVED/REJECTED
    String punchType = "ALL",
  }) async {
    final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final end = DateTime(toDate.year, toDate.month, toDate.day);
    if (end.isBefore(start)) return [];

    final days = end.difference(start).inDays + 1;
    if (days > 62) {
      throw Exception("Date range too large ($days days). Please select up to 62 days.");
    }

    final df = DateFormat("yyyy-MM-dd");
    final all = <PunchLogRow>[];

    for (int i = 0; i < days; i++) {
      final d = start.add(Duration(days: i));
      final ymd = df.format(d);

      final rows = await _fetchSingleDate(
        empCode: empCode,
        token: token,
        dateYmd: ymd,
        approvalStatus: approvalStatus,
        punchType: punchType,
      );
      all.addAll(rows);
    }

    // Sort by punch_time desc if possible
    all.sort((a, b) {
      DateTime? da;
      DateTime? db;
      try {
        da = DateTime.parse(a.punchTime.replaceFirst(" ", "T"));
      } catch (_) {}
      try {
        db = DateTime.parse(b.punchTime.replaceFirst(" ", "T"));
      } catch (_) {}
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    return all;
  }
}

class PunchLogsScreen extends StatefulWidget {
  const PunchLogsScreen({super.key});

  @override
  State<PunchLogsScreen> createState() => _PunchLogsScreenState();
}

class _PunchLogsScreenState extends State<PunchLogsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loading = true;
  String? _error;

  String _empCode = "";
  String _token = "";

  // default range = today
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  // data per tab
  List<PunchLogRow> _pending = [];
  List<PunchLogRow> _approved = [];
  List<PunchLogRow> _rejected = [];

  // ---- Theme colors (White + Cream)
  static const Color _creamBg = Color(0xFFFFF7E8);
  static const Color _cardWhite = Color(0xFFFFFFFF);
  static const Color _borderSoft = Color(0x1A000000);

  @override
  void initState() {
    super.initState();

    // DEFAULT OPEN: Approved TAB
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);

    _normalizeRangeToToday();
    _loadSessionAndFetch();
  }

  void _normalizeRangeToToday() {
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, now.day);
    _toDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _fromPretty => DateFormat("dd MMM yyyy").format(_fromDate);

  String get _toPretty => DateFormat("dd MMM yyyy").format(_toDate);

  bool get _isSingleDay =>
      _fromDate.year == _toDate.year &&
          _fromDate.month == _toDate.month &&
          _fromDate.day == _toDate.day;

  String get _rangeLabel =>
      _isSingleDay ? _fromPretty : "$_fromPretty  -  $_toPretty";

  Future<void> _loadSessionAndFetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sp = await SharedPreferences.getInstance();
      final emp = (sp.getString(SessionKeys.empCode) ?? "").trim();
      final tok = (sp.getString(SessionKeys.token) ?? "").trim();

      if (emp.isEmpty || tok.isEmpty) {
        throw Exception("Session expired. Please login again.");
      }

      _empCode = emp;
      _token = tok;

      await _fetchAllTabs();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchAllTabs() async {
    final from = _fromDate;
    final to = _toDate;

    final results = await Future.wait([
      PunchLogApi.fetchLogsRange(
        empCode: _empCode,
        token: _token,
        fromDate: from,
        toDate: to,
        approvalStatus: "PENDING",
      ),
      PunchLogApi.fetchLogsRange(
        empCode: _empCode,
        token: _token,
        fromDate: from,
        toDate: to,
        approvalStatus: "APPROVED",
      ),
      PunchLogApi.fetchLogsRange(
        empCode: _empCode,
        token: _token,
        fromDate: from,
        toDate: to,
        approvalStatus: "REJECTED",
      ),
    ]);

    if (!mounted) return;
    setState(() {
      _pending = results[0];
      _approved = results[1];
      _rejected = results[2];
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initialStart = _fromDate;
    final initialEnd = _toDate;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: "Select Date Range",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.brown,
              brightness: Brightness.light,
              background: _creamBg,
            ),
            dialogBackgroundColor: _creamBg,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _fromDate =
          DateTime(picked.start.year, picked.start.month, picked.start.day);
      _toDate = DateTime(picked.end.year, picked.end.month, picked.end.day);
      _error = null;
    });

    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _fetchAllTabs();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goHomeDirect() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
          (route) => false,
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.redAccent.withOpacity(0.85)),
        borderRadius: BorderRadius.circular(14),
        color: Colors.redAccent.withOpacity(0.07),
      ),
      child: Text(
        msg,
        style: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _topFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: _creamBg.withOpacity(0.85),
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _cardWhite.withOpacity(0.90),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _borderSoft),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.calendar,
                      size: 18, color: Colors.black.withOpacity(0.65)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _rangeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.black.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            onPressed: _loading ? null : _pickRange,
            child: const Text(
              "Change",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 10),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.black,
            borderRadius: BorderRadius.circular(14),
            onPressed: _loading ? null : _refresh,
            child: _loading
                ? const CupertinoActivityIndicator(color: Colors.white)
                : const Text("Refresh",
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Material(
      color: _creamBg.withOpacity(0.85),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.black54,
        indicatorColor: Colors.black,
        indicatorWeight: 2.2,
        labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        tabs: [
          Tab(text: "Pending (${_pending.length})"),
          Tab(text: "Approved (${_approved.length})"),
          Tab(text: "Rejected (${_rejected.length})"),
        ],
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.doc_text_search, size: 44),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                  color: Colors.black54, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _fmtPunchTime(String raw) {
    try {
      final dt = DateTime.parse(raw.replaceFirst(" ", "T"));
      return DateFormat("hh:mm a").format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _fmtPunchDate(String raw) {
    try {
      final dt = DateTime.parse(raw.replaceFirst(" ", "T"));
      return DateFormat("dd MMM").format(dt);
    } catch (_) {
      return "";
    }
  }

  Widget _imageBox(PunchLogRow row) {
    final url = row.selfieUrl;
    if (url == null) {
      return Container(
        height: 106,
        width: 106,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.04),
          border: Border.all(color: _borderSoft),
        ),
        child: const Icon(CupertinoIcons.photo, size: 30),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 106,
        width: 106,
        decoration: BoxDecoration(
          border: Border.all(color: _borderSoft),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.03),
        ),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(child: CupertinoActivityIndicator());
          },
          errorBuilder: (context, error, stack) {
            return Container(
              color: Colors.black.withOpacity(0.04),
              child: const Center(
                child: Icon(CupertinoIcons.exclamationmark_triangle, size: 26),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _chip(String text, {Color? bg, Color? fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _borderSoft),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: fg ?? Colors.black,
        ),
      ),
    );
  }

  (Color bg, Color fg) _statusColors(String status) {
    switch (status) {
      case "APPROVED":
        return (Colors.green.withOpacity(0.14), Colors.green.shade800);
      case "REJECTED":
        return (Colors.red.withOpacity(0.12), Colors.red.shade800);
      case "PENDING":
      default:
        return (Colors.orange.withOpacity(0.14), Colors.orange.shade900);
    }
  }

  // FIXED OVERFLOW CARD
  Widget _rowCard(PunchLogRow row) {
    final s = row.approvalStatus.toUpperCase();
    final colors = _statusColors(s);
    final remark = (row.remark ?? "").trim();
    final addr = (row.liveAddress ?? "").trim();

    final timeStr = _fmtPunchTime(row.punchTime);
    final dateStr = _fmtPunchDate(row.punchTime);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderSoft),
        color: _cardWhite.withOpacity(0.96),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _imageBox(row),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ROW 1: chips wrap + time safe (no overflow)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip(row.punchType == "IN" ? "IN" : "OUT"),
                          _chip(s, bg: colors.$1, fg: colors.$2),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        timeStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          fontSize: 12.8,
                        ),
                      ),
                    ),
                  ],
                ),

                // Small date under time (optional, like your screenshot)
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      dateStr,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        color: Colors.black.withOpacity(0.55),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                if (remark.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.035),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _borderSoft),
                    ),
                    child: Text(
                      remark,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  )
                else
                  Text(
                    "No note/remark",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withOpacity(0.55),
                    ),
                  ),

                if (addr.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(CupertinoIcons.location_solid,
                          size: 16, color: Colors.black.withOpacity(0.6)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          addr,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black.withOpacity(0.72),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listFor(List<PunchLogRow> list, String emptyLabel) {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: _errorBox(_error!),
      );
    }
    if (list.isEmpty) {
      return _emptyState(
        "No $emptyLabel logs for $_rangeLabel",
        "Try changing the date range or refresh.",
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16, top: 6),
        itemCount: list.length,
        itemBuilder: (_, i) => _rowCard(list[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double topInset =
        MediaQuery
            .of(context)
            .padding
            .top + const CupertinoNavigationBar().preferredSize.height;

    return CupertinoPageScaffold(
      backgroundColor: _creamBg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: _creamBg.withOpacity(0.92),
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _goHomeDirect,
          child: const Icon(CupertinoIcons.back),
        ),
        middle: const Text(
          "Punch Logs",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _loading ? null : _pickRange,
          child: const Icon(CupertinoIcons.calendar),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: Column(
              children: [
                _topFilterBar(),
                _tabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _listFor(_pending, "Pending"),
                      _listFor(_approved, "Approved"),
                      _listFor(_rejected, "Rejected"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}