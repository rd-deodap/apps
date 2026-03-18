class UpdatePhotoVO {
  bool? success;
  Data? data;
  String? message;

  UpdatePhotoVO({this.success, this.data, this.message});

  UpdatePhotoVO.fromJson(Map<String, dynamic> json) {
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
  String? id;
  String? orderNo;
  String? awb;
  String? imagePath;
  String? errors;

  Data({this.id, this.orderNo, this.awb, this.imagePath,this.errors});

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    orderNo = json['order_no'];
    awb = json['awb'];
    errors = json['errors'];
    imagePath = json['image_path'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['order_no'] = this.orderNo;
    data['awb'] = this.awb;
    data['errors'] = this.errors;
    data['image_path'] = this.imagePath;
    return data;
  }
}
