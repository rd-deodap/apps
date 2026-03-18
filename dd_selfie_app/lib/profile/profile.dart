import 'package:dd_selfie_app/home/home_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Use same keys as your LoginPage
class SessionKeys {
  static const String token = "token";
  static const String empCode = "emp_code";
  static const String name = "name"; // optional
}

/// ===============================
/// API CONFIG
/// ===============================
class ProfileApiConfig {
  static const String fetchUrl =
      "https://staff.deodap.in/api/admin/getuserdetail";

  /// Update endpoint
  static const String updateUrl =
      "https://staff.deodap.in/api/admin/updateuserdetail";

  static const Duration timeout = Duration(seconds: 25);
}

/// ===============================
/// MODEL
/// ===============================
class UserProfile {
  final String empCode;

  final String? fullName;
  final String? name;
  final String? middleName;
  final String? surname;
  final String? mobileNo;
  final String? email;

  final String? address;
  final String? currentAddress;
  final String? city;
  final String? state;
  final String? pincode;

  final String? mobilePersonal;
  final String? mobileCompany;
  final String? relationName;

  final String? gender;
  final String? dob;
  final String? interviewDate;
  final String? joinDate;
  final String? skills;
  final String? designationName;
  final String? workLocationName;
  final List<String> departments;

  final String? bankAccountName;
  final String? bankName;
  final String? bankBranchName;
  final String? bankAccountNo;
  final String? bankIfsc;

  final String? remark;

  // Base location (we will hide lat/lng on UI)
  final double? baseLat;
  final double? baseLng;
  final String? baseLocationAddress;
  final String? baseLocationSetAt;

  // paths
  final String? profileImagePath;
  final String? profileSelfiePath; // kept for parsing, but NOT shown in UI
  final String? aadharFrontPath;
  final String? aadharBackPath;

  final bool? isPasswordChanged;
  final bool? isActive;

  final String? profileUpdatedAt;
  final String? createdAt;
  final String? updatedAt;

  /// image_urls from API (already absolute)
  final Map<String, String> imageUrls;

  const UserProfile({
    required this.empCode,
    required this.imageUrls,
    this.fullName,
    this.name,
    this.middleName,
    this.surname,
    this.mobileNo,
    this.email,
    this.address,
    this.currentAddress,
    this.city,
    this.state,
    this.pincode,
    this.mobilePersonal,
    this.mobileCompany,
    this.relationName,
    this.gender,
    this.dob,
    this.interviewDate,
    this.joinDate,
    this.skills,
    this.designationName,
    this.workLocationName,
    this.departments = const [],
    this.bankAccountName,
    this.bankName,
    this.bankBranchName,
    this.bankAccountNo,
    this.bankIfsc,
    this.remark,
    this.baseLat,
    this.baseLng,
    this.baseLocationAddress,
    this.baseLocationSetAt,
    this.profileImagePath,
    this.profileSelfiePath,
    this.aadharFrontPath,
    this.aadharBackPath,
    this.isPasswordChanged,
    this.isActive,
    this.profileUpdatedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromApi({
    required String empCode,
    required Map<String, dynamic> data,
    required Map<String, dynamic> imageUrls,
  }) {
    double? _d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return double.tryParse(s);
    }

    bool? _b(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      if (v is num) return v.toInt() == 1;
      final s = v.toString().trim().toLowerCase();
      if (s.isEmpty) return null;
      if (s == "1" || s == "true" || s == "yes") return true;
      if (s == "0" || s == "false" || s == "no") return false;
      return null;
    }

    String? _s(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    String? _gender(dynamic v) {
      if (v == null) return null;
      if (v is num) {
        if (v.toInt() == 0) return "Male";
        if (v.toInt() == 1) return "Female";
        if (v.toInt() == 2) return "Other";
      }
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      final l = s.toLowerCase();
      if (l == "0" || l == "male") return "Male";
      if (l == "1" || l == "female") return "Female";
      if (l == "2" || l == "other") return "Other";
      return s;
    }

    String? _pickStr(List<String> keys) {
      for (final k in keys) {
        final v = _s(data[k]);
        if (v != null) return v;
      }
      return null;
    }

    final urls = <String, String>{};
    imageUrls.forEach((k, v) {
      if (v == null) return;
      final s = v.toString().trim();
      if (s.isNotEmpty) urls[k] = s;
    });

    // Support the newer user payload image keys.
    final profileUrl = _s(data["image_url"]);
    final idFrontUrl = _s(data["id_proof_url"]);
    final idBackUrl = _s(data["id_proof_backside_url"]);
    if (profileUrl != null && !urls.containsKey("profile_image")) {
      urls["profile_image"] = profileUrl;
    }
    if (idFrontUrl != null && !urls.containsKey("aadhar_front")) {
      urls["aadhar_front"] = idFrontUrl;
    }
    if (idBackUrl != null && !urls.containsKey("aadhar_back")) {
      urls["aadhar_back"] = idBackUrl;
    }

    final firstName = _s(data["name"]);
    final middleName = _s(data["middle_name"]);
    final surName = _s(data["surname"]);
    final designation = (data["designation"] is Map)
        ? (data["designation"] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final worklocation = (data["worklocation"] is Map)
        ? (data["worklocation"] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final departmentsRaw = (data["departments"] is List)
        ? data["departments"] as List
        : const [];
    final departmentNames = departmentsRaw
        .map((e) {
          if (e is Map) return _s(e["name"]);
          return null;
        })
        .whereType<String>()
        .toList(growable: false);
    final mergedName = [
      firstName,
      middleName,
      surName,
    ].where((x) => (x ?? "").trim().isNotEmpty).join(" ").trim();
    final profileCode = _pickStr(["code", "emp_code"]) ?? empCode;

    return UserProfile(
      empCode: profileCode,
      imageUrls: urls,
      fullName:
          _pickStr(["full_name"]) ?? (mergedName.isEmpty ? null : mergedName),
      name: _pickStr(["name"]),
      middleName: _s(data["middle_name"]),
      surname: _s(data["surname"]),
      mobileNo: _pickStr(["mobile_no", "phone3", "phone2", "phone"]),
      email: _s(data["email"]),
      address: _pickStr(["address", "permanent_address"]),
      currentAddress: _pickStr(["current_address", "permanent_address"]),
      city: _s(data["city"]),
      state: _s(data["state"]),
      pincode: _s(data["pincode"]),
      mobilePersonal: _pickStr([
        "mobile_personal",
        "phone2",
        "phone3",
        "phone",
      ]),
      mobileCompany: _pickStr(["mobile_company", "phone"]),
      relationName: _s(data["relation_name"]),
      gender: _gender(data["gender"]),
      dob: _s(data["dob"]),
      interviewDate: _s(data["interview_date"]),
      joinDate: _s(data["join_date"]),
      skills: _s(data["skills"]),
      designationName: _s(designation["name"]),
      workLocationName: _s(worklocation["name"]),
      departments: departmentNames,
      bankAccountName: _pickStr(["bank_account_name", "account_name"]),
      bankName: _s(data["bank_name"]),
      bankBranchName: _pickStr(["bank_branch_name", "branch_name"]),
      bankAccountNo: _pickStr(["bank_account_no", "account_no"]),
      bankIfsc: _pickStr(["bank_ifsc", "ifsc"]),
      remark: _pickStr(["remark", "remarks"]),
      baseLat: _d(data["base_lat"]),
      baseLng: _d(data["base_lng"]),
      baseLocationAddress: _s(data["base_location_address"]),
      baseLocationSetAt: _s(data["base_location_set_at"]),
      profileImagePath: _pickStr(["profile_image_path", "img"]),
      profileSelfiePath: _s(data["profile_selfie_path"]),
      aadharFrontPath: _pickStr(["aadhar_front", "id_proof"]),
      aadharBackPath: _pickStr(["aadhar_back", "id_proof_backside"]),
      isPasswordChanged: _b(data["is_password_changed"]),
      isActive: _b(data["is_active"]) ?? _b(data["status"]),
      profileUpdatedAt: _pickStr(["profile_updated_at", "updated_at"]),
      createdAt: _s(data["created_at"]),
      updatedAt: _s(data["updated_at"]),
    );
  }

  String? get displayName {
    final t = (fullName ?? name ?? "").trim();
    return t.isEmpty ? null : t;
  }

  String? get departmentsText {
    if (departments.isEmpty) return null;
    return departments.join(", ");
  }
}

/// ===============================
/// ERROR PARSER (User-friendly)
/// ===============================
class FriendlyError {
  static String fromException(Object e) {
    final raw = e.toString().replaceFirst("Exception:", "").trim();
    final idx = raw.indexOf(":");
    if (idx > 0 && idx < 25) {
      final msg = raw.substring(idx + 1).trim();
      if (msg.isNotEmpty) return msg;
    }
    if (raw.isEmpty) return "Something went wrong. Please try again.";
    return raw;
  }

  static String fromServerJson(Map<String, dynamic> jsonBody) {
    final directMsg = (jsonBody["message"] ?? "").toString().trim();
    if (directMsg.isNotEmpty) return directMsg;

    final err = (jsonBody["error"] is Map) ? jsonBody["error"] as Map : {};
    final message = (err["message"] ?? "").toString().trim();
    if (message.isNotEmpty) return message;
    final code = (err["code"] ?? "").toString().trim();
    if (code.isNotEmpty) return code;
    return "Request failed. Please try again.";
  }
}

/// ===============================
/// API SERVICE
/// ===============================
class ProfileApi {
  static Future<UserProfile> fetchProfile({
    required String empCode,
    required String token,
  }) async {
    final uri = Uri.parse(
      ProfileApiConfig.fetchUrl,
    ).replace(queryParameters: {"emp_code": empCode, "token": token});

    final res = await http
        .get(
          uri,
          headers: {
            "Accept": "application/json",
            "Authorization": "Bearer $token",
          },
        )
        .timeout(ProfileApiConfig.timeout);

    Map<String, dynamic> jsonBody;
    try {
      jsonBody = json.decode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception("Invalid server response. Please try again.");
    }

    bool isSuccess(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v.toInt() == 1;
      final s = (v ?? "").toString().trim().toLowerCase();
      return s == "1" || s == "true" || s == "success" || s == "ok";
    }

    final ok = isSuccess(jsonBody["ok"]) || isSuccess(jsonBody["status"]);
    if (!ok) {
      throw Exception(FriendlyError.fromServerJson(jsonBody));
    }

    final data = (jsonBody["user"] is Map)
        ? (jsonBody["user"] as Map).cast<String, dynamic>()
        : (jsonBody["data"] is Map)
        ? (jsonBody["data"] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final imageUrls = (jsonBody["image_urls"] is Map)
        ? (jsonBody["image_urls"] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    return UserProfile.fromApi(
      empCode: empCode,
      data: data,
      imageUrls: imageUrls,
    );
  }

  /// ✅ Multipart update (supports files + fields)
  /// Sends only provided fields/files.
  static Future<void> updateProfileMultipart({
    required String empCode,
    required String token,
    required Map<String, String> fields,
    File? profileImageFile,
    File? aadharFrontFile,
    File? aadharBackFile,
  }) async {
    final uri = Uri.parse(ProfileApiConfig.updateUrl);

    final req = http.MultipartRequest("POST", uri)
      ..headers.addAll({
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      })
      ..fields["code"] = empCode
      ..fields["emp_code"] = empCode
      ..fields["token"] = token;

    fields.forEach((k, v) {
      req.fields[k] = v.trim();
    });

    Future<void> addFile(String fieldName, File f) async {
      final len = await f.length();
      if (len <= 0) return;
      req.files.add(await http.MultipartFile.fromPath(fieldName, f.path));
    }

    if (profileImageFile != null) await addFile("img", profileImageFile);
    if (aadharFrontFile != null) await addFile("id_proof", aadharFrontFile);
    if (aadharBackFile != null) {
      await addFile("id_proof_backside", aadharBackFile);
    }

    final streamed = await req.send().timeout(ProfileApiConfig.timeout);
    final body = await streamed.stream.bytesToString();

    Map<String, dynamic> jsonBody;
    try {
      jsonBody = json.decode(body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception("Invalid server response. Please try again.");
    }

    bool isSuccess(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v.toInt() == 1;
      final s = (v ?? "").toString().trim().toLowerCase();
      return s == "1" || s == "true" || s == "success" || s == "ok";
    }

    final ok = isSuccess(jsonBody["ok"]) || isSuccess(jsonBody["status"]);
    if (!ok) {
      throw Exception(FriendlyError.fromServerJson(jsonBody));
    }
  }
}

/// ===============================
/// SCREEN (2 Tabs)
/// ===============================
class ProfileTabsScreen extends StatefulWidget {
  const ProfileTabsScreen({super.key});

  @override
  State<ProfileTabsScreen> createState() => _ProfileTabsScreenState();
}

class _ProfileTabsScreenState extends State<ProfileTabsScreen>
    with SingleTickerProviderStateMixin {
  // clean white theme + very soft off-white background
  static const Color _bg = Color(0xFFF7F7FB);
  static const Color _card = Colors.white;
  static const Color _stroke = Color(0xFFE9E9F2);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _accent = Color(0xFF111827);

  bool _loading = true;
  bool _refreshing = false;

  String? _empCode;
  String? _token;
  String? _error;

  UserProfile? _profile;

  late final TabController _tabCtrl;

  bool get _isIOS => Theme.of(context).platform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_guardTabNavigation);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_guardTabNavigation);
    _tabCtrl.dispose();
    super.dispose();
  }

  bool _hasValue(String? v) => (v ?? "").trim().isNotEmpty;

  bool _isProfileComplete(UserProfile p) {
    // "All details updated" => no empty editable field + required images uploaded.
    // NOTE: If you want to treat some fields as optional, remove them from below list.
    final mustHaveText = <String?>[
      p.name,
      p.middleName,
      p.surname,
      p.mobileNo,
      p.email,
      p.relationName,
      p.dob,
      p.gender,
      p.bankAccountName,
      p.bankName,
      p.bankBranchName,
      p.bankIfsc,
      p.bankAccountNo,
      p.city,
      p.state,
      p.pincode,
      p.currentAddress,
      p.address,
    ];

    final allTextOk = mustHaveText.every((x) => _hasValue(x));

    // Images required (profile selfie intentionally removed)
    final hasProfileImage =
        _hasValue(p.profileImagePath) ||
        _hasValue(p.imageUrls["profile_image"]);
    final hasAadharFront =
        _hasValue(p.aadharFrontPath) || _hasValue(p.imageUrls["aadhar_front"]);
    final hasAadharBack =
        _hasValue(p.aadharBackPath) || _hasValue(p.imageUrls["aadhar_back"]);

    return allTextOk && hasProfileImage && hasAadharFront && hasAadharBack;
  }

  bool get _updateTabEnabled {
    final p = _profile;
    if (p == null) return false;
    return !_isProfileComplete(p);
  }

  void _guardTabNavigation() {
    // Prevent switching to Update tab if disabled
    if (_tabCtrl.index == 1 && !_updateTabEnabled) {
      // If user tried to switch, bounce back to details
      _tabCtrl.animateTo(0);
      _toast("Profile is complete. No updates are allowed.");
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sp = await SharedPreferences.getInstance();
      final emp = sp.getString(SessionKeys.empCode);
      final tok = sp.getString(SessionKeys.token);

      if (emp == null ||
          emp.trim().isEmpty ||
          tok == null ||
          tok.trim().isEmpty) {
        throw Exception("Session not found. Please login again.");
      }

      _empCode = emp.trim();
      _token = tok.trim();

      final p = await ProfileApi.fetchProfile(
        empCode: _empCode!,
        token: _token!,
      );
      if (!mounted) return;

      setState(() {
        _profile = p;
        _loading = false;
      });

      // If update tab is disabled and currently selected, force details
      if (!_updateTabEnabled && _tabCtrl.index == 1) {
        _tabCtrl.animateTo(0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FriendlyError.fromException(e);
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (_empCode == null || _token == null) {
      await _bootstrap();
      return;
    }
    setState(() {
      _refreshing = true;
      _error = null;
    });

    try {
      final p = await ProfileApi.fetchProfile(
        empCode: _empCode!,
        token: _token!,
      );
      if (!mounted) return;
      setState(() => _profile = p);

      // If now complete, force user to Details tab
      if (!_updateTabEnabled && mounted) {
        _tabCtrl.animateTo(0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = FriendlyError.fromException(e));
    } finally {
      if (!mounted) return;
      setState(() => _refreshing = false);
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();

    if (_isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: _bg,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: Colors.white.withOpacity(0.98),
          border: const Border.fromBorderSide(
            BorderSide(color: _stroke, width: 0.7),
          ),
          middle: const Text("Profile"),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _goHome,
            child: const Icon(CupertinoIcons.back, size: 22),
          ),
          trailing: _refreshing
              ? const CupertinoActivityIndicator()
              : CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _refresh,
                  child: const Icon(CupertinoIcons.refresh, size: 22),
                ),
        ),
        child: SafeArea(child: body),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: _goHome,
        ),
        title: const Text("Profile"),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _refresh,
            ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _buildBody() {
    if (_loading) return _loadingSkeleton();

    if (_error != null) {
      return _errorState(_error!);
    }

    final p = _profile;
    if (p == null) return _errorState("No profile data found.");

    return Column(
      children: [
        _tabHeader(),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            physics: const BouncingScrollPhysics(),
            children: [
              _detailsTab(p),
              _updateTabEnabled
                  ? _updateTab(p)
                  : _profileCompleteTab(), // when disabled, show completion UI
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabHeader() {
    final updateDisabled = !_updateTabEnabled;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _stroke, width: 1),
        ),
        child: TabBar(
          controller: _tabCtrl,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _stroke, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          labelColor: _text,
          unselectedLabelColor: _muted,
          dividerColor: Colors.transparent,
          tabs: [
            const Tab(text: "Your Details"),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Update Profile",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: updateDisabled ? const Color(0xFF9CA3AF) : null,
                    ),
                  ),
                  if (updateDisabled) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.lock_rounded,
                      size: 16,
                      color: Color(0xFF9CA3AF),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ===============================
  /// DETAILS TAB
  /// ===============================
  Widget _detailsTab(UserProfile p) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _headerCard(p),
          const SizedBox(height: 14),

          if (_isProfileComplete(p)) ...[
            _successBanner(
              "Profile Completed",
              "All details are updated. Update tab is locked.",
            ),
            const SizedBox(height: 14),
          ],

          _sectionTitle("Images"),
          const SizedBox(height: 8),
          _imagesSection(p), // profile selfie removed here

          const SizedBox(height: 14),
          _sectionTitle("Basic Info"),
          const SizedBox(height: 8),
          _kvCard([
            _kv("Employee Code", p.empCode),
            _kv("Full Name", p.fullName ?? p.name),
            _kv("Middle Name", p.middleName),
            _kv("Surname", p.surname),
            _kv("Relation", p.relationName),
            _kv("Mobile", p.mobileNo),
            _kv("Email", p.email),
            _kv("Gender", p.gender),
            _kv("DOB", p.dob),
            _kv("Skills", p.skills),
          ]),

          const SizedBox(height: 14),
          _sectionTitle("Employment"),
          const SizedBox(height: 8),
          _kvCard([
            _kv("Designation", p.designationName),
            _kv("Work Location", p.workLocationName),
            _kv("Department(s)", p.departmentsText),
            _kv("Interview Date", p.interviewDate),
            _kv("Join Date", p.joinDate),
          ]),

          const SizedBox(height: 14),
          _sectionTitle("Address"),
          const SizedBox(height: 8),
          _kvCard([
            _kv("Address", p.address),
            _kv("Current Address", p.currentAddress),
            _kv("City", p.city),
            _kv("State", p.state),
            _kv("Pincode", p.pincode),
          ]),

          const SizedBox(height: 14),
          _sectionTitle("Contact Numbers"),
          const SizedBox(height: 8),
          _kvCard([
            _kv("Personal Mobile", p.mobilePersonal),
            _kv("Company Mobile", p.mobileCompany),
          ]),

          const SizedBox(height: 14),
          _sectionTitle("Bank Details"),
          const SizedBox(height: 8),
          _kvCard([
            _kv("Account Name", p.bankAccountName),
            _kv("Bank Name", p.bankName),
            _kv("Branch", p.bankBranchName),
            _kv("Account No", p.bankAccountNo),
            _kv("IFSC", p.bankIfsc),
          ]),

          const SizedBox(height: 14),
          _sectionTitle("Base Location"),
          const SizedBox(height: 8),
          _kvCard([
            _kv("Base Address", p.baseLocationAddress),
            // ✅ latitude/longitude hidden
            _kv("Set At", p.baseLocationSetAt),
          ]),

          const SizedBox(height: 14),
          _sectionTitle("System"),
          const SizedBox(height: 8),
          _kvCard([
            _kv(
              "Active",
              p.isActive == null ? null : (p.isActive! ? "Yes" : "No"),
            ),
            _kv(
              "Password Changed",
              p.isPasswordChanged == null
                  ? null
                  : (p.isPasswordChanged! ? "Yes" : "No"),
            ),
            _kv("Profile Updated At", p.profileUpdatedAt),
            _kv("Created At", p.createdAt),
            _kv("Updated At", p.updatedAt),
          ]),

          const SizedBox(height: 14),
          _sectionTitle("Remark"),
          const SizedBox(height: 8),
          _textCard(p.remark),
        ],
      ),
    );
  }

  Widget _successBanner(String title, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_rounded,
            color: Color(0xFF047857),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _BannerText(
              title: title,
              subtitle: subtitle,
              titleColor: const Color(0xFF065F46),
              subtitleColor: const Color(0xFF047857),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard(UserProfile p) {
    final title = (p.displayName ?? "Employee").trim();
    final subtitle = [
      if ((p.mobileNo ?? "").trim().isNotEmpty) p.mobileNo!.trim(),
      if ((p.email ?? "").trim().isNotEmpty) p.email!.trim(),
    ].join(" • ");

    final avatarUrl = p.imageUrls["profile_image"]; // selfie removed

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stroke, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _avatar(avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle.isEmpty ? "Emp: ${p.empCode}" : subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill("Emp: ${p.empCode}"),
                    if (p.isActive == true) _pill("Active"),
                    if (p.isPasswordChanged == true) _pill("Pwd Changed"),
                    if (_profile != null && _isProfileComplete(_profile!))
                      _pill("Complete"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String? url) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? const Icon(
              CupertinoIcons.person_crop_circle,
              size: 36,
              color: _muted,
            )
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.broken_image_rounded, color: _muted),
            ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _stroke, width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _text,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _text,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.2,
      ),
    );
  }

  _KVRow _kv(String label, String? value) => _KVRow(label, value);

  Widget _kvCard(List<_KVRow> rows) {
    final filtered = rows
        .where((r) => (r.value ?? "").trim().isNotEmpty)
        .toList();
    if (filtered.isEmpty) return _emptyCard("No data available");

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stroke, width: 1),
      ),
      child: Column(
        children: [
          for (int i = 0; i < filtered.length; i++) ...[
            _kvRow(filtered[i].label, filtered[i].value!),
            if (i != filtered.length - 1)
              const Divider(height: 1, thickness: 0.6, color: _stroke),
          ],
        ],
      ),
    );
  }

  Widget _kvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _text,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagesSection(UserProfile p) {
    // ✅ Profile selfie removed from UI
    final items = <_ImageItem>[
      _ImageItem("Profile Image", p.imageUrls["profile_image"]),
      _ImageItem("Aadhar Front", p.imageUrls["aadhar_front"]),
      _ImageItem("Aadhar Back", p.imageUrls["aadhar_back"]),
    ].where((x) => (x.url ?? "").trim().isNotEmpty).toList();

    if (items.isEmpty) return _emptyCard("No images uploaded");

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stroke, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15,
        ),
        itemBuilder: (context, index) {
          final it = items[index];
          return _imageTile(it.title, it.url!);
        },
      ),
    );
  }

  Widget _imageTile(String title, String url) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openImageViewer(title: title, url: url),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _stroke, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_rounded, color: _muted),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openImageViewer({required String title, required String url}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          size: 28,
                          color: _muted,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _textCard(String? text) {
    final t = (text ?? "").trim();
    if (t.isEmpty) return _emptyCard("No remark");
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stroke, width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Text(
        t,
        style: const TextStyle(
          color: _text,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }

  /// ===============================
  /// UPDATE TAB
  /// ===============================
  Widget _updateTab(UserProfile p) {
    return _UpdateProfileForm(
      bg: _bg,
      card: _card,
      stroke: _stroke,
      text: _text,
      muted: _muted,
      accent: _accent,
      empCode: _empCode!,
      token: _token!,
      profile: p,
      onUpdated: () async {
        await _refresh();
        if (!mounted) return;
        _toast("Profile updated successfully.");
      },
    );
  }

  Widget _profileCompleteTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _stroke, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_rounded, color: Color(0xFF047857)),
                  SizedBox(width: 10),
                  Text(
                    "Profile is Complete",
                    style: TextStyle(
                      color: _text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                "All details are already updated. Updates are not allowed now.",
                style: TextStyle(
                  color: _muted,
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _tabCtrl.animateTo(0),
                  child: const Text(
                    "Go to Your Details",
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stroke),
      ),
      padding: const EdgeInsets.all(14),
      child: Text(
        text,
        style: const TextStyle(
          color: _muted,
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _errorState(String msg) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _stroke, width: 1),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Unable to load profile",
                style: TextStyle(
                  color: _text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                msg,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _bootstrap,
                  child: const Text(
                    "Try Again",
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loadingSkeleton() {
    Widget box({double h = 16, double r = 14}) {
      return Container(
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFF6),
          borderRadius: BorderRadius.circular(r),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _stroke),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFF6),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    box(h: 18, r: 10),
                    const SizedBox(height: 10),
                    box(h: 14, r: 10),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: box(h: 26, r: 999)),
                        const SizedBox(width: 8),
                        Expanded(child: box(h: 26, r: 999)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (int i = 0; i < 3; i++) ...[
          Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _stroke),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                box(h: 14, r: 10),
                const SizedBox(height: 10),
                box(h: 14, r: 10),
                const SizedBox(height: 10),
                box(h: 14, r: 10),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

/// Small banner text widget to keep const row above simple
class _BannerText extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;

  const _BannerText({
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: subtitleColor,
            fontSize: 13.2,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// ===============================
/// UPDATE FORM (locked fields if already filled)
/// - Gender dropdown added
/// - Profile selfie removed
/// ===============================
class _UpdateProfileForm extends StatefulWidget {
  final Color bg;
  final Color card;
  final Color stroke;
  final Color text;
  final Color muted;
  final Color accent;

  final String empCode;
  final String token;
  final UserProfile profile;
  final Future<void> Function() onUpdated;

  const _UpdateProfileForm({
    required this.bg,
    required this.card,
    required this.stroke,
    required this.text,
    required this.muted,
    required this.accent,
    required this.empCode,
    required this.token,
    required this.profile,
    required this.onUpdated,
  });

  @override
  State<_UpdateProfileForm> createState() => _UpdateProfileFormState();
}

class _UpdateProfileFormState extends State<_UpdateProfileForm> {
  final _formKey = GlobalKey<FormState>();

  bool _saving = false;
  String? _error;

  // controllers
  late final TextEditingController mobileNoCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController middleNameCtrl;
  late final TextEditingController surnameCtrl;
  late final TextEditingController relationCtrl;

  late final TextEditingController addressCtrl;
  late final TextEditingController currentAddressCtrl;
  late final TextEditingController cityCtrl;
  late final TextEditingController stateCtrl;
  late final TextEditingController pincodeCtrl;

  late final TextEditingController mobilePersonalCtrl;
  late final TextEditingController mobileCompanyCtrl;

  late final TextEditingController dobCtrl;
  late final TextEditingController skillsCtrl;

  late final TextEditingController bankAccountNameCtrl;
  late final TextEditingController bankNameCtrl;
  late final TextEditingController bankBranchCtrl;
  late final TextEditingController bankAccountNoCtrl;
  late final TextEditingController bankIfscCtrl;

  late final TextEditingController remarkCtrl;

  // gender dropdown value
  String? _genderValue;

  // images (profile selfie removed)
  File? _profileImage;
  File? _aadharFront;
  File? _aadharBack;

  final _picker = ImagePicker();

  bool _hasValue(String? v) => (v ?? "").trim().isNotEmpty;

  bool _lockedField({required bool alwaysLocked, required String? existing}) {
    if (alwaysLocked) return true;
    return _hasValue(existing);
  }

  @override
  void initState() {
    super.initState();

    mobileNoCtrl = TextEditingController(text: widget.profile.mobileNo ?? "");
    emailCtrl = TextEditingController(text: widget.profile.email ?? "");
    middleNameCtrl = TextEditingController(
      text: widget.profile.middleName ?? "",
    );
    surnameCtrl = TextEditingController(text: widget.profile.surname ?? "");
    relationCtrl = TextEditingController(
      text: widget.profile.relationName ?? "",
    );

    addressCtrl = TextEditingController(text: widget.profile.address ?? "");
    currentAddressCtrl = TextEditingController(
      text: widget.profile.currentAddress ?? "",
    );
    cityCtrl = TextEditingController(text: widget.profile.city ?? "");
    stateCtrl = TextEditingController(text: widget.profile.state ?? "");
    pincodeCtrl = TextEditingController(text: widget.profile.pincode ?? "");

    mobilePersonalCtrl = TextEditingController(
      text: widget.profile.mobilePersonal ?? "",
    );
    mobileCompanyCtrl = TextEditingController(
      text: widget.profile.mobileCompany ?? "",
    );

    _genderValue = _normalizeGender(widget.profile.gender);

    dobCtrl = TextEditingController(text: widget.profile.dob ?? "");
    skillsCtrl = TextEditingController(text: widget.profile.skills ?? "");

    bankAccountNameCtrl = TextEditingController(
      text: widget.profile.bankAccountName ?? "",
    );
    bankNameCtrl = TextEditingController(text: widget.profile.bankName ?? "");
    bankBranchCtrl = TextEditingController(
      text: widget.profile.bankBranchName ?? "",
    );
    bankAccountNoCtrl = TextEditingController(
      text: widget.profile.bankAccountNo ?? "",
    );
    bankIfscCtrl = TextEditingController(text: widget.profile.bankIfsc ?? "");

    remarkCtrl = TextEditingController(text: widget.profile.remark ?? "");
  }

  String? _normalizeGender(String? g) {
    final s = (g ?? "").trim().toLowerCase();
    if (s == "male") return "Male";
    if (s == "female") return "Female";
    if (s == "other") return "Other";
    return null;
  }

  @override
  void dispose() {
    mobileNoCtrl.dispose();
    emailCtrl.dispose();
    middleNameCtrl.dispose();
    surnameCtrl.dispose();
    relationCtrl.dispose();

    addressCtrl.dispose();
    currentAddressCtrl.dispose();
    cityCtrl.dispose();
    stateCtrl.dispose();
    pincodeCtrl.dispose();

    mobilePersonalCtrl.dispose();
    mobileCompanyCtrl.dispose();

    dobCtrl.dispose();
    skillsCtrl.dispose();

    bankAccountNameCtrl.dispose();
    bankNameCtrl.dispose();
    bankBranchCtrl.dispose();
    bankAccountNoCtrl.dispose();
    bankIfscCtrl.dispose();

    remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage({
    required bool locked,
    required void Function(File f) onPicked,
  }) async {
    if (locked) return;
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    onPicked(File(x.path));
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final fields = <String, String>{};

    void addIfEditable({
      required String key,
      required String? original,
      required bool alwaysLocked,
      required String value,
    }) {
      final locked = _lockedField(
        alwaysLocked: alwaysLocked,
        existing: original,
      );
      if (locked) return;

      final v = value.trim();
      if (v.isEmpty) return;
      if (_hasValue(original)) return;
      fields[key] = v;
    }

    // send only fields that are currently empty on profile
    addIfEditable(
      key: "phone3",
      original: widget.profile.mobileNo,
      alwaysLocked: false,
      value: mobileNoCtrl.text,
    );
    addIfEditable(
      key: "email",
      original: widget.profile.email,
      alwaysLocked: false,
      value: emailCtrl.text,
    );
    addIfEditable(
      key: "middle_name",
      original: widget.profile.middleName,
      alwaysLocked: false,
      value: middleNameCtrl.text,
    );
    addIfEditable(
      key: "surname",
      original: widget.profile.surname,
      alwaysLocked: false,
      value: surnameCtrl.text,
    );

    addIfEditable(
      key: "permanent_address",
      original: widget.profile.address,
      alwaysLocked: false,
      value: addressCtrl.text,
    );
    addIfEditable(
      key: "current_address",
      original: widget.profile.currentAddress,
      alwaysLocked: false,
      value: currentAddressCtrl.text,
    );
    addIfEditable(
      key: "city",
      original: widget.profile.city,
      alwaysLocked: false,
      value: cityCtrl.text,
    );
    addIfEditable(
      key: "state",
      original: widget.profile.state,
      alwaysLocked: false,
      value: stateCtrl.text,
    );
    addIfEditable(
      key: "pincode",
      original: widget.profile.pincode,
      alwaysLocked: false,
      value: pincodeCtrl.text,
    );

    addIfEditable(
      key: "phone2",
      original: widget.profile.mobilePersonal,
      alwaysLocked: false,
      value: mobilePersonalCtrl.text,
    );
    addIfEditable(
      key: "phone",
      original: widget.profile.mobileCompany,
      alwaysLocked: false,
      value: mobileCompanyCtrl.text,
    );
    addIfEditable(
      key: "relation_name",
      original: widget.profile.relationName,
      alwaysLocked: false,
      value: relationCtrl.text,
    );

    // ✅ Gender dropdown
    addIfEditable(
      key: "gender",
      original: widget.profile.gender,
      alwaysLocked: false,
      value: _genderValue ?? "",
    );

    addIfEditable(
      key: "dob",
      original: widget.profile.dob,
      alwaysLocked: false,
      value: dobCtrl.text,
    );
    addIfEditable(
      key: "account_name",
      original: widget.profile.bankAccountName,
      alwaysLocked: false,
      value: bankAccountNameCtrl.text,
    );
    addIfEditable(
      key: "bank_name",
      original: widget.profile.bankName,
      alwaysLocked: false,
      value: bankNameCtrl.text,
    );
    addIfEditable(
      key: "branch_name",
      original: widget.profile.bankBranchName,
      alwaysLocked: false,
      value: bankBranchCtrl.text,
    );
    addIfEditable(
      key: "account_no",
      original: widget.profile.bankAccountNo,
      alwaysLocked: false,
      value: bankAccountNoCtrl.text,
    );
    addIfEditable(
      key: "ifsc",
      original: widget.profile.bankIfsc,
      alwaysLocked: false,
      value: bankIfscCtrl.text,
    );

    // Images: allow only if original empty
    final profileImgLocked =
        _hasValue(widget.profile.profileImagePath) ||
        _hasValue(widget.profile.imageUrls["profile_image"]);
    final aFrontLocked =
        _hasValue(widget.profile.aadharFrontPath) ||
        _hasValue(widget.profile.imageUrls["aadhar_front"]);
    final aBackLocked =
        _hasValue(widget.profile.aadharBackPath) ||
        _hasValue(widget.profile.imageUrls["aadhar_back"]);

    final File? profileImageToSend = profileImgLocked ? null : _profileImage;
    final File? aFrontToSend = aFrontLocked ? null : _aadharFront;
    final File? aBackToSend = aBackLocked ? null : _aadharBack;

    final hasAny =
        fields.isNotEmpty ||
        profileImageToSend != null ||
        aFrontToSend != null ||
        aBackToSend != null;

    if (!hasAny) {
      setState(() => _error = "Please update at least one field or image.");
      return;
    }

    String _fromCtrl(TextEditingController ctrl, String? fallback) {
      final v = ctrl.text.trim();
      return v.isNotEmpty ? v : (fallback ?? "").trim();
    }

    final requiredFields = <String, String>{
      "name": (widget.profile.name ?? widget.profile.displayName ?? "").trim(),
      "email": _fromCtrl(emailCtrl, widget.profile.email),
      "code": widget.profile.empCode.trim(),
      "middle_name": _fromCtrl(middleNameCtrl, widget.profile.middleName),
      "surname": _fromCtrl(surnameCtrl, widget.profile.surname),
      "phone3": _fromCtrl(mobileNoCtrl, widget.profile.mobileNo),
      "relation_name": _fromCtrl(relationCtrl, widget.profile.relationName),
      "gender": (_genderValue ?? widget.profile.gender ?? "").trim(),
      "dob": _fromCtrl(dobCtrl, widget.profile.dob),
      "account_name": _fromCtrl(
        bankAccountNameCtrl,
        widget.profile.bankAccountName,
      ),
      "bank_name": _fromCtrl(bankNameCtrl, widget.profile.bankName),
      "branch_name": _fromCtrl(bankBranchCtrl, widget.profile.bankBranchName),
      "ifsc": _fromCtrl(bankIfscCtrl, widget.profile.bankIfsc),
      "account_no": _fromCtrl(bankAccountNoCtrl, widget.profile.bankAccountNo),
      "city": _fromCtrl(cityCtrl, widget.profile.city),
      "state": _fromCtrl(stateCtrl, widget.profile.state),
      "pincode": _fromCtrl(pincodeCtrl, widget.profile.pincode),
      "current_address": _fromCtrl(
        currentAddressCtrl,
        widget.profile.currentAddress,
      ),
      "permanent_address": _fromCtrl(addressCtrl, widget.profile.address),
    };

    // Keep required image keys present even when not uploading new files.
    if (profileImageToSend == null) {
      requiredFields["img"] = (widget.profile.profileImagePath ?? "").trim();
    }
    if (aFrontToSend == null) {
      requiredFields["id_proof"] = (widget.profile.aadharFrontPath ?? "")
          .trim();
    }
    if (aBackToSend == null) {
      requiredFields["id_proof_backside"] =
          (widget.profile.aadharBackPath ?? "").trim();
    }

    // Changed editable fields overwrite fallback values.
    requiredFields.addAll(fields);

    setState(() => _saving = true);

    try {
      await ProfileApi.updateProfileMultipart(
        empCode: widget.empCode,
        token: widget.token,
        fields: requiredFields,
        profileImageFile: profileImageToSend,
        aadharFrontFile: aFrontToSend,
        aadharBackFile: aBackToSend,
      );

      if (!mounted) return;
      await widget.onUpdated();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = FriendlyError.fromException(e));
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;

    final lockName = true;
    final lockEmpCode = true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Update Rules",
                style: TextStyle(
                  color: widget.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Only fields which are empty can be updated. Already updated fields are locked.",
                style: TextStyle(
                  color: widget.muted,
                  fontSize: 13.2,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (_error != null) ...[
          _card(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        Form(
          key: _formKey,
          child: Column(
            children: [
              _section("Identity", [
                _lockedInfoField(
                  label: "Employee Code",
                  value: p.empCode,
                  locked: lockEmpCode,
                ),
                _lockedInfoField(
                  label: "Name",
                  value: p.displayName ?? "-",
                  locked: lockName,
                ),
              ]),

              const SizedBox(height: 12),
              _section("Basic", [
                _editableField(
                  label: "Mobile",
                  hint: "Enter mobile number",
                  controller: mobileNoCtrl,
                  locked: _lockedField(
                    alwaysLocked: false,
                    existing: p.mobileNo,
                  ),
                  keyboardType: TextInputType.phone,
                ),
                _editableField(
                  label: "Email",
                  hint: "Enter email",
                  controller: emailCtrl,
                  locked: _lockedField(alwaysLocked: false, existing: p.email),
                  keyboardType: TextInputType.emailAddress,
                ),
                _editableField(
                  label: "Middle Name",
                  hint: "Enter middle name",
                  controller: middleNameCtrl,
                  locked: _lockedField(
                    alwaysLocked: false,
                    existing: p.middleName,
                  ),
                ),
                _editableField(
                  label: "Surname",
                  hint: "Enter surname",
                  controller: surnameCtrl,
                  locked: _lockedField(
                    alwaysLocked: false,
                    existing: p.surname,
                  ),
                ),
                _editableField(
                  label: "Relation",
                  hint: "relation with contact",
                  controller: relationCtrl,
                  locked: _lockedField(
                    alwaysLocked: false,
                    existing: p.relationName,
                  ),
                ),

                // ✅ Gender dropdown
                _genderDropdown(existing: p.gender),

                _editableField(
                  label: "DOB (YYYY-MM-DD)",
                  hint: "1990-01-31",
                  controller: dobCtrl,
                  locked: _lockedField(alwaysLocked: false, existing: p.dob),
                ),
              ]),

              const SizedBox(height: 12),
              _section("Address", [
                _editableField(
                  label: "Address",
                  hint: "Enter address",
                  controller: addressCtrl,
                  locked: _lockedField(
                    alwaysLocked: false,
                    existing: p.address,
                  ),
                  maxLines: 3,
                ),
                _editableField(
                  label: "Current Address",
                  hint: "Enter current address",
                  controller: currentAddressCtrl,
                  locked: _lockedField(
                    alwaysLocked: false,
                    existing: p.currentAddress,
                  ),
                  maxLines: 3,
                ),
                _editableField(
                  label: "City",
                  hint: "Enter city",
                  controller: cityCtrl,
                  locked: _lockedField(alwaysLocked: false, existing: p.city),
                ),
                _editableField(
                  label: "State",
                  hint: "Enter state",
                  controller: stateCtrl,
                  locked: _lockedField(alwaysLocked: false, existing: p.state),
                ),
                _editableField(
                  label: "Pincode",
                  hint: "Enter pincode",
                  controller: pincodeCtrl,
                  locked: _lockedField(
                    alwaysLocked: false,
                    existing: p.pincode,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ]),

              const SizedBox(height: 12),
              _section("Contact Numbers", [
                _editableField(
                  label: "Personal Mobile",
                  hint: "Personal number",
                  controller: mobilePersonalCtrl,
                  locked: _lockedField(
                    alwaysLocked: false,
                    existing: p.mobilePersonal,
                  ),
                  keyboardType: TextInputType.phone,
                ),
                _editableField(
                  label: "Company Mobile",
                  hint: "Company number",
                  controller: mobileCompanyCtrl,
                  locked: _lockedField(
                    alwaysLocked: false,
                    existing: p.mobileCompany,
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ]),

              const SizedBox(height: 12),
              _section("Bank", [
                _editableField(
                  label: "Account Name",
                  hint: "Account holder name",
                  controller: bankAccountNameCtrl,
                  locked: _lockedField(
                    alwaysLocked: false,
                    existing: p.bankAccountName,
                  ),
                ),
                _editableField(
                  label: "Bank Name",
                  hint: "Bank name",
                  controller: bankNameCtrl,
                  locked: _lockedField(
                    alwaysLocked: false,
                    existing: p.bankName,
                  ),
                ),
                _editableField(
                  label: "Branch",
                  hint: "Branch name",
                  controller: bankBranchCtrl,
                  locked: _lockedField(
                    alwaysLocked: false,
                    existing: p.bankBranchName,
                  ),
                ),
                _editableField(
                  label: "Account No",
                  hint: "Account number",
                  controller: bankAccountNoCtrl,
                  locked: _lockedField(
                    alwaysLocked: false,
                    existing: p.bankAccountNo,
                  ),
                  keyboardType: TextInputType.number,
                ),
                _editableField(
                  label: "IFSC",
                  hint: "IFSC code",
                  controller: bankIfscCtrl,
                  locked: _lockedField(
                    alwaysLocked: false,
                    existing: p.bankIfsc,
                  ),
                ),
              ]),

              const SizedBox(height: 12),
              _section("Images (Only if not uploaded)", [
                _imagePickerRow(
                  title: "Profile Image",
                  existingUrl: p.imageUrls["profile_image"],
                  locked:
                      _hasValue(p.profileImagePath) ||
                      _hasValue(p.imageUrls["profile_image"]),
                  pickedFile: _profileImage,
                  onPick: () => _pickImage(
                    locked:
                        _hasValue(p.profileImagePath) ||
                        _hasValue(p.imageUrls["profile_image"]),
                    onPicked: (f) => _profileImage = f,
                  ),
                ),
                _imagePickerRow(
                  title: "Aadhar Front",
                  existingUrl: p.imageUrls["aadhar_front"],
                  locked:
                      _hasValue(p.aadharFrontPath) ||
                      _hasValue(p.imageUrls["aadhar_front"]),
                  pickedFile: _aadharFront,
                  onPick: () => _pickImage(
                    locked:
                        _hasValue(p.aadharFrontPath) ||
                        _hasValue(p.imageUrls["aadhar_front"]),
                    onPicked: (f) => _aadharFront = f,
                  ),
                ),
                _imagePickerRow(
                  title: "Aadhar Back",
                  existingUrl: p.imageUrls["aadhar_back"],
                  locked:
                      _hasValue(p.aadharBackPath) ||
                      _hasValue(p.imageUrls["aadhar_back"]),
                  pickedFile: _aadharBack,
                  onPick: () => _pickImage(
                    locked:
                        _hasValue(p.aadharBackPath) ||
                        _hasValue(p.imageUrls["aadhar_back"]),
                    onPicked: (f) => _aadharBack = f,
                  ),
                ),
              ]),

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Save Update",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "If a field is locked, it is already updated and cannot be changed.",
                style: TextStyle(
                  color: widget.muted,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: widget.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.stroke, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }

  Widget _section(String title, List<Widget> children) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: widget.text,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _lockedInfoField({
    required String label,
    required String value,
    required bool locked,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.stroke, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: widget.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: widget.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (locked)
              const Icon(
                Icons.lock_rounded,
                size: 18,
                color: Color(0xFF6B7280),
              ),
          ],
        ),
      ),
    );
  }

  Widget _editableField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool locked,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        enabled: !locked,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: widget.text, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
            color: widget.muted,
            fontWeight: FontWeight.w700,
          ),
          filled: true,
          fillColor: locked ? const Color(0xFFF3F4F6) : const Color(0xFFF4F5FA),
          suffixIcon: locked ? const Icon(Icons.lock_rounded, size: 18) : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: widget.stroke),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: widget.stroke),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: widget.stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: widget.accent),
          ),
        ),
        validator: (_) => null,
      ),
    );
  }

  Widget _genderDropdown({required String? existing}) {
    final locked = _lockedField(alwaysLocked: false, existing: existing);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: "Gender",
          labelStyle: TextStyle(
            color: widget.muted,
            fontWeight: FontWeight.w700,
          ),
          filled: true,
          fillColor: locked ? const Color(0xFFF3F4F6) : const Color(0xFFF4F5FA),
          suffixIcon: locked ? const Icon(Icons.lock_rounded, size: 18) : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: widget.stroke),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: widget.stroke),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: widget.stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: widget.accent),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _genderValue,
            hint: Text(
              "Select",
              style: TextStyle(
                color: widget.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            items: const [
              DropdownMenuItem(value: "Male", child: Text("Male")),
              DropdownMenuItem(value: "Female", child: Text("Female")),
              DropdownMenuItem(value: "Other", child: Text("Other")),
            ],
            onChanged: locked
                ? null
                : (v) {
                    setState(() => _genderValue = v);
                  },
          ),
        ),
      ),
    );
  }

  Widget _imagePickerRow({
    required String title,
    required String? existingUrl,
    required bool locked,
    required File? pickedFile,
    required VoidCallback onPick,
  }) {
    final preview = pickedFile != null
        ? Image.file(pickedFile, fit: BoxFit.cover)
        : (existingUrl != null && existingUrl.trim().isNotEmpty)
        ? CachedNetworkImage(imageUrl: existingUrl, fit: BoxFit.cover)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: locked ? const Color(0xFFF3F4F6) : const Color(0xFFF4F5FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.stroke, width: 1),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.stroke, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child:
                  preview ??
                  Icon(Icons.image_outlined, color: widget.muted, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: widget.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (locked)
              const Icon(Icons.lock_rounded, size: 18, color: Color(0xFF6B7280))
            else
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.text,
                  side: BorderSide(color: widget.stroke, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onPick,
                child: const Text(
                  "Choose",
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KVRow {
  final String label;
  final String? value;
  _KVRow(this.label, this.value);
}

class _ImageItem {
  final String title;
  final String? url;
  _ImageItem(this.title, this.url);
}
