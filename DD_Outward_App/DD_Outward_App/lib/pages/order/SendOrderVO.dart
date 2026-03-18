class SendOrderVO {
  String? status;
  String? message;
  Data? data;

  SendOrderVO({this.status, this.message, this.data});

  SendOrderVO.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    data = json['data'] != null ? new Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    data['message'] = this.message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class Data {
  OrderInfo? orderInfo;
  PackagingInfo? packagingInfo;

  Data({this.orderInfo, this.packagingInfo});

  Data.fromJson(Map<String, dynamic> json) {
    orderInfo = json['order_info'] != null
        ? new OrderInfo.fromJson(json['order_info'])
        : null;
    packagingInfo = json['packaging_info'] != null
        ? new PackagingInfo.fromJson(json['packaging_info'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.orderInfo != null) {
      data['order_info'] = this.orderInfo!.toJson();
    }
    if (this.packagingInfo != null) {
      data['packaging_info'] = this.packagingInfo!.toJson();
    }
    return data;
  }
}

class OrderInfo {
  String? orderNo;
  String? status;
  String? statusColor;
  String? statusColorCode;
  String? createdAt;
  String? total;
  String? buyerName;
  String? buyerPhone;
  String? buyerCity;

  OrderInfo(
      {this.orderNo,
      this.status,
      this.statusColor,
      this.statusColorCode,
      this.createdAt,
      this.total,
      this.buyerName,
      this.buyerPhone,
      this.buyerCity});

  OrderInfo.fromJson(Map<String, dynamic> json) {
    orderNo = json['order_no'];
    status = json['status'];
    statusColor = json['status_color'];
    statusColorCode = json['status_color_code'];
    createdAt = json['created_at'];
    total = json['total'];
    buyerName = json['buyer_name'];
    buyerPhone = json['buyer_phone'];
    buyerCity = json['buyer_city'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['order_no'] = this.orderNo;
    data['status'] = this.status;
    data['status_color'] = this.statusColor;
    data['status_color_code'] = this.statusColorCode;
    data['created_at'] = this.createdAt;
    data['total'] = this.total;
    data['buyer_name'] = this.buyerName;
    data['buyer_phone'] = this.buyerPhone;
    data['buyer_city'] = this.buyerCity;
    return data;
  }
}

class PackagingInfo {
  String? attachment1;
  String? attachment2;
  int? shipmentPackagesCount;
  String? packagingStaffCode;
  String? packagingStaffName;

  PackagingInfo(
      {this.attachment1,
      this.attachment2,
      this.shipmentPackagesCount,
      this.packagingStaffCode,
      this.packagingStaffName});

  PackagingInfo.fromJson(Map<String, dynamic> json) {
    attachment1 = json['attachment1'];
    attachment2 = json['attachment2'];
    shipmentPackagesCount = json['shipment_packages_count'];
    packagingStaffCode = json['packaging_staff_code'];
    packagingStaffName = json['packaging_staff_name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['attachment1'] = this.attachment1;
    data['attachment2'] = this.attachment2;
    data['shipment_packages_count'] = this.shipmentPackagesCount;
    data['packaging_staff_code'] = this.packagingStaffCode;
    data['packaging_staff_name'] = this.packagingStaffName;
    return data;
  }
}
