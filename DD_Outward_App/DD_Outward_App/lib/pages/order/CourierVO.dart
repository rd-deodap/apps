class CourierVO {
  bool? success;
  List<Courier>? data;
  String? message;

  CourierVO({this.success, this.data, this.message});

  CourierVO.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    if (json['data'] != null) {
      data = <Courier>[];
      json['data'].forEach((v) {
        data!.add(new Courier.fromJson(v));
      });
    }
    message = json['message'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['success'] = this.success;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    data['message'] = this.message;
    return data;
  }
}

class Courier {
  int? id;
  String? name;
  String? shippingLogo;
  String? logoPath;

  Courier({this.id, this.name, this.shippingLogo, this.logoPath});

  Courier.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    shippingLogo = json['shipping_logo'];
    logoPath = json['logo_path'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    data['shipping_logo'] = this.shippingLogo;
    data['logo_path'] = this.logoPath;
    return data;
  }
}
