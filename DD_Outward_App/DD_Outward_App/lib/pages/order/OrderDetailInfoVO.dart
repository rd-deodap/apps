class OrderDetailInfoVO {
  var errors;
  var status;
  Data? data;

  OrderDetailInfoVO({this.errors, this.status, this.data});

  OrderDetailInfoVO.fromJson(Map<String, dynamic> json) {
    errors = json['errors'];
    status = json['status'];
    data = json['data'] != null ? new Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['errors'] = this.errors;
    data['status'] = this.status;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class Data {
  OrderTable? orderTable;
  List<ImgesTable>? imgesTable;

  Data({this.orderTable, this.imgesTable});

  Data.fromJson(Map<String, dynamic> json) {
    orderTable = json['order_table'] != null
        ? new OrderTable.fromJson(json['order_table'])
        : null;
    if (json['imges_table'] != null) {
      imgesTable = <ImgesTable>[];
      json['imges_table'].forEach((v) {
        imgesTable!.add(new ImgesTable.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.orderTable != null) {
      data['order_table'] = this.orderTable!.toJson();
    }
    if (this.imgesTable != null) {
      data['imges_table'] = this.imgesTable!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class OrderTable {
  var orderId;
  var inwardDate;
  var trackingId;
  var outwardDate;

  OrderTable(
      {this.orderId, this.inwardDate, this.trackingId, this.outwardDate});

  OrderTable.fromJson(Map<String, dynamic> json) {
    orderId = json['order_id'];
    inwardDate = json['inward_date'];
    trackingId = json['tracking_id'];
    outwardDate = json['outward_date'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['order_id'] = this.orderId;
    data['inward_date'] = this.inwardDate;
    data['tracking_id'] = this.trackingId;
    data['outward_date'] = this.outwardDate;
    return data;
  }
}

class ImgesTable {
  var imageName;
  var imageDate;

  ImgesTable({this.imageName, this.imageDate});

  ImgesTable.fromJson(Map<String, dynamic> json) {
    imageName = json['image_name'];
    imageDate = json['image_date'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['image_name'] = this.imageName;
    data['image_date'] = this.imageDate;
    return data;
  }
}
