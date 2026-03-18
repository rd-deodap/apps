import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PunchReportScreen extends StatefulWidget {
  const PunchReportScreen({super.key});

  @override
  State<PunchReportScreen> createState() => _PunchReportScreenState();
}

class _PunchReportScreenState extends State<PunchReportScreen> {
  bool loading = true;
  String? error;
  List<dynamic> rows = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final empCode = sp.getString("emp_code") ?? "";
      final token = sp.getString("token") ?? "";

      // SAMPLE API URL
      final res = await http.post(
        Uri.parse("https://deodap.com/api/attendance_report.php"),
        body: {
          "emp_code": empCode,
          "token": token,
          "from_date": "2026-01-01",
          "to_date": "2026-01-31",
        },
      );

      final jsonRes = json.decode(res.body);

      if (jsonRes["ok"] != true) {
        setState(() => error = jsonRes["error"]);
        return;
      }

      setState(() {
        rows = jsonRes["data"]["rows"] ?? [];
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Attendance Report")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, i) {
          final r = rows[i];
          return ListTile(
            title: Text(r["attendance_date"]),
            subtitle: Text(
              "Work: ${r["total_work_time"]} | OT: ${r["ot_time"]}",
            ),
            trailing: Text(r["status"]),
          );
        },
      ),
    );
  }
}
