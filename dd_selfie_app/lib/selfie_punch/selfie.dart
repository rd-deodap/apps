import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // compute
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:dd_selfie_app/home/home_screen.dart';

class ApiConfig {
  static const String punchUrl =
      "https://customprint.deodap.com/api_selfie_app/selfie_punch.php";
  static const String locationPolicyUrl =
      "https://customprint.deodap.com/api_selfie_app/selfie_location.php";
}

class SessionKeys {
  static const String token = "token";
  static const String empCode = "emp_code";
  static const String name = "name";
}

/* ============================================================
   Isolate Watermark Worker (NO plugins here)
============================================================ */
class _WatermarkJob {
  final String inputPath;
  final String dtStr;
  final String address;

  const _WatermarkJob({
    required this.inputPath,
    required this.dtStr,
    required this.address,
  });

  Map<String, dynamic> toJson() => {
    "inputPath": inputPath,
    "dtStr": dtStr,
    "address": address,
  };

  static _WatermarkJob fromJson(Map<String, dynamic> j) => _WatermarkJob(
    inputPath: (j["inputPath"] ?? "").toString(),
    dtStr: (j["dtStr"] ?? "").toString(),
    address: (j["address"] ?? "").toString(),
  );
}

/// Returns JPG bytes (Uint8List) so we can save the file on main isolate.
Future<Uint8List> _watermarkWorker(Map<String, dynamic> payload) async {
  final job = _WatermarkJob.fromJson(payload);

  final inFile = File(job.inputPath);
  final bytes = await inFile.readAsBytes();

  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception("Failed to process image.");
  }

  final base = img.bakeOrientation(decoded);

  final lines = <String>[
    job.dtStr,
    job.address.isEmpty ? "Location unavailable" : job.address,
  ];

  final font = img.arial14;

  const padding = 18;
  const lineGap = 8;

  int approxTextWidth(String s) =>
      (s.length * 10).clamp(0, base.width - 2 * padding);

  int maxW = 0;
  for (final l in lines) {
    final w = approxTextWidth(l);
    if (w > maxW) maxW = w;
  }

  final boxW = (maxW + padding * 2).clamp(220, base.width - 24);
  final boxH = (lines.length * 22 + (lines.length - 1) * lineGap + padding * 2)
      .clamp(90, base.height - 24);

  final x0 = base.width - boxW - 20;
  final y0 = base.height - boxH - 20;

  img.fillRect(
    base,
    x1: x0,
    y1: y0,
    x2: x0 + boxW,
    y2: y0 + boxH,
    color: img.ColorRgba8(0, 0, 0, 140),
  );

  int ty = y0 + padding;
  for (final l in lines) {
    img.drawString(
      base,
      l,
      font: font,
      x: x0 + padding,
      y: ty,
      color: img.ColorRgba8(255, 255, 255, 255),
    );
    ty += 22 + lineGap;
  }

  final outBytes = img.encodeJpg(
    base,
    quality: 80,
  ); // slightly lower quality for faster encode/upload
  return Uint8List.fromList(outBytes);
}

/* ============================================================
   Page
============================================================ */
class SelfiePunchPage extends StatefulWidget {
  const SelfiePunchPage({super.key});

  @override
  State<SelfiePunchPage> createState() => _SelfiePunchPageState();
}

class _SelfiePunchPageState extends State<SelfiePunchPage>
    with WidgetsBindingObserver {
  // White theme + cream accents
  static const Color _bg = Colors.white;
  static const Color _cream = Color(0xFFFEF8DD);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  bool _isInitializing = true;
  bool _openingCamera = false;
  bool _busy = false;
  bool _camDisposing = false;
  bool _camInitializing = false;

  String? _error;

  String _empCode = "";
  String _token = "";
  String _name = "";

  CameraController? _cam;
  CameraDescription? _selectedCam;
  List<CameraDescription> _availableCameras = [];
  bool _useFrontCamera = true; // Default to front camera for selfie

  Position? _pos;
  String? _address;

  // Location gate flags
  bool _locServiceEnabled = true;
  bool _locPermissionGranted = true;
  bool _locOk = true;

  // Location policy from backend
  String? _locationMode; // DELTA, ELISA, EVERYONE
  double? _baseLat;
  double? _baseLng;
  int _allowedRadius = 100; // default 100 meters
  String? _baseAddress;
  bool _policyLoaded = false;
  bool _isWithinRange = true;
  double _distanceFromBase = 0;

  File? _capturedFile;
  File? _watermarkedFile;
  bool _isWatermarking = false;

  // countdown removed - selfies can now be submitted at any time
  // (previously used for 15-second validation)

  final TextEditingController _remarkController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, dynamic>? _punchResponse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fastInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // timer removed; nothing to cancel
    unawaited(_safeDisposeCamera());
    _remarkController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_safeDisposeCamera());
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_loadLocation(silent: true));
      if (mounted && _capturedFile == null && _cam == null && !_openingCamera) {
        unawaited(_openCamera());
      }
    }
  }

  /* ============================================================
     Init
  ============================================================ */
  Future<void> _fastInit() async {
    try {
      await _loadSession();
      await _loadLocationPolicy();
      // preload current location so the location gate can appear immediately
      await _loadLocation(silent: true);
    } catch (e) {
      await _playErrorSound();
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isInitializing = false);

      // auto open camera
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted &&
              _capturedFile == null &&
              _cam == null &&
              !_openingCamera) {
            unawaited(_openCamera());
          }
        });
      }
    }
  }

  Future<void> _loadSession() async {
    final sp = await SharedPreferences.getInstance();
    final emp = (sp.getString(SessionKeys.empCode) ?? "").trim();
    final token = (sp.getString(SessionKeys.token) ?? "").trim();
    final name = (sp.getString(SessionKeys.name) ?? "").trim();

    if (emp.isEmpty || token.isEmpty) {
      throw Exception("Session expired. Please login again.");
    }
    _empCode = emp;
    _token = token;
    _name = name;
  }

  /* ============================================================
     Location Policy from Backend
  ============================================================ */
  Future<void> _loadLocationPolicy() async {
    if (_empCode.isEmpty) return;

    try {
      final uri = Uri.parse(
        "${ApiConfig.locationPolicyUrl}?action=get_policy&emp_code=$_empCode",
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception("API returned status ${response.statusCode}");
      }

      final js = jsonDecode(response.body) as Map<String, dynamic>;

      if (js["ok"] == true && js["data"] != null) {
        final data = js["data"] as Map<String, dynamic>;
        if (!mounted) return;

        // Parse coordinates safely (PHP may return strings or numbers)
        double? parsedLat;
        double? parsedLng;
        int parsedRadius = 600; // default 600 meters

        // Handle lat - could be number, string, or null
        final latValue = data["lat"];
        if (latValue != null && latValue.toString().toLowerCase() != "null") {
          parsedLat = double.tryParse(latValue.toString());
        }

        // Handle lng - could be number, string, or null
        final lngValue = data["lng"];
        if (lngValue != null && lngValue.toString().toLowerCase() != "null") {
          parsedLng = double.tryParse(lngValue.toString());
        }

        // Handle radius
        final radiusValue = data["radius_m"];
        if (radiusValue != null) {
          parsedRadius = int.tryParse(radiusValue.toString()) ?? 600;
        }

        // Validate coordinates are reasonable
        if (parsedLat != null && parsedLng != null) {
          final isInvalidLat = parsedLat < -90 || parsedLat > 90;
          final isInvalidLng = parsedLng < -180 || parsedLng > 180;

          if (isInvalidLat || isInvalidLng) {
            parsedLat = null;
            parsedLng = null;
          }
        }

        final mode = data["mode"]?.toString().toUpperCase() ?? "EVERYONE";

        setState(() {
          _locationMode = mode;
          _baseLat = parsedLat;
          _baseLng = parsedLng;
          _allowedRadius = parsedRadius;
          _baseAddress = data["address"]?.toString();
          _policyLoaded = true;
        });
      } else {
        // API returned ok=false or no data
        if (!mounted) return;
        setState(() {
          _policyLoaded = true;
          _locationMode = "EVERYONE";
        });
      }
    } catch (_) {
      // Policy load failed - continue with default (no restriction)
      if (!mounted) return;
      setState(() {
        _policyLoaded = true;
        _locationMode = "EVERYONE";
      });
    }
  }

  /// Calculate distance and check if within allowed range
  void _checkDistanceFromBase() {
    if (!mounted) return;

    // If mode is EVERYONE or no base coordinates, allow selfie
    if (_locationMode == "EVERYONE" || _baseLat == null || _baseLng == null) {
      setState(() {
        _isWithinRange = true;
        _distanceFromBase = 0;
      });
      return;
    }

    // If current position is not available
    if (_pos == null) {
      setState(() {
        _isWithinRange = false;
        _distanceFromBase = 0;
      });
      return;
    }

    // Calculate distance using Geolocator
    final distance = Geolocator.distanceBetween(
      _pos!.latitude,
      _pos!.longitude,
      _baseLat!,
      _baseLng!,
    );

    final withinRange = distance <= _allowedRadius;

    setState(() {
      _distanceFromBase = distance;
      _isWithinRange = withinRange;
    });
  }

  /* ============================================================
     Location Core
  ============================================================ */
  Future<void> _loadLocation({bool silent = false}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locServiceEnabled = false;
          _locPermissionGranted = true;
          _locOk = false;
          _pos = null;
          _address = "Location services disabled";
        });
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      final permGranted =
      !(perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever);

      if (!permGranted) {
        if (!mounted) return;
        setState(() {
          _locServiceEnabled = true;
          _locPermissionGranted = false;
          _locOk = false;
          _pos = null;
          _address = perm == LocationPermission.deniedForever
              ? "Location permission denied forever"
              : "Location permission not granted";
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      String? addr;
      try {
        final placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          final parts = <String>[
            if ((pm.name ?? '').trim().isNotEmpty) pm.name!.trim(),
            if ((pm.subLocality ?? '').trim().isNotEmpty)
              pm.subLocality!.trim(),
            if ((pm.locality ?? '').trim().isNotEmpty) pm.locality!.trim(),
            if ((pm.administrativeArea ?? '').trim().isNotEmpty)
              pm.administrativeArea!.trim(),
            if ((pm.postalCode ?? '').trim().isNotEmpty) pm.postalCode!.trim(),
          ];
          addr = parts.join(", ");
        }
      } catch (_) {
        addr = "Address unavailable";
      }

      if (!mounted) return;
      setState(() {
        _locServiceEnabled = true;
        _locPermissionGranted = true;
        _locOk = true;
        _pos = pos;
        _address = addr ?? "Address unavailable";
      });
      _checkDistanceFromBase();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locServiceEnabled = true;
        _locPermissionGranted = true;
        _locOk = false;
        _pos = null;
        _address = "Location unavailable";
      });

      if (!silent && mounted) {
        setState(() => _error = "Location unavailable. Please try again.");
      }
    }
  }

  Future<void> _openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {}
  }

  Future<void> _openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }

  /// ✅ Proper submit flow (fix):
  /// - Service OFF -> open location settings
  /// - Denied -> show system popup (requestPermission)
  /// - Denied forever -> open app settings
  /// - Then fetch fresh location
  /// Location is no longer required; this helper simply refreshes the
  /// position/address if possible and always returns true.
  /// Attempt to refresh the current location and indicate whether it is usable.
  /// Previously location was optional, but now the selfie flow requires a valid
  /// position before capturing or submitting. This helper will try to load the
  /// location (silently) and return true only when `_locOk` is true and we
  /// have a non-null `_pos`.
  Future<bool> _ensureLocationReadyForSubmit() async {
    await _loadLocation(silent: true);
    return _locOk && _pos != null;
  }

  Future<String> _getDeviceId() async {
    final di = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await di.androidInfo;
      return a.id;
    } else if (Platform.isIOS) {
      final i = await di.iosInfo;
      return i.identifierForVendor ?? "ios_unknown";
    }
    return "unknown_device";
  }

  Future<void> _playErrorSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/error.mp3'));
      if (await Vibration.hasVibrator() ?? false) {
        await Vibration.vibrate(duration: 450);
      }
    } catch (_) {}
  }

  /* ============================================================
     Navigation
  ============================================================ */
  void _goToAppShell() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
          (route) => false,
    );
  }

  /* ============================================================
     Camera: SAFE open/close/dispose
  ============================================================ */
  Future<void> _safeDisposeCamera() async {
    if (_camDisposing) return;
    final cam = _cam;
    if (cam == null) return;

    _camDisposing = true;
    try {
      await cam.dispose();
    } catch (_) {}
    _cam = null;
    _selectedCam = null;
    _camDisposing = false;

    if (mounted) setState(() {});
  }

  Future<void> _openCamera() async {
    if (_openingCamera || _busy || _camInitializing) return;

    if (mounted) {
      setState(() {
        _openingCamera = true;
        _error = null;
      });
    }

    try {
      _camInitializing = true;
      await _safeDisposeCamera();

      final cams = await availableCameras();
      if (cams.isEmpty) throw Exception("No camera available on device.");

      _availableCameras = cams;

      // Find front and back cameras
      CameraDescription? front;
      CameraDescription? back;
      for (final c in cams) {
        if (c.lensDirection == CameraLensDirection.front) {
          front = c;
        } else if (c.lensDirection == CameraLensDirection.back) {
          back = c;
        }
      }

      // Select camera based on _useFrontCamera flag
      CameraDescription useCam;
      if (_useFrontCamera) {
        useCam = front ?? back ?? cams.first;
      } else {
        useCam = back ?? front ?? cams.first;
      }
      _selectedCam = useCam;

      // use medium resolution to speed up capture and processing
      final controller = CameraController(
        useCam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      try {
        await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      } catch (_) {}

      if (!mounted) {
        await controller.dispose();
        return;
      }

      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _cam = controller;
      });
    } catch (e) {
      await _playErrorSound();
      if (mounted) setState(() => _error = "Camera error: ${e.toString()}");
    } finally {
      _camInitializing = false;
      if (mounted) setState(() => _openingCamera = false);
    }
  }

  /// Switch between front and back camera
  Future<void> _switchCamera() async {
    if (_openingCamera || _busy || _camInitializing) return;
    if (_availableCameras.length < 2) return; // No other camera to switch to

    setState(() {
      _useFrontCamera = !_useFrontCamera;
    });

    await _openCamera();
  }

  /* ============================================================
     15 seconds submit window
  ============================================================ */
  // countdown logic has been removed; users can submit at their leisure
  void _startExpiryCountdown() {
    // intentionally left blank
  }

  /* ============================================================
     Capture
  ============================================================ */
  Future<void> _captureSelfie() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) {
      await _playErrorSound();
      if (mounted)
        setState(() => _error = "Camera not ready. Please try again.");
      return;
    }
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final cap = await cam.takePicture();

      await _safeDisposeCamera();

      if (!mounted) return;
      setState(() {
        _capturedFile = File(cap.path);
        _busy = false;
      });

      // Start watermarking in background (non-blocking)
      _watermarkInBackground();

    } catch (e) {
      await _playErrorSound();
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _busy = false;
      });
    }
  }

  /// Watermark in background without blocking UI
  Future<void> _watermarkInBackground() async {
    if (_capturedFile == null || _isWatermarking) return;

    setState(() => _isWatermarking = true);

    try {
      final captureNow = DateTime.now();
      final addr = (_address ?? "Location unavailable").trim();
      final dtStr = DateFormat("dd-MM-yyyy  HH:mm:ss").format(captureNow);

      final wmBytes = await compute<Map<String, dynamic>, Uint8List>(
        _watermarkWorker,
        _WatermarkJob(
          inputPath: _capturedFile!.path,
          dtStr: dtStr,
          address: addr,
        ).toJson(),
      );

      final dir = await getTemporaryDirectory();
      final outPath = p.join(
        dir.path,
        "wm_${DateTime.now().millisecondsSinceEpoch}.jpg",
      );
      final outFile = File(outPath);
      await outFile.writeAsBytes(wmBytes, flush: true);

      if (mounted) {
        setState(() {
          _watermarkedFile = outFile;
          _isWatermarking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isWatermarking = false);
      }
    }
  }

  /* ============================================================
     Submit
  ============================================================ */
  Future<void> _submitPunch() async {
    if (_capturedFile == null || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // ensure location before submitting (required by backend)
      final ready = await _ensureLocationReadyForSubmit();
      if (!ready) {
        throw Exception("Location is required to submit selfie.");
      }

      // Wait for watermarking to complete if still processing
      if (_isWatermarking && _watermarkedFile == null) {
        // Watermark is still processing, wait for it
        int attempts = 0;
        while (_isWatermarking && attempts < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      }

      final deviceId = await _getDeviceId();
      final addr = (_address ?? "Location unavailable").trim();

      final req = http.MultipartRequest("POST", Uri.parse(ApiConfig.punchUrl));
      req.fields["action"] = "punch";
      req.fields["emp_code"] = _empCode;
      req.fields["token"] = _token;
      req.fields["punch_type"] = "AUTO";
      req.fields["live_location_address"] = addr;
      req.fields["device_id"] = deviceId;

      final remarkText = _remarkController.text.trim();
      if (remarkText.isNotEmpty) req.fields["remark"] = remarkText;

      if (_pos != null) {
        req.fields["live_lat"] = _pos!.latitude.toStringAsFixed(6);
        req.fields["live_lng"] = _pos!.longitude.toStringAsFixed(6);
      }

      // Use watermarked file if ready, otherwise use original
      final uploadFile = _watermarkedFile ?? _capturedFile!;

      req.files.add(
        await http.MultipartFile.fromPath(
          "selfie_file",
          uploadFile.path,
          filename: p.basename(uploadFile.path),
        ),
      );

      final streamed = await req.send().timeout(const Duration(seconds: 20));
      final body = await streamed.stream.bytesToString();

      Map<String, dynamic> js;
      try {
        js = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception("Server returned invalid response. Please try again.");
      }

      if (js["ok"] != true) {
        final errMsg =
            js["error"]?["message"]?.toString() ??
                "Punch submission failed. Please try again.";
        throw Exception(errMsg);
      }

      _punchResponse = js["data"] ?? {};

      // Send data to webhook endpoint (for testing)
      unawaited(_sendToWebhook());

      // Clean up files
      try {
        if (_watermarkedFile != null) await _watermarkedFile!.delete();
        if (_capturedFile != null) await _capturedFile!.delete();
      } catch (_) {}

      if (!mounted) return;
      setState(() => _busy = false);

      await _showSuccessDialogFullWidth();
    } catch (e) {
      await _playErrorSound();

      String msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('SocketException') ||
          msg.toLowerCase().contains('network')) {
        msg = "Network connection failed. Please check your internet.";
      } else if (msg.contains('TimeoutException')) {
        msg = "Submit timeout. Please try again.";
      } else if (msg.contains('FormatException')) {
        msg = "Server error occurred. Please contact support.";
      }

      if (!mounted) return;
      setState(() {
        _error = msg;
        _busy = false;
      });
    }
  }


  Map<String, dynamic> _buildWebhookPayload() {
    final data = _punchResponse ?? {};
    final daily = (data["daily"] as Map?)?.cast<String, dynamic>() ?? {};

    // Get FIRST IN punch (always in_time_1)
    final inTimeRaw = _fmtTime(daily["in_time_1"]);
    final inTime = _toHourMinute(inTimeRaw, allowDash: true, fallback: "-");

    // Get LAST OUT punch (check slots 3, 2, 1 in that order)
    String outTime = "-";
    for (int slot = 3; slot >= 1; slot--) {
      final outT = _fmtTime(daily["out_time_$slot"]);
      if (outT != "-") {
        outTime = _toHourMinute(outT, allowDash: true, fallback: "-");
        break;
      }
    }

    // Calculate TOTAL work time by summing all slots
    Duration totalDuration = Duration.zero;
    for (int slot = 1; slot <= 3; slot++) {
      final slotIn = _fmtTime(daily["in_time_$slot"]);
      final slotOut = _fmtTime(daily["out_time_$slot"]);
      final slotDur = _slotDuration(slotIn, slotOut);
      if (slotDur != null) {
        totalDuration += slotDur;
      }
    }
    final workTime = totalDuration.inSeconds > 0 ? _durToHm(totalDuration) : "00:00";

    // Get other fields
    final otTime = _toHourMinute(daily["ot_time"], fallback: "00:00");

    // Get date string in DD/MM/YYYY format
    final now = DateTime.now();
    final dateString = DateFormat("dd/MM/yyyy").format(now);

    // Determine status code: WO for Sunday, P for Present, A for Absent
    String status;
    if (now.weekday == DateTime.sunday) {
      status = "WO"; // Weekly Off for Sunday
    } else {
      final attendanceStatus = (daily["attendance_status"] ?? "P").toString().toUpperCase();
      if (attendanceStatus == "PRESENT" || attendanceStatus == "P") {
        status = "P";
      } else if (attendanceStatus == "ABSENT" || attendanceStatus == "A") {
        status = "A";
      } else {
        status = "P"; // Default to Present
      }
    }

    // Calculate Late_In based on punch time (after 9:00 AM = late)
    final lateIn = _calculateLateIn(inTime);
    final erlOut = _toHourMinute(daily["erl_out"], fallback: "00:00");

    // Generate automatic remark (LT, OT, EL, EOA, Miss Punch)
    final remark = _buildAutoRemark();

    return {
      "InOutPunchData": [
        {
          "Empcode": _empCode,
          "INTime": inTime,
          "OUTTime": outTime,
          "WorkTime": workTime,
          "OverTime": otTime,
          "BreakTime": "00:00",
          "Status": status,
          "DateString": dateString,
          "Remark": remark,
          "Erl_Out": erlOut,
          "Late_In": lateIn,
          "Name": _name,
        }
      ],
      "Error": false,
      "Msg": "Success",
      "IsAdmin": false,
    };
  }

  /// Send punch data to webhook endpoint with retry mechanism
  Future<void> _sendToWebhook() async {
    const webhookUrl =
        "https://staff.deodap.in/api/webhook/punches";
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    final payload = _buildWebhookPayload();

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http.post(
          Uri.parse(webhookUrl),
          headers: {
            "Content-Type": "application/json",
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 10));

        // Success - exit retry loop
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return;
        }

        // Server error (5xx) - retry
        if (response.statusCode >= 500 && attempt < maxRetries) {
          await Future.delayed(retryDelay);
          continue;
        }

        // Client error (4xx) - don't retry
        if (response.statusCode >= 400 && response.statusCode < 500) {
          return;
        }
      } on TimeoutException catch (_) {
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay);
        }
      } on SocketException catch (_) {
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay);
        }
      } catch (_) {
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay);
        }
      }
    }
    // Don't throw - webhook is for testing only
  }

  /* ============================================================
     Slot helpers
  ============================================================ */
  String _fmtTime(dynamic v) {
    final s = (v ?? "").toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return "-";
    if (s.length >= 19 && s.contains(' ')) {
      final parts = s.split(' ');
      if (parts.length >= 2) return parts[1];
    }
    return s;
  }

  Duration? _slotDuration(String inT, String outT) {
    if (inT == "-" || outT == "-") return null;
    try {
      DateTime parseAny(String s) {
        if (s.contains(' ')) return DateTime.parse(s.replaceFirst(' ', 'T'));
        return DateTime.parse("2000-01-01T$s");
      }

      final a = parseAny(inT);
      final b = parseAny(outT);
      if (b.isBefore(a)) return null;
      return b.difference(a);
    } catch (_) {
      return null;
    }
  }

  String _durToHms(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  String _durToHm(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return "$h:$m";
  }

  /// Normalize time to HH:mm for webhook payload.
  /// Accepts values like HH:mm, HH:mm:ss, or yyyy-MM-dd HH:mm:ss.
  String _toHourMinute(
      dynamic value, {
        String fallback = "00:00",
        bool allowDash = false,
      }) {
    final raw = (value ?? "").toString().trim();
    if (raw.isEmpty || raw.toLowerCase() == "null") return fallback;
    if (allowDash && raw == "-") return "-";

    String timePart = raw;
    if (timePart.contains(' ')) {
      final parts = timePart.split(' ');
      if (parts.length >= 2) {
        timePart = parts[1].trim();
      }
    }

    final segments = timePart.split(':');
    if (segments.length >= 2) {
      final h = int.tryParse(segments[0]);
      final m = int.tryParse(segments[1]);
      if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        final hh = h.toString().padLeft(2, '0');
        final mm = m.toString().padLeft(2, '0');
        return "$hh:$mm";
      }
    }

    return fallback;
  }

  /// Calculate Late In time based on 9:00 AM standard
  /// If punch is after 9:00 AM, returns the difference (e.g., 10:00 AM = 01:00 late)
  String _calculateLateIn(String inTime) {
    if (inTime == "-" || inTime.isEmpty) return "00:00";

    try {
      // inTime format is "HH:mm" or "HH:mm:ss"
      final parts = inTime.split(':');
      if (parts.length < 2) return "00:00";

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      // Standard start time is 9:00 AM
      const standardHour = 9;
      const standardMinute = 0;

      // If punch is at or before 9:00 AM, not late
      if (hour < standardHour || (hour == standardHour && minute == 0)) {
        return "00:00";
      }

      // Calculate minutes since 9:00 AM
      final inMinutes = hour * 60 + minute;
      final standardMinutes = standardHour * 60 + standardMinute;
      final lateMinutes = inMinutes - standardMinutes;

      if (lateMinutes <= 0) return "00:00";

      final lateHours = (lateMinutes ~/ 60).toString().padLeft(2, '0');
      final lateMin = (lateMinutes % 60).toString().padLeft(2, '0');

      return "$lateHours:$lateMin";
    } catch (_) {
      return "00:00";
    }
  }

  /// Generate automatic remark based on punch conditions
  /// Returns codes like "LT-OT", "EL", "Miss Punch", etc.
  String _buildAutoRemark() {
    final data = _punchResponse ?? {};
    final daily = (data["daily"] as Map?)?.cast<String, dynamic>() ?? {};
    final slotInfo = _buildSlotSummary(daily);

    final inTime = slotInfo["currentIn"]?.toString() ?? "-";
    final outTime = slotInfo["currentOut"]?.toString() ?? "-";
    final otTime = (daily["ot_time"] ?? "00:00:00").toString();
    final erlOut = (daily["erl_out"] ?? "00:00").toString();

    final remarks = <String>[];

    // Check for Miss Punch first (if IN or OUT is missing in current slot)
    if (inTime == "-" || outTime == "-") {
      remarks.add("Miss Punch");
    } else {
      // Check for Late In (after 9:00 AM)
      final lateIn = _calculateLateIn(inTime);
      if (lateIn != "00:00") {
        remarks.add("LT");
      } else {
        // Check for Early In (before 9:00 AM)
        try {
          final parts = inTime.split(':');
          if (parts.length >= 2) {
            final hour = int.parse(parts[0]);
            if (hour < 9) {
              remarks.add("EL");
            }
          }
        } catch (_) {
        }
      }
    }

    // Check for Overtime (if OT time > 00:00)
    if (otTime != "00:00:00" && otTime != "00:00") {
      try {
        final parts = otTime.split(':');
        if (parts.isNotEmpty) {
          final hours = int.tryParse(parts[0]) ?? 0;
          final minutes = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
          if (hours > 0 || minutes > 0) {
            remarks.add("OT");
          }
        }
      } catch (_) {
      }
    }

    // Check for Early Out Allowed (if erl_out > 00:00)
    if (erlOut != "00:00") {
      try {
        final parts = erlOut.split(':');
        if (parts.isNotEmpty) {
          final hours = int.tryParse(parts[0]) ?? 0;
          final minutes = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
          if (hours > 0 || minutes > 0) {
            remarks.add("EOA");
          }
        }
      } catch (_) {
      }
    }

    return remarks.isEmpty ? "-" : remarks.join("-");
  }

  Map<String, dynamic> _buildSlotSummary(Map<String, dynamic> daily) {
    final inCntRaw = daily["in_count_total"];
    final outCntRaw = daily["out_count_total"];

    final int inCnt = (inCntRaw is int)
        ? inCntRaw
        : int.tryParse("$inCntRaw") ?? 0;
    final int outCnt = (outCntRaw is int)
        ? outCntRaw
        : int.tryParse("$outCntRaw") ?? 0;

    final finalPunch = (_punchResponse?["final_punch_type"] ?? "").toString();

    int slotNo;
    if (finalPunch == "IN") {
      slotNo = inCnt.clamp(1, 3);
    } else if (finalPunch == "OUT") {
      slotNo = outCnt.clamp(1, 3);
    } else {
      slotNo = (inCnt > outCnt ? inCnt : outCnt).clamp(1, 3);
      if (slotNo < 1) slotNo = 1;
    }

    String inKey(int n) => "in_time_$n";
    String outKey(int n) => "out_time_$n";

    final currentIn = _fmtTime(daily[inKey(slotNo)]);
    final currentOut = _fmtTime(daily[outKey(slotNo)]);

    return {
      "slotNo": slotNo,
      "finalPunch": finalPunch,
      "inCnt": inCnt,
      "outCnt": outCnt,
      "currentIn": currentIn,
      "currentOut": currentOut,
    };
  }

  /* ============================================================
     FULL-WIDTH Success Dialog
  ============================================================ */
  Future<void> _showSuccessDialogFullWidth() async {
    final data = _punchResponse ?? {};
    final daily = (data["daily"] as Map?)?.cast<String, dynamic>() ?? {};

    final punchType = (data["final_punch_type"] ?? "-").toString();
    final attendanceStatus = (daily["attendance_status"] ?? "-").toString();
    final totalWorkTime = (daily["total_work_time"] ?? "00:00:00").toString();
    final otTime = (daily["ot_time"] ?? "00:00:00").toString();
    final status = (daily["status"] ?? "OPEN").toString();

    final slotInfo = _buildSlotSummary(daily);
    final int currentSlot = (slotInfo["slotNo"] as int?) ?? 1;

    Widget slotCard(int n) {
      final inT = _fmtTime(daily["in_time_$n"]);
      final outT = _fmtTime(daily["out_time_$n"]);
      final dur = _slotDuration(inT, outT);
      final work = dur == null ? "-" : _durToHms(dur);

      final isCurrent = (currentSlot == n);

      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFF93C5FD)
                : const Color(0xFFE5E7EB),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Slot $n${isCurrent ? " (Current)" : ""}",
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("IN: $inT", style: const TextStyle(fontSize: 12)),
                Text("OUT: $outT", style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Work: $work",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
    }

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "success",
      barrierColor: Colors.black.withOpacity(0.45),
      pageBuilder: (_, __, ___) {
        final w = MediaQuery.of(context).size.width;
        final dialogW = (w * 0.94).clamp(320.0, 520.0);

        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: dialogW,
                margin: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      const Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        color: Color(0xFF16A34A),
                        size: 56,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Punch Successful!",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _DialogRow("Final Punch", punchType),
                      _DialogRow("Attendance", attendanceStatus),
                      _DialogRow("Day Status", status),
                      _DialogRow("Total Work", totalWorkTime),
                      _DialogRow("OT", otTime),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Current Slot Detail",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _DialogRow(
                              "Slot No",
                              slotInfo["slotNo"].toString(),
                            ),
                            _DialogRow(
                              "Slot IN",
                              slotInfo["currentIn"].toString(),
                            ),
                            _DialogRow(
                              "Slot OUT",
                              slotInfo["currentOut"].toString(),
                            ),
                            _DialogRow(
                              "Total IN",
                              slotInfo["inCnt"].toString(),
                            ),
                            _DialogRow(
                              "Total OUT",
                              slotInfo["outCnt"].toString(),
                            ),
                          ],
                        ),
                      ),
                      for (int i = 1; i <= currentSlot; i++) slotCard(i),
                      const SizedBox(height: 12),
                      Text(
                        "Location: ${_address ?? "Location unavailable"}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(14),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _goToAppShell();
                          },
                          child: const Text(
                            "OK",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /* ============================================================
     UI
  ============================================================ */
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && !_busy) {
          await _safeDisposeCamera();
          _goToAppShell();
        }
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: _isInitializing
              ? const Center(child: CupertinoActivityIndicator())
              : Column(
            children: [
              _buildHeader(),
              _buildLocationGateCard(),
              Expanded(
                child: _capturedFile != null
                    ? _buildPreviewView()
                    : (_cam == null
                    ? _buildPlaceholder()
                    : _buildCameraView()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              onPressed: _busy
                  ? null
                  : () async {
                await _safeDisposeCamera();
                _goToAppShell();
              },
              child: const Icon(CupertinoIcons.back, size: 28, color: _ink),
            ),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "My Selfie",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                const SizedBox(height: 2),
                Text(
                  _name.isEmpty ? "" : "Signed in as $_name",
                  style: const TextStyle(
                    fontSize: 12,
                    color: _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // location button removed; gating is now handled via the card below
          ],
        ),
      ),
    );
  }

  Widget _buildLocationGateCard({EdgeInsets? margin}) {
    if (_locOk) return const SizedBox.shrink();

    final isServiceOff = !_locServiceEnabled;
    final isPermOff = _locServiceEnabled && !_locPermissionGranted;

    final title = isServiceOff
        ? "Location Services OFF"
        : isPermOff
        ? "Location Permission Needed"
        : "Location Unavailable";

    final desc = isServiceOff
        ? "Please enable Location to submit punch."
        : isPermOff
        ? "Please allow location permission to submit punch."
        : "Please try again or check settings.";

    final primaryLabel = isServiceOff
        ? "Enable Location"
        : isPermOff
        ? "Grant Permission"
        : "Try Again";

    final onPrimary = isServiceOff
        ? () async => _openLocationSettings()
        : isPermOff
        ? () async {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      } else if (perm == LocationPermission.deniedForever) {
        await _openAppSettings();
      }
      await _loadLocation(silent: true);
    }
        : () async => _loadLocation(silent: true);

    return Container(
      margin:
      margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                CupertinoIcons.location_slash,
                size: 18,
                color: Color(0xFFB45309),
              ),
              SizedBox(width: 8),
              Text(
                "Location Required",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: TextStyle(
              color: Colors.black.withOpacity(0.55),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _busy ? null : () async => onPrimary(),
                  child: Text(
                    primaryLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _busy
                      ? null
                      : () async => _loadLocation(silent: true),
                  child: const Text(
                    "Refresh",
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceWarningCard({EdgeInsets? margin}) {
    // Only show if policy loaded, not EVERYONE mode, and out of range
    if (!_policyLoaded ||
        _locationMode == "EVERYONE" ||
        _baseLat == null ||
        _baseLng == null ||
        _isWithinRange) {
      return const SizedBox.shrink();
    }

    final distStr = _distanceFromBase >= 1000
        ? "${(_distanceFromBase / 1000).toStringAsFixed(1)} km"
        : "${_distanceFromBase.toStringAsFixed(0)} m";

    return Container(
      margin:
      margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                size: 18,
                color: Color(0xFFDC2626),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Too Far From Selfie Location",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "You are $distStr away",
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Selfie Location: ${_baseAddress ?? 'Unknown'}",
            style: TextStyle(
              color: Colors.black.withOpacity(0.65),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "You must be within $_allowedRadius meters to take selfie.",
            style: TextStyle(
              color: Colors.black.withOpacity(0.55),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
              onPressed: _busy
                  ? null
                  : () async {
                await _loadLocation(silent: true);
                _checkDistanceFromBase();
              },
              child: const Text(
                "Refresh Location",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                // location gate/info removed - selfies allowed anywhere
                GestureDetector(
                  onTap: _openingCamera ? null : _openCamera,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _cream.withOpacity(0.35),
                      border: Border.all(
                        color: Colors.black.withOpacity(0.18),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _openingCamera
                          ? const CupertinoActivityIndicator()
                          : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            CupertinoIcons.camera,
                            size: 34,
                            color: _muted,
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Take selfie",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Please capture selfie here!",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Tip: Keep face inside circle with good light",
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.45),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        if (_error != null)
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: _ErrorBox(message: _error!),
          ),
      ],
    );
  }

  /// Fixed camera preview (no nose-zoom)
  Widget _buildCameraView() {
    final cam = _cam;

    if (cam == null || _camDisposing || !cam.value.isInitialized) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (cam.value.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            "Camera error: ${cam.value.errorDescription ?? 'Unknown'}",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final isFront = (_selectedCam?.lensDirection == CameraLensDirection.front);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;

        final previewSize = cam.value.previewSize;
        if (previewSize == null) {
          return const Center(child: CupertinoActivityIndicator());
        }

        final previewAR = previewSize.height / previewSize.width;
        final screenAR = size.width / size.height;

        double scale;
        if (screenAR > previewAR) {
          scale = screenAR / previewAR;
        } else {
          scale = previewAR / screenAR;
        }
        if (scale < 1.0) scale = 1.0;

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scale(scale, scale)
                  ..rotateY(isFront ? math.pi : 0),
                child: Center(child: CameraPreview(cam)),
              ),
            ),

            // circle guide
            Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.85),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.20),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),

            // location gate handled by parent; capture button disabled when not ready
            if (_error != null)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: _ErrorBox(message: _error!),
              ),

            // capture button and camera switch
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Spacer for balance
                  const SizedBox(width: 60),

                  // Capture button
                  _busy
                      ? const CupertinoActivityIndicator(radius: 20)
                      : CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _captureSelfie,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: _ink, width: 6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 22,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Camera switch button
                  if (_availableCameras.length > 1)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _busy || _openingCamera ? null : _switchCamera,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.5),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.camera_rotate,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 50),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildLocationGateCard(),
          if (_error != null) ...[
            _ErrorBox(message: _error!),
            const SizedBox(height: 16),
          ],

          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Image.file(_capturedFile!, fit: BoxFit.cover),
            ),
          ),

          const SizedBox(height: 18),

          // remark
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Add Remark (Optional)",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: _remarkController,
                  placeholder: "Enter your remark here...",
                  maxLines: 3,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // actions
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: _busy
                      ? null
                      : () async {
                    // reset preview state
                    setState(() {
                      _capturedFile = null;
                      _watermarkedFile = null;
                      _isWatermarking = false;
                      _error = null;
                      _remarkController.clear();
                    });
                    await _openCamera();
                  },
                  child: const Text(
                    "Retake",
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(14),
                  onPressed: _busy ? null : _submitPunch,
                  child: _busy
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text(
                    "Submit",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Text(
            "Location: ${_address ?? "Location unavailable"}",
            style: TextStyle(
              color: Colors.black.withOpacity(0.45),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   Widgets
============================================================ */
class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: Color(0xFF991B1B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogRow extends StatelessWidget {
  final String label;
  final String value;

  const _DialogRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "$label:",
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
