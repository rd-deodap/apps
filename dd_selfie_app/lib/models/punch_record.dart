/// Model for employee punch records from the dashboard API
class PunchRecord {
  final int? id;
  final String? employeeCode;
  final String? name;
  final String? date;
  final String? intime;
  final String? outtime;
  final String? worktime;
  final String? overtime;
  final String? breaktime;
  final String? remark;
  final String? verifiedByEmployeeId;
  final String? note;
  final String? proof;
  final String? erlOut;
  final String? lateIn;
  final String? status;
  final String? mFlag;
  final String? metaAttendanceStatus;
  final String? metaIsCalculated;
  final String? metaReceivedFrom;
  final String? createdAt;
  final String? updatedAt;

  const PunchRecord({
    this.id,
    this.employeeCode,
    this.name,
    this.date,
    this.intime,
    this.outtime,
    this.worktime,
    this.overtime,
    this.breaktime,
    this.remark,
    this.verifiedByEmployeeId,
    this.note,
    this.proof,
    this.erlOut,
    this.lateIn,
    this.status,
    this.mFlag,
    this.metaAttendanceStatus,
    this.metaIsCalculated,
    this.metaReceivedFrom,
    this.createdAt,
    this.updatedAt,
  });

  factory PunchRecord.fromJson(Map<String, dynamic> json) {
    return PunchRecord(
      id: json['id'] as int?,
      employeeCode: json['employee_code']?.toString(),
      name: json['name']?.toString(),
      date: json['date']?.toString(),
      intime: json['intime']?.toString(),
      outtime: json['outtime']?.toString(),
      worktime: json['worktime']?.toString(),
      overtime: json['overtime']?.toString(),
      breaktime: json['breaktime']?.toString(),
      remark: json['remark']?.toString(),
      verifiedByEmployeeId: json['verified_by_employee_id']?.toString(),
      note: json['note']?.toString(),
      proof: json['proof']?.toString(),
      erlOut: json['erl_out']?.toString(),
      lateIn: json['late_in']?.toString(),
      status: json['status']?.toString(),
      mFlag: json['m_flag']?.toString(),
      metaAttendanceStatus: json['meta_attendance_status']?.toString(),
      metaIsCalculated: json['meta_is_calculated']?.toString(),
      metaReceivedFrom: json['meta_received_From']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  String displayValue(String? value) {
    if (value == null || value.isEmpty || value == 'null') return '-';
    return value;
  }
}

/// Response from the dashboard API
class DashboardResponse {
  final bool ok;
  final String employeeCode;
  final String? date;
  final int count;
  final List<PunchRecord> data;
  final String? error;

  const DashboardResponse({
    required this.ok,
    required this.employeeCode,
    this.date,
    required this.count,
    required this.data,
    this.error,
  });

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    final dataList = (json['data'] as List?)
        ?.map((e) => PunchRecord.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];

    return DashboardResponse(
      ok: json['ok'] == true,
      employeeCode: json['employee_code']?.toString() ?? '',
      date: json['date']?.toString(),
      count: json['count'] as int? ?? 0,
      data: dataList,
      error: json['error']?.toString(),
    );
  }
}
