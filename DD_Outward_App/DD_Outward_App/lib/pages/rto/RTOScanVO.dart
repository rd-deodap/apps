class RTOScanVO {
  bool? success;
  Data? data;
  String? message;

  RTOScanVO({this.success, this.data, this.message});

  RTOScanVO.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    data = json['data'] != null ? new Data.fromJson(json['data']) : null;
    message = json['message'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['success'] = this.success;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    data['message'] = this.message;
    return data;
  }
}

class Data {
  int? orderId;
  String? awb;
  String? errors;
  int? scanByUserId;
  String? scanAt;
  String? id;
  String? updatedAt;
  String? createdAt;

  Data(
      {this.orderId,
      this.awb,
      this.errors,
      this.scanByUserId,
      this.scanAt,
      this.id,
      this.updatedAt,
      this.createdAt});

  Data.fromJson(Map<String, dynamic> json) {
    orderId = json['order_id'];
    awb = json['awb'];
    errors = json['errors'];
    scanByUserId = json['scan_by_user_id'];
    scanAt = json['scan_at'];
    id = json['id'];
    updatedAt = json['updated_at'];
    createdAt = json['created_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['order_id'] = this.orderId;
    data['awb'] = this.awb;
    data['errors'] = this.errors;
    data['scan_by_user_id'] = this.scanByUserId;
    data['scan_at'] = this.scanAt;
    data['id'] = this.id;
    data['updated_at'] = this.updatedAt;
    data['created_at'] = this.createdAt;
    return data;
  }
}
