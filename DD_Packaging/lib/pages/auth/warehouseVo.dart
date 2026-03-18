class WarehouseVo {
  String? status;
  String? message;
  List<Logins> data = const <Logins>[];

  WarehouseVo({this.status, this.message, this.data = const <Logins>[]});

  WarehouseVo.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    if (json['data'] != null) {
      data = <Logins>[];
      json['data'].forEach((v) {
        data!.add(new Logins.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['status'] = this.status;
    data['message'] = this.message;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Logins {
  int? id;
  String? label;

  Logins({this.id, this.label});

  Logins.fromJson(Map<String, dynamic> json) {
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
