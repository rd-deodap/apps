class ScanAWBVO {
  bool? success;
  Data? data;
  var message;

  ScanAWBVO({this.success, this.data, this.message});

  ScanAWBVO.fromJson(Map<String, dynamic> json) {
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
  var id;
  var orderId;
  var isPortalOrder;
  var awb;
  var errors;
  var courierSlug;
  var scanDate;
  var scanByUserId;
  Order? order;
  ScanByUser? scanByUser;
  Data(
      {this.id,
        this.orderId,
        this.isPortalOrder,
        this.awb,
        this.courierSlug,
        this.scanDate,
        this.errors,
        this.scanByUserId,
        this.order,
        this.scanByUser});

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    orderId = json['order_id'];
    isPortalOrder = json['is_portal_order'];
    awb = json['awb'];
    courierSlug = json['courier_slug'];
    scanDate = json['scan_date'];
    scanByUserId = json['scan_by_user_id'];
    order = json['order'] != null ? new Order.fromJson(json['order']) : null;
    scanByUser = json['scan_by_user'] != null
        ? new ScanByUser.fromJson(json['scan_by_user'])
        : null;
    errors = json['errors'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['order_id'] = this.orderId;
    data['is_portal_order'] = this.isPortalOrder;
    data['awb'] = this.awb;
    data['courier_slug'] = this.courierSlug;
    data['scan_date'] = this.scanDate;
    data['scan_by_user_id'] = this.scanByUserId;
    data['errors'] = this.errors;
    data['order'] = this.order;
    if (this.scanByUser != null) {
      data['scan_by_user'] = this.scanByUser!.toJson();
    }
    return data;
  }
}

class Order {
  var id;
  String? orderNo;

  Order({this.id, this.orderNo});

  Order.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    orderNo = json['order_no'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['order_no'] = this.orderNo;
    return data;
  }
}

class ScanByUser {
  var id;
  String? name;

  ScanByUser({this.id, this.name});

  ScanByUser.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    return data;
  }
}
