import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, ScaffoldMessenger, SnackBar;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SessionKeys {
  static const String token = "token";
  static const String empCode = "emp_code";
}

class ReportEndpoints {
  static const String monthlyHtml =
      "https://customprint.deodap.com/api_selfie_app/webviewer_monthly.php";

  static const String monthlyPdf =
      "https://customprint.deodap.com/api_selfie_app/webviewer_monthly_pdf.php";
}

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final DateFormat _monthFmt = DateFormat("yyyy-MM"); // ✅ 2026-01

  String _empCode = "";
  String _token = "";

  /// Keep it always the 1st day of month internally
  DateTime _selectedMonth =
  DateTime(DateTime.now().year, DateTime.now().month, 1);

  bool _loading = true;
  bool _downloading = false;

  late final WebViewController _web;

  @override
  void initState() {
    super.initState();

    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) async {
            // ✅ Remove underline / text decoration inside web page
            await _injectNoUnderlineCss();
            if (mounted) setState(() => _loading = false);
          },
        ),
      );

    _loadSessionAndOpen();
  }

  Future<void> _loadSessionAndOpen() async {
    final sp = await SharedPreferences.getInstance();
    final emp = (sp.getString(SessionKeys.empCode) ?? "").trim();
    final tok = (sp.getString(SessionKeys.token) ?? "").trim();

    if (!mounted) return;

    if (emp.isEmpty || tok.isEmpty) {
      _showError("Session expired. Please login again.");
      return;
    }

    setState(() {
      _empCode = emp;
      _token = tok;
    });

    _openWebView();
  }

  String _buildMonthValue() => _monthFmt.format(_selectedMonth);

  String _buildHtmlUrl() {
    final month = _buildMonthValue();
    final uri = Uri.parse(ReportEndpoints.monthlyHtml).replace(
      queryParameters: {
        "emp_code": _empCode,
        "token": _token,
        "month": month,
      },
    );
    return uri.toString();
  }

  String _buildPdfUrl() {
    final month = _buildMonthValue();
    final uri = Uri.parse(ReportEndpoints.monthlyPdf).replace(
      queryParameters: {
        "emp_code": _empCode,
        "token": _token,
        "month": month,
      },
    );
    return uri.toString();
  }

  Future<void> _openWebView() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await _web.loadRequest(Uri.parse(_buildHtmlUrl()));
  }

  /// ✅ Strong CSS injection to remove underline everywhere
  Future<void> _injectNoUnderlineCss() async {
    try {
      await _web.runJavaScript(r"""
        (function () {
          try {
            var id = 'dd_no_underline_css';
            if (document.getElementById(id)) return;

            var css = `
              * { -webkit-tap-highlight-color: rgba(0,0,0,0); }
              a, a:link, a:visited, a:hover, a:active,
              a *, a:link *, a:visited *, a:hover *, a:active * {
                text-decoration: none !important;
                border-bottom: none !important;
                outline: none !important;
              }
            `;

            var style = document.createElement('style');
            style.id = id;
            style.type = 'text/css';
            style.appendChild(document.createTextNode(css));
            document.head.appendChild(style);
          } catch (e) {}
        })();
      """);
    } catch (_) {
      // ignore
    }
  }

  /// ✅ Proper Month Picker (NO OVERFLOW even if system font is large)
  Future<void> _pickMonth() async {
    final int startYear = 2023;
    final int endYear = DateTime.now().year + 2;

    final List<int> years =
    List<int>.generate(endYear - startYear + 1, (i) => startYear + i);

    final List<String> months = const [
      "01",
      "02",
      "03",
      "04",
      "05",
      "06",
      "07",
      "08",
      "09",
      "10",
      "11",
      "12",
    ];

    int tempYear = _selectedMonth.year;
    int tempMonth = _selectedMonth.month;

    int yearIndex = years.indexOf(tempYear);
    if (yearIndex < 0) yearIndex = 0;

    int monthIndex = tempMonth - 1;
    if (monthIndex < 0) monthIndex = 0;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) {
        // ✅ clamp text scale to avoid "Select Mont" overflow
        final mq = MediaQuery.of(context);
        final fixedMq = mq.copyWith(textScaler: const TextScaler.linear(1.0));

        return MediaQuery(
          data: fixedMq,
          child: CupertinoPopupSurface(
            child: Container(
              color: Colors.white,
              height: 360,
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    // Top bar (Cancel | Title | Done)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.black.withOpacity(0.08),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),

                          // Title (no overflow)
                          Expanded(
                            child: Center(
                              child: Text(
                                "Select Month",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  decoration: TextDecoration.none,
                                  color: CupertinoColors.black,
                                ),
                              ),
                            ),
                          ),

                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              final newMonth =
                              DateTime(tempYear, tempMonth, 1);
                              setState(() => _selectedMonth = newMonth);
                              Navigator.pop(context);
                              _openWebView();
                            },
                            child: const Text("Done"),
                          ),
                        ],
                      ),
                    ),

                    // Wheels
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoPicker(
                              scrollController:
                              FixedExtentScrollController(
                                  initialItem: monthIndex),
                              itemExtent: 42,
                              useMagnifier: true,
                              magnification: 1.08,
                              onSelectedItemChanged: (i) {
                                monthIndex = i;
                                tempMonth = i + 1;
                              },
                              children: months
                                  .map(
                                    (m) => Center(
                                  child: Text(
                                    m,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.none,
                                      color: CupertinoColors.black,
                                    ),
                                  ),
                                ),
                              )
                                  .toList(),
                            ),
                          ),
                          Expanded(
                            child: CupertinoPicker(
                              scrollController:
                              FixedExtentScrollController(
                                  initialItem: yearIndex),
                              itemExtent: 42,
                              useMagnifier: true,
                              magnification: 1.08,
                              onSelectedItemChanged: (i) {
                                yearIndex = i;
                                tempYear = years[i];
                              },
                              children: years
                                  .map(
                                    (y) => Center(
                                  child: Text(
                                    y.toString(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.none,
                                      color: CupertinoColors.black,
                                    ),
                                  ),
                                ),
                              )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom small hint
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        "Selected: ${_monthFmt.format(DateTime(tempYear, tempMonth, 1))}",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withOpacity(0.55),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadPdf() async {
    if (_downloading) return;
    setState(() => _downloading = true);

    try {
      final url = _buildPdfUrl();
      final month = _buildMonthValue();

      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/Monthly_Attendance_${_empCode}_$month.pdf");

      final dio = Dio(
        BaseOptions(
          receiveTimeout: const Duration(seconds: 90),
          connectTimeout: const Duration(seconds: 30),
        ),
      );

      await dio.download(
        url,
        file.path,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (s) => (s ?? 0) >= 200 && (s ?? 0) < 400,
        ),
      );

      if (!mounted) return;

      await OpenFilex.open(file.path);
      _toast("PDF saved: ${file.path}");
    } catch (e) {
      if (!mounted) return;
      _showError("PDF download failed: $e");
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _showError(String msg) {
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text("Error"),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(msg),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _curvedHeader() {
    final monthTitle = _buildMonthValue(); // ✅ 2026-01

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: const Icon(CupertinoIcons.back, color: Colors.black),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Monthly Report",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                    color: CupertinoColors.black,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Emp: $_empCode • $monthTitle",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withOpacity(0.55),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _pickMonth,
            child: const Icon(CupertinoIcons.calendar, color: Colors.black),
          ),
          const SizedBox(width: 6),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _downloading ? null : _downloadPdf,
            child: _downloading
                ? const CupertinoActivityIndicator()
                : const Icon(CupertinoIcons.arrow_down_doc, color: Colors.black),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            _curvedHeader(),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _web),
                  if (_loading)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Center(child: CupertinoActivityIndicator()),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
