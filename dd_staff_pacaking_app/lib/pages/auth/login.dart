import 'dart:convert';

import 'package:deodap/commonmodule/HexColor.dart';
import 'package:deodap/commonmodule/appString.dart';
import 'package:deodap/pages/auth/warehouseVo.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_storage/get_storage.dart';

import '../../commonmodule/appConstant.dart';
import '../../widgets/all_widget.dart';
import '../splash/DeviceConfigVO.dart';
import 'login_controller.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final LoginController controller =
  Get.put(LoginController(Get.find(), Get.find()));
  final GetStorage storage = GetStorage();

  final TextEditingController searchController = TextEditingController();

  String? selectedStateValue;
  String? selectedStateId = "8";

  DeviceConfigVO? deviceConfigVO;
  WarehouseVo? warehouseVo;

  final List<Logins> _listStateData = <Logins>[];

  // -----------------------------
  // UI theme (Blue + White)
  // -----------------------------
  Color get _blue => const Color(0xFF1E5EFF);
  Color get _blue2 => const Color(0xFF2A7BFF);
  Color get _bg => const Color(0xFFF6F9FF);
  Color get _cardBorder => const Color(0xFFE6EDFF);
  Color get _textDark => const Color(0xFF101828);
  Color get _muted => const Color(0xFF667085);

  TextStyle get _titleStyle => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.2,
  );

  TextStyle get _labelStyle => TextStyle(
    fontSize: 12.5,
    color: _muted,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
  );

  TextStyle get _hintStyle => TextStyle(
    fontSize: 13,
    color: Colors.grey.shade600,
    fontWeight: FontWeight.w600,
  );

  @override
  void initState() {
    super.initState();
    check().then((internet) {
      if (internet != null && internet) {
        selectedStateValue = 'L008';
        controller.warehouseController = selectedStateId;
        _requestWarehouse();
      } else {
        toastError(AppString.no_internet);
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // -----------------------------
  // UI helpers
  // -----------------------------
  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_blue, _blue2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _blue.withOpacity(0.20),
            blurRadius: 22,
            offset: const Offset(0, 14),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Sign in",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Use your credentials and select warehouse",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.90),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _cleanDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: _labelStyle,
      hintText: hint,
      hintStyle: _hintStyle,
      prefixIcon: Icon(icon, color: _blue),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _blue, width: 1.6),
      ),
    );
  }

  Widget _textField({
    required TextEditingController c,
    required String label,
    required String hint,
    required TextInputType type,
    bool obscure = false,
    String? Function(String?)? validator,
    required IconData icon,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: type,
      obscureText: obscure,
      obscuringCharacter: "*",
      validator: validator,
      style: TextStyle(
        color: _textDark,
        fontWeight: FontWeight.w900,
        fontSize: 14,
        letterSpacing: 0.1,
      ),
      decoration: _cleanDecoration(
        label: label,
        hint: hint,
        icon: icon,
        suffix: c.text.isEmpty
            ? null
            : IconButton(
          onPressed: () {
            c.clear();
            setState(() {});
          },
          icon: Icon(Icons.close_rounded, color: Colors.grey.shade500),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _warehouseDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        isExpanded: true,
        hint: Text(
          'Select Warehouse',
          style: TextStyle(
            fontSize: 13.5,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconStyleData: IconStyleData(
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 26,
            color: Colors.grey.shade700,
          ),
        ),
        buttonStyleData: ButtonStyleData(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cardBorder),
          ),
        ),
        dropdownStyleData: DropdownStyleData(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cardBorder),
          ),
        ),
        menuItemStyleData: const MenuItemStyleData(height: 46),
        items: _listStateData
            .map(
              (item) => DropdownMenuItem<String>(
            value: item.label.toString(),
            child: Text(
              item.label.toString(),
              style: TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w900,
                fontSize: 13.8,
              ),
            ),
          ),
        )
            .toList(),
        value: selectedStateValue,
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            for (final e in _listStateData) {
              if (e.label == value) {
                selectedStateId = e.id.toString();
                break;
              }
            }
            selectedStateValue = value;
            controller.warehouseController = selectedStateId;
          });
        },
        dropdownSearchData: DropdownSearchData(
          searchController: searchController,
          searchInnerWidgetHeight: 64,
          searchInnerWidget: Padding(
            padding: const EdgeInsets.all(10),
            child: TextFormField(
              controller: searchController,
              style: TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
              decoration: InputDecoration(
                hintText: 'Search warehouse...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
                prefixIcon: Icon(Icons.search_rounded, color: _blue),
                filled: true,
                fillColor: _bg,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _blue, width: 1.6),
                ),
              ),
            ),
          ),
          searchMatchFn: (item, searchValue) {
            return item.value
                .toString()
                .toLowerCase()
                .contains(searchValue.toLowerCase());
          },
        ),
        onMenuStateChange: (isOpen) {
          if (!isOpen) searchController.clear();
        },
      ),
    );
  }

  Widget _signInButton() {
    return Obx(
          () => SizedBox(
        width: Get.width,
        height: 52,
        child: ElevatedButton(
          onPressed: controller.flag.value ? controller.validate : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
            controller.flag.value ? _blue : Colors.grey.shade400,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!controller.flag.value)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.login_rounded, size: 18),
              const SizedBox(width: 10),
              Text(
                controller.flag.value ? 'SIGN IN' : 'LOADING...',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  fontFamily: fontName(),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            // soft background blobs
            Positioned(
              top: -120,
              right: -120,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              left: -120,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: _blue2.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            SafeArea(
              child: Form(
                key: controller.validationKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                  child: Column(
                    children: [
                      _header(),
                      const SizedBox(height: 14),

                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Credentials",
                                style: _titleStyle.copyWith(color: _textDark)),
                            const SizedBox(height: 14),

                            _textField(
                              c: controller.mobileController,
                              label: "Domain Name / Phone Number",
                              hint: "Eg: myshop.com / 9999999999",
                              type: TextInputType.phone,
                              validator: controller.isMobileValid,
                              icon: Icons.phone_android_rounded,
                            ),
                            const SizedBox(height: 12),

                            _textField(
                              c: controller.passwordController,
                              label: "Password",
                              hint: "Enter Password",
                              type: TextInputType.visiblePassword,
                              validator: controller.isPasswordValid,
                              obscure: true,
                              icon: Icons.lock_outline_rounded,
                            ),

                            const SizedBox(height: 16),
                            Text("Warehouse",
                                style: _titleStyle.copyWith(
                                  color: _textDark,
                                  fontSize: 15.5,
                                )),
                            const SizedBox(height: 10),
                            _warehouseDropdown(),

                            const SizedBox(height: 16),
                            _signInButton(),

                            const SizedBox(height: 10),
                            Text(
                              "Choose the correct warehouse before sign in.",
                              style: TextStyle(
                                fontSize: 12.5,
                                color: _muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // footer
                      Text(
                        "Secure login • Deodap Packaging App v1.0.8",
                        style: TextStyle(
                          fontSize: 12,
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ================== API ==================
  Future<void> _requestWarehouse() async {
    showProgress();
    try {
      final response = await apiCall().get(
        AppConstant.WS_WAREHOUSE_LIST,
        queryParameters: {
          "app_id": AppConstant.APP_ID,
          "api_key": AppConstant.APP_KEY,
        },
      );

      if (response.statusCode == AppConstant.STATUS_CODE) {
        warehouseVo = WarehouseVo.fromJson(jsonDecode(response.toString()));
        if (warehouseVo != null && warehouseVo!.data != null) {
          _listStateData.clear();
          _listStateData.addAll(warehouseVo!.data);
          setState(() {});
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oops! Something went wrong...')),
        );
      }
    } catch (_) {
      toastError('Failed to load warehouse list');
    }
    hideProgressBar();
  }
}
