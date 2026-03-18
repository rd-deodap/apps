import 'dart:convert';

import 'package:deodap/commonmodule/appString.dart';
import 'package:deodap/pages/auth/login_controller.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:get_storage/get_storage.dart';

import '../../commonmodule/appConstant.dart';
import '../../widgets/all_widget.dart';
import 'LoginVo.dart';
import 'ProfileVO.dart';

class Profile extends StatefulWidget {
  const Profile({Key? key}) : super(key: key);

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final controller = Get.put(LoginController(Get.find(), Get.find()));
  final storage = GetStorage();

  LoginVo? loginVo;
  ProfileVO? profileVO;

  // Theme (match your new screens)
  Color get _bluePrimary => const Color(0xFF1E5EFF);
  Color get _violet => const Color(0xFF6D5DF6);
  Color get _bg => const Color(0xFFF6F8FF);
  Color get _textDark => const Color(0xFF101828);

  TextStyle get _titleStyle => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.2,
  );

  TextStyle get _labelStyle => TextStyle(
    fontSize: 12,
    color: Colors.grey.shade700,
    fontWeight: FontWeight.w700,
  );

  TextStyle get _valueStyle => TextStyle(
    fontSize: 13.5,
    color: _textDark,
    fontWeight: FontWeight.w900,
  );

  @override
  void initState() {
    super.initState();
    check().then((intenet) {
      loginVo = LoginVo.fromJson(storage.read(AppConstant.PREF_APP_INFO_LOGIN));
      if (intenet != null && intenet) {
        callAPI();
      } else {
        toastError(AppString.no_internet);
      }
    });
  }

  String _safe(String? s) => (s ?? '').trim();
  bool _has(String? s) => _safe(s).isNotEmpty;

  String _initials(String name) {
    final n = name.trim();
    if (n.isEmpty) return "U";
    final parts = n.split(RegExp(r"\s+")).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return "U";
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Widget _card({
    required Widget child,
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _pill(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _bluePrimary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: _textDark,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _bluePrimary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _bluePrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _labelStyle),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: _valueStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noRecord() {
    return SizedBox(
      width: screenWidth(context),
      height: mainHeight(context) - 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            AppConstant.noRecordImagePath,
            height: AppConstant.noRecordImageHeightWidth,
            width: AppConstant.noRecordImageHeightWidth,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = profileVO?.data?.name?.toString() ?? "";
    final phone = profileVO?.data?.phone?.toString() ?? "";
    final code = profileVO?.data?.code?.toString() ?? "";
    final warehouseId = profileVO?.data?.warehouseId?.toString() ?? "";

    // Fallback heading
    final displayName = _has(name) ? name : "User";

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // soft background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _bluePrimary.withOpacity(0.12),
                    _bg,
                    _bg,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Get.back(),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: _textDark,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Profile",
                          style: _titleStyle.copyWith(color: _textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_bluePrimary, _violet],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.person_rounded,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: profileVO != null
                      ? RefreshIndicator(
                    onRefresh: () async {
                      await callAPI();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                      child: Column(
                        children: [
                          // Header: Avatar + Name + Pills (NO LOGO)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _bluePrimary.withOpacity(0.14),
                                  Colors.white,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                  color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [_bluePrimary, _violet],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius:
                                    BorderRadius.circular(22),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _initials(displayName),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: TextStyle(
                                          color: _textDark,
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),

                                      // ✅ Emp + Phone (same row if possible)
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 8,
                                        children: [
                                          if (_has(code))
                                            _pill("Emp: $code",
                                                Icons.badge_outlined),
                                          _pill(
                                            _has(phone)
                                                ? "No: $phone"
                                                : "No: -",
                                            Icons.phone_in_talk_outlined,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Details card
                          _card(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: _bluePrimary
                                            .withOpacity(0.10),
                                        borderRadius:
                                        BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        Icons.info_outline_rounded,
                                        color: _bluePrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      "Profile Details",
                                      style: _titleStyle.copyWith(
                                          color: _textDark),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                if (_has(name)) ...[
                                  _infoRow(
                                    icon: Icons.person_rounded,
                                    label: "Name",
                                    value: name,
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (_has(phone)) ...[
                                  _infoRow(
                                    icon: Icons.phone_rounded,
                                    label: "Phone",
                                    value: phone,
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (_has(code)) ...[
                                  _infoRow(
                                    icon: Icons.badge_rounded,
                                    label: "Employee Code",
                                    value: code,
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (_has(warehouseId)) ...[
                                  _infoRow(
                                    icon: Icons.warehouse_rounded,
                                    label: "Warehouse ID",
                                    value: warehouseId,
                                  ),
                                ],

                                if (!_has(name) &&
                                    !_has(phone) &&
                                    !_has(code) &&
                                    !_has(warehouseId))
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Text(
                                      "No profile details found.",
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Small note card (optional but looks premium)
                          _card(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F9FC),
                                    borderRadius:
                                    BorderRadius.circular(14),
                                    border: Border.all(
                                        color: Colors.grey.shade200),
                                  ),
                                  child: Icon(Icons.verified_user_rounded,
                                      color: _bluePrimary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Your profile data is fetched securely from the server.",
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      : _noRecord(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> callAPI() async {
    showProgress();
    try {
      final _response = await apiCall().get(
        AppConstant.WS_GET_PROFILE,
        queryParameters: {
          "app_id": AppConstant.APP_ID,
          "api_key": AppConstant.APP_KEY,
          "token": loginVo!.data!.token.toString(),
        },
      );

      if (_response.statusCode == AppConstant.STATUS_CODE) {
        hideProgressBar();
        profileVO = ProfileVO.fromJson(jsonDecode(_response.toString()));
        if (mounted) setState(() {});
      } else {
        hideProgressBar();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oops! Something went wrong...'),
          ),
        );
      }
    } catch (e) {
      hideProgressBar();
      // ignore: avoid_print
      print('Error: $e');
    }
  }
}
