class CommonDropDownVO {
  List<Commons>? data;
  bool? success;
  String? message;

  CommonDropDownVO({this.data, this.success, this.message});

  CommonDropDownVO.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <Commons>[];
      json['data'].forEach((v) {
        data!.add(new Commons.fromJson(v));
      });
    }
    success = json['success'];
    message = json['message'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    data['success'] = this.success;
    data['message'] = this.message;
    return data;
  }
}

class Commons {
  String? id;
  String? label;

  Commons({this.id, this.label});

  /*Commons.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    label = json['label'];
  }*/

  factory Commons.fromJson(Map<String, dynamic> json) {
    return Commons(
      id: json['id'].toString(), // Convert int to String
      label: json['label'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['label'] = this.label;
    return data;
  }
}
