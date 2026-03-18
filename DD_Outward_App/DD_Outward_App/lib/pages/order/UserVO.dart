class UserVO {
  bool? success;
  List<User>? data;
  String? message;

  UserVO({this.success, this.data, this.message});

  UserVO.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    if (json['data'] != null) {
      data = <User>[];
      json['data'].forEach((v) {
        data!.add(new User.fromJson(v));
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

class User {
  int? id;
  String? label;
  String? name;

  User({this.id, this.label, this.name});

  User.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    label = json['label'];
    name = json['name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['label'] = this.label;
    data['name'] = this.name;
    return data;
  }
}
