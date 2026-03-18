import 'dart:convert';

import 'package:deodap/commonmodule/appConstant.dart';
import 'package:deodap/commonmodule/appString.dart';
import 'package:deodap/pages/splash/DeviceConfigVO.dart';
import 'package:deodap/widgets/extensions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/routes.dart';
import '../../widgets/all_widget.dart';

class Splash extends StatefulWidget {
  const Splash({Key? key}) : super(key: key);

  @override
  _SplashState createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  final storage = GetStorage();

  DeviceConfigVO? deviceConfigVO;

  String? versionName;   // e.g. 1.0.4
  String? buildNumber;   // e.g. 8

  // offline mode UI
  bool isOfflineApp = false;
  String msg = '';
  dynamic response;

  // update UI
  bool showUpdateUI = false;
  bool forceUpdate = false;
  String updateMessage = "New version available!";
  String latestVersion = "";
  String downloadLink = "";

  bool _openingLink = false;

  @override
  void initState() {
    super.initState();

    _loadVersion();

    // Restore login flag
    final storedLogin = storage.read(AppConstant.IS_LOGIN);
    if (storedLogin != null) {
      AppConstant.isLogin = storedLogin == true;
    } else {
      AppConstant.isLogin = false;
    }

    check().then((internet) async {
      if (internet == true) {
        // 1) Check update first
        await _checkVersionAndMaybeBlock();

        // If update UI is shown (force update), do not proceed further
        if (showUpdateUI && forceUpdate) return;

        // 2) Your existing device config/offline check
        await callAPI();
      } else {
        toastError(AppString.no_internet);
      }
    });
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      versionName = packageInfo.version;      // e.g. 1.0.4
      buildNumber = packageInfo.buildNumber;  // e.g. 8
    });
  }

  // ---------- VERSION CHECK ----------
  int _compareVersions(String a, String b) {
    // returns -1 if a<b, 0 if equal, 1 if a>b
    List<int> pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final len = pa.length > pb.length ? pa.length : pb.length;
    while (pa.length < len) pa.add(0);
    while (pb.length < len) pb.add(0);

    for (int i = 0; i < len; i++) {
      if (pa[i] < pb[i]) return -1;
      if (pa[i] > pb[i]) return 1;
    }
    return 0;
  }

  Future<void> _checkVersionAndMaybeBlock() async {
    try {
      // Pass current version to API (recommended)
      final current = (versionName ?? "").trim();

      final res = await apiCall().get(
        AppConstant.WS_VERSION_CHECK,
        queryParameters: {
          "current_version": current,
          "app_id": AppConstant.APP_ID,
          "api_key": AppConstant.APP_KEY,
        },
      );

      if (!mounted) return;

      if (res.statusCode != AppConstant.STATUS_CODE) {
        // If version API fails, do not block app
        return;
      }

      final data = jsonDecode(res.toString());

      final String apiLatest = (data["latest_version"] ?? "").toString().trim();
      final bool apiForce = (data["force_update"] == true);
      final String apiLink = (data["download_link"] ?? "").toString().trim();
      final String apiMsg = (data["message"] ?? "").toString();

      if (apiLatest.isEmpty) return;

      // Decide update needed also from app-side compare (safe)
      final currentVer = (versionName ?? "").trim();
      final needUpdate = currentVer.isEmpty
          ? true
          : (_compareVersions(currentVer, apiLatest) < 0);

      if (needUpdate) {
        setState(() {
          latestVersion = apiLatest;
          forceUpdate = apiForce; // from server
          downloadLink = apiLink;
          updateMessage = apiMsg.isNotEmpty ? apiMsg : "Update available!";
          showUpdateUI = true;
        });
      }
    } catch (_) {
      // If version check fails, do not block app
      return;
    }
  }

  Future<void> _openDownload() async {
    if (_openingLink) return;
    _openingLink = true;

    final link = downloadLink.trim();
    if (link.isEmpty) {
      _openingLink = false;
      Get.snackbar(
        "Link missing",
        "Download link is not available. Please contact admin.",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final uri = Uri.tryParse(link);
    if (uri == null) {
      _openingLink = false;
      Get.snackbar(
        "Invalid link",
        "Download link is invalid.",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        Get.snackbar(
          "Failed",
          "Could not open download link.",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (_) {
      Get.snackbar(
        "Failed",
        "Could not open download link.",
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _openingLink = false;
    }
  }

  // ---------- DEVICE CONFIG / OFFLINE ----------
  void _nextScreen() {
    if (deviceConfigVO?.data?.isOffline == 1) {
      msg = deviceConfigVO?.message ??
          (response?.data?['message']?.toString() ?? 'App is offline');
      isOfflineApp = true;
      if (mounted) setState(() {});
      return;
    }

    _homeRoute();
  }

  void _homeRoute() {
    if (AppConstant.isLogin) {
      Get.toNamed(Routes.homeRoute);
    } else {
      Get.toNamed(Routes.loginRoute);
    }
  }

  Future<void> callAPI() async {
    showProgress();
    try {
      response = await apiCall().get(
        AppConstant.WS_DEVICE_CONFIG,
        queryParameters: {
          "app_id": AppConstant.APP_ID,
          "api_key": AppConstant.APP_KEY,
        },
      );

      if (!mounted) return;

      if (response.statusCode == AppConstant.STATUS_CODE) {
        deviceConfigVO = DeviceConfigVO.fromJson(
          jsonDecode(response.toString()),
        );

        if (deviceConfigVO != null &&
            deviceConfigVO!.status == AppConstant.APP_SUCCESS) {
          storage.write(AppConstant.PREF_APP_INFO, deviceConfigVO!.toJson());
          hideProgressBar();
          _nextScreen();
        } else {
          hideProgressBar();
          setState(() {});
        }
      } else {
        hideProgressBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Oops! Something went wrong...')),
        );
      }
    } catch (e) {
      hideProgressBar();
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    if (showUpdateUI) {
      // ✅ Update UI (force update => block back)
      return WillPopScope(
        onWillPop: () async => !forceUpdate,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F6FF),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Icon(
                      Icons.system_update_alt_rounded,
                      size: 44,
                      color: Color(0xFF1E5EFF),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Update Available",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    updateMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Current: ${versionName ?? '-'}   |   Latest: ${latestVersion.isEmpty ? '-' : latestVersion}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openDownload,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        forceUpdate ? "Update Now" : "Download Update",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E5EFF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  if (!forceUpdate) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          // allow continue if not force update
                          setState(() => showUpdateUI = false);
                          await callAPI();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF101828),
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "Later",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],

                  const Spacer(),
                  Text(
                    "Build: ${buildNumber ?? '-'}",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Existing offline or splash UI
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isOfflineApp
            ? Column(
          children: [
            const Spacer(),
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/ic_offline.png',
                    height: 200,
                    width: 200,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        )
            : Column(
          children: [
            const Spacer(),
            Center(
              child: Image.asset(
                'assets/images/splash.png',
                height: 200,
                width: 200,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Version: ${versionName ?? '-'} (${buildNumber ?? '-'})",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
