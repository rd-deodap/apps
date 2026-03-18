class ProfileVO {
  String? status;
  String? message;
  Data? data;

  ProfileVO({this.status, this.message, this.data});

  ProfileVO.fromJson(Map<String, dynamic> json) {
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
  String? code;
  String? name;
  String? phone;

  Data({this.id, this.warehouseId, this.code, this.name, this.phone});

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    warehouseId = json['warehouse_id'];
    code = json['code'];
    name = json['name'];
    phone = json['phone'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['warehouse_id'] = this.warehouseId;
    data['code'] = this.code;
    data['name'] = this.name;
    data['phone'] = this.phone;
    return data;
  }
}
