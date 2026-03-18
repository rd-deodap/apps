class OrderInfoVO {
  bool? success;
  Data? data;
  var message;

  OrderInfoVO({this.success, this.data, this.message});

  OrderInfoVO.fromJson(Map<String, dynamic> json) {
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
  List<Orders>? orders;
  Pagination? pagination;

  Data({this.orders, this.pagination});

  Data.fromJson(Map<String, dynamic> json) {
    if (json['orders'] != null) {
      orders = <Orders>[];
      json['orders'].forEach((v) {
        orders!.add(new Orders.fromJson(v));
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

class Orders {
  var id;
  var orderId;
  var warehouseId;
  var isPortalOrder;
  var awb;
  var courierSlug;
  var scanDate;
  var scanByUserId;
  Order? order;
  ScanByUser? scanByUser;
  List<OutwardMedias>? outwardMedias;
  Warehouse? warehouse;

  Orders(
      {this.id,
        this.orderId,
        this.warehouseId,
        this.isPortalOrder,
        this.awb,
        this.courierSlug,
        this.scanDate,
        this.scanByUserId,
        this.order,
        this.scanByUser,
        this.outwardMedias,
        this.warehouse});

  Orders.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    orderId = json['order_id'];
    warehouseId = json['warehouse_id'];
    isPortalOrder = json['is_portal_order'];
    awb = json['awb'];
    courierSlug = json['courier_slug'];
    scanDate = json['scan_date'];
    scanByUserId = json['scan_by_user_id'];
    order = json['order'] != null ? new Order.fromJson(json['order']) : null;
    scanByUser = json['scan_by_user'] != null
        ? new ScanByUser.fromJson(json['scan_by_user'])
        : null;
    if (json['outward_medias'] != null) {
      outwardMedias = <OutwardMedias>[];
      json['outward_medias'].forEach((v) {
        outwardMedias!.add(new OutwardMedias.fromJson(v));
      });
    }
    warehouse = json['warehouse'] != null
        ? new Warehouse.fromJson(json['warehouse'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['order_id'] = this.orderId;
    data['warehouse_id'] = this.warehouseId;
    data['is_portal_order'] = this.isPortalOrder;
    data['awb'] = this.awb;
    data['courier_slug'] = this.courierSlug;
    data['scan_date'] = this.scanDate;
    data['scan_by_user_id'] = this.scanByUserId;
    if (this.order != null) {
      data['order'] = this.order!.toJson();
    }
    if (this.scanByUser != null) {
      data['scan_by_user'] = this.scanByUser!.toJson();
    }
    if (this.outwardMedias != null) {
      data['outward_medias'] =
          this.outwardMedias!.map((v) => v.toJson()).toList();
    }
    if (this.warehouse != null) {
      data['warehouse'] = this.warehouse!.toJson();
    }
    return data;
  }
}

class Order {
  var id;
  var orderNo;

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
  var name;

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

class Warehouse {
  var id;
  var label;

  Warehouse({this.id, this.label});

  Warehouse.fromJson(Map<String, dynamic> json) {
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
class OutwardMedias {
  var id;
  var orderOutwardId;
  var imageName;
  var imagePath;

  OutwardMedias({this.id, this.orderOutwardId, this.imageName, this.imagePath});

  OutwardMedias.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    orderOutwardId = json['order_outward_id'];
    imageName = json['image_name'];
    imagePath = json['image_path'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['order_outward_id'] = this.orderOutwardId;
    data['image_name'] = this.imageName;
    data['image_path'] = this.imagePath;
    return data;
  }
}
class Pagination {
  var pageNo;
  var itemsPerPage;
  bool? hasNextPage;
  bool? hasPreviousPage;
  var totalRecords;
  var lastPage;

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
