class PendingOrderVO {
  bool? success;
  Data? data;
  String? message;

  PendingOrderVO({this.success, this.data, this.message});

  PendingOrderVO.fromJson(Map<String, dynamic> json) {
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
  List<PendingOrders>? orders;
  Pagination? pagination;

  Data({this.orders, this.pagination});

  Data.fromJson(Map<String, dynamic> json) {
    if (json['orders'] != null) {
      orders = <PendingOrders>[];
      json['orders'].forEach((v) {
        orders!.add(new PendingOrders.fromJson(v));
      });
    }
    pagination = json['pagination'] != null
        ? new Pagination.fromJson(json['pagination'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.orders != null) {
      data['orders'] = this.orders!.map((v) => v.toJson()).toList();
    }
    if (this.pagination != null) {
      data['pagination'] = this.pagination!.toJson();
    }
    return data;
  }
}

class PendingOrders {
  int? id;
  String? orderNo;
  String? orderDate;
  String? awb;
  String? orderStatus;
  int? warehouseId;
  String? courierSlug;
  Warehouses? warehouses;

  PendingOrders(
      {this.id,
        this.orderNo,
        this.orderDate,
        this.awb,
        this.orderStatus,
        this.warehouseId,
        this.courierSlug,
        this.warehouses});

  PendingOrders.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    orderNo = json['order_no'];
    orderDate = json['order_date'];
    awb = json['awb'];
    orderStatus = json['order_status'];
    warehouseId = json['warehouse_id'];
    courierSlug = json['courier_slug'];
    warehouses = json['warehouses'] != null
        ? new Warehouses.fromJson(json['warehouses'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['order_no'] = this.orderNo;
    data['order_date'] = this.orderDate;
    data['awb'] = this.awb;
    data['order_status'] = this.orderStatus;
    data['warehouse_id'] = this.warehouseId;
    data['courier_slug'] = this.courierSlug;
    if (this.warehouses != null) {
      data['warehouses'] = this.warehouses!.toJson();
    }
    return data;
  }
}

class Warehouses {
  int? id;
  String? label;

  Warehouses({this.id, this.label});

  Warehouses.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    label = json['label'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['label'] = this.label;
    return data;
  }
}

class Pagination {
  int? pageNo;
  int? itemsPerPage;
  bool? hasNextPage;
  bool? hasPreviousPage;
  int? totalRecords;
  int? lastPage;

  Pagination(
      {this.pageNo,
        this.itemsPerPage,
        this.hasNextPage,
        this.hasPreviousPage,
        this.totalRecords,
        this.lastPage});

  Pagination.fromJson(Map<String, dynamic> json) {
    pageNo = json['page_no'];
    itemsPerPage = json['items_per_page'];
    hasNextPage = json['has_next_page'];
    hasPreviousPage = json['has_previous_page'];
    totalRecords = json['total_records'];
    lastPage = json['last_page'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['page_no'] = this.pageNo;
    data['items_per_page'] = this.itemsPerPage;
    data['has_next_page'] = this.hasNextPage;
    data['has_previous_page'] = this.hasPreviousPage;
    data['total_records'] = this.totalRecords;
    data['last_page'] = this.lastPage;
    return data;
  }
}
