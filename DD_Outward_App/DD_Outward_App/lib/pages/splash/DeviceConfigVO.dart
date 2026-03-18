class DeviceConfigVO {
  String? status;
  String? message;
  Data? data;

  DeviceConfigVO({this.status, this.message, this.data});

  DeviceConfigVO.fromJson(Map<String, dynamic> json) {
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
  int? id;
  int? warehouseId;
  String? name;
  String? brandName;
  String? version;
  String? assetsBaseUrl;
  String? pixelTrackingId;
  String? googleAnalyticsTrackingId;
  int? isOffline;
  String? token;

  Data(
      {this.id,
      this.warehouseId,
      this.name,
      this.brandName,
      this.version,
      this.assetsBaseUrl,
      this.pixelTrackingId,
      this.googleAnalyticsTrackingId,
      this.isOffline,
      this.token});

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    warehouseId = json['warehouse_id'];
    name = json['name'];
    brandName = json['brand_name'];
    version = json['version'];
    assetsBaseUrl = json['assets_base_url'];
    pixelTrackingId = json['pixel_tracking_id'];
    googleAnalyticsTrackingId = json['google_analytics_tracking_id'];
    isOffline = json['is_offline'];
    token = json['token'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['warehouse_id'] = this.warehouseId;
    data['name'] = this.name;
    data['brand_name'] = this.brandName;
    data['version'] = this.version;
    data['assets_base_url'] = this.assetsBaseUrl;
    data['pixel_tracking_id'] = this.pixelTrackingId;
    data['google_analytics_tracking_id'] = this.googleAnalyticsTrackingId;
    data['is_offline'] = this.isOffline;
    data['token'] = this.token;
    return data;
  }
}
