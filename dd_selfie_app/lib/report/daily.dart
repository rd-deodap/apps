// lib/reports/daily_report_screen.dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, ScaffoldMessenger, SnackBar, showDatePicker, ColorScheme, Theme;
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
  // HTML page for WebView
  static const String dailyHtml =
      "https://customprint.deodap.com/api_selfie_app/webviewer.php";

  // PDF download endpoint
  static const String dailyPdf =
      "https://customprint.deodap.com/api_selfie_app/webviewer_pdf.php";
}

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  final DateFormat _df = DateFormat("yyyy-MM-dd");

  String _empCode = "";
  String _token = "";
  DateTime _selected = DateTime.now();

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
            // ✅ Remove underline / text-decoration inside WebView page
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

  String _buildHtmlUrl() {
    final date = _df.format(_selected);
    final uri = Uri.parse(ReportEndpoints.dailyHtml).replace(queryParameters: {
      "emp_code": _empCode,
      "token": _token,
      "date": date,
    });
    return uri.toString();
  }

  String _buildPdfUrl() {
    final date = _df.format(_selected);
    final uri = Uri.parse(ReportEndpoints.dailyPdf).replace(queryParameters: {
      "emp_code": _empCode,
      "token": _token,
      "date": date,
    });
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

  /// ✅ Proper Date picker without overflow issue (clamp text scale in dialog)
  Future<void> _pickDate() async {
    final initial = _selected;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        // ✅ clamp font scale inside picker to avoid overflow on some phones
        final mq = MediaQuery.of(context);
        final fixedMq = mq.copyWith(textScaler: const TextScaler.linear(1.0));

        return MediaQuery(
          data: fixedMq,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Colors.black,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked == null) return;

    setState(() => _selected = picked);
    _openWebView();
  }

  Future<void> _downloadPdf() async {
    if (_downloading) return;

    setState(() => _downloading = true);

    try {
      final url = _buildPdfUrl();
      final date = _df.format(_selected);

      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/Daily_Attendance_${_empCode}_$date.pdf");

      final dio = Dio(
        BaseOptions(
          receiveTimeout: const Duration(seconds: 60),
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
    final dateTxt = _df.format(_selected);

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
                  "Daily Report",
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
                  "Emp: $_empCode • Date: $dateTxt",
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
            onPressed: _pickDate,
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
