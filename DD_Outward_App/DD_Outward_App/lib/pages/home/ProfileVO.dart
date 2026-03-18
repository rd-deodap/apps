class ProfileVO {
  int? statusFlag;
  String? statusLabel;
  List<String>? statusMessages;
  Data? data;

  ProfileVO(
      {this.statusFlag, this.statusLabel, this.statusMessages, this.data});

  ProfileVO.fromJson(Map<String, dynamic> json) {
    statusFlag = json['status_flag'];
    statusLabel = json['status_label'];
    statusMessages = json['status_messages'].cast<String>();
    data = json['data'] != null ? new Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status_flag'] = this.statusFlag;
    data['status_label'] = this.statusLabel;
    data['status_messages'] = this.statusMessages;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class Data {
  User? user;
  List<String>? stockPhysicalLocations;

  Data({this.user, this.stockPhysicalLocations});

  Data.fromJson(Map<String, dynamic> json) {
    user = json['user'] != null ? new User.fromJson(json['user']) : null;
    stockPhysicalLocations = json['stock_physical_locations'].cast<String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.user != null) {
      data['user'] = this.user!.toJson();
    }
    data['stock_physical_locations'] = this.stockPhysicalLocations;
    return data;
  }
}

class User {
  int? id;
  int? warehouseId;
  String? name;
  String? email;
  String? phone;
  int? isActive;

  User(
      {this.id,
      this.warehouseId,
      this.name,
      this.email,
      this.phone,
      this.isActive});

  User.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    warehouseId = json['warehouse_id'];
    name = json['name'];
    email = json['email'];
    phone = json['phone'];
    isActive = json['is_active'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['warehouse_id'] = this.warehouseId;
    data['name'] = this.name;
    data['email'] = this.email;
    data['phone'] = this.phone;
    data['is_active'] = this.isActive;
    return data;
  }
}
