class LoginVo {
  bool? success;
  Data? data;
  var message;

  LoginVo({this.success, this.data, this.message});

  LoginVo.fromJson(Map<String, dynamic> json) {
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
  var token;
  User? user;
  var expiresInMinutes;

  Data({this.token, this.user, this.expiresInMinutes});

  Data.fromJson(Map<String, dynamic> json) {
    token = json['token'];
    user = json['user'] != null ? new User.fromJson(json['user']) : null;
    expiresInMinutes = json['expires_in_minutes'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['token'] = this.token;
    if (this.user != null) {
      data['user'] = this.user!.toJson();
    }
    data['expires_in_minutes'] = this.expiresInMinutes;
    return data;
  }
}

class User {
  var id;
  var warehouseId;
  var name;
  var email;
  var emailVerifiedAt;
  var inActive;
  var userPhoto;
  var userEnv;
  var appToken;
  var createdAt;
  var updatedAt;

  User(
      {this.id,
        this.warehouseId,
        this.name,
        this.email,
        this.emailVerifiedAt,
        this.inActive,
        this.userPhoto,
        this.userEnv,
        this.appToken,
        this.createdAt,
        this.updatedAt});

  User.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    warehouseId = json['warehouse_id'];
    name = json['name'];
    email = json['email'];
    emailVerifiedAt = json['email_verified_at'];
    inActive = json['in_active'];
    userPhoto = json['user_photo'];
    userEnv = json['user_env'];
    appToken = json['app_token'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['warehouse_id'] = this.warehouseId;
    data['name'] = this.name;
    data['email'] = this.email;
    data['email_verified_at'] = this.emailVerifiedAt;
    data['in_active'] = this.inActive;
    data['user_photo'] = this.userPhoto;
    data['user_env'] = this.userEnv;
    data['app_token'] = this.appToken;
    data['created_at'] = this.createdAt;
    data['updated_at'] = this.updatedAt;
    return data;
  }
}
