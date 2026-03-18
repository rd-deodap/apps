class ProductListVo {
  int? statusFlag;
  String? statusLabel;
  MetaData? metaData;
  List<Pro>? data;

  ProductListVo({this.statusFlag, this.statusLabel, this.metaData, this.data});

  ProductListVo.fromJson(Map<String, dynamic> json) {
    statusFlag = json['status_flag'];
    statusLabel = json['status_label'];
    metaData = json['meta_data'] != null
        ? new MetaData.fromJson(json['meta_data'])
        : null;
    if (json['data'] != null) {
      data = <Pro>[];
      json['data'].forEach((v) {
        data!.add(new Pro.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status_flag'] = this.statusFlag;
    data['status_label'] = this.statusLabel;
    if (this.metaData != null) {
      data['meta_data'] = this.metaData!.toJson();
    }
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class MetaData {
  Paging? paging;

  MetaData({this.paging});

  MetaData.fromJson(Map<String, dynamic> json) {
    paging =
        json['paging'] != null ? new Paging.fromJson(json['paging']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.paging != null) {
      data['paging'] = this.paging!.toJson();
    }
    return data;
  }
}

class Paging {
  int? pageNo;
  int? itemsPerPage;
  int? totalRecords;
  bool? hasNextPage;
  bool? hasPreviousPage;
  int? lastPage;

  Paging(
      {this.pageNo,
      this.itemsPerPage,
      this.totalRecords,
      this.hasNextPage,
      this.hasPreviousPage,
      this.lastPage});

  Paging.fromJson(Map<String, dynamic> json) {
    pageNo = json['page_no'];
    itemsPerPage = json['items_per_page'];
    totalRecords = json['total_records'];
    hasNextPage = json['has_next_page'];
    hasPreviousPage = json['has_previous_page'];
    lastPage = json['last_page'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['page_no'] = this.pageNo;
    data['items_per_page'] = this.itemsPerPage;
    data['total_records'] = this.totalRecords;
    data['has_next_page'] = this.hasNextPage;
    data['has_previous_page'] = this.hasPreviousPage;
    data['last_page'] = this.lastPage;
    return data;
  }
}

class Pro {
  int? id;
  String? sku;
  String? name;
  int? warehouseId;
  int? stock;
  int? stockReserveThreshold;
  int? workingStock;
  String? image;
  String? imageThumb;
  String? stockPhysicalLocation;
  String? stockPhysicalSubLocation;

  Pro(
      {this.id,
      this.sku,
      this.name,
      this.warehouseId,
      this.stock,
      this.stockReserveThreshold,
      this.workingStock,
      this.image,
      this.imageThumb,
      this.stockPhysicalLocation,
      this.stockPhysicalSubLocation});

  Pro.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    sku = json['sku'];
    name = json['name'];
    warehouseId = json['warehouse_id'];
    stock = json['stock'];
    stockReserveThreshold = json['stock_reserve_threshold'];
    workingStock = json['working_stock'];
    image = json['image'];
    imageThumb = json['image_thumb'];
    stockPhysicalLocation = json['stock_physical_location'];
    stockPhysicalSubLocation = json['stock_physical_sub_location'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['sku'] = this.sku;
    data['name'] = this.name;
    data['warehouse_id'] = this.warehouseId;
    data['stock'] = this.stock;
    data['stock_reserve_threshold'] = this.stockReserveThreshold;
    data['working_stock'] = this.workingStock;
    data['image'] = this.image;
    data['image_thumb'] = this.imageThumb;
    data['stock_physical_location'] = this.stockPhysicalLocation;
    data['stock_physical_sub_location'] = this.stockPhysicalSubLocation;
    return data;
  }
}
