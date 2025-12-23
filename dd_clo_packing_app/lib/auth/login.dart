import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../route/app_route.dart';
import '../theme/app_color.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- Controllers ---
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // --- UI State ---
  bool _obscure = true;
  bool _loading = false;
  bool _rememberMe = true;

  // --- Warehouse data/state ---
  List<Map<String, dynamic>> _warehouses = []; // [{id,label}, ...]
  bool _loadingWarehouses = false;
  String? _selectedWarehouseId; // stored internally
  String? _selectedWarehouseLabel; // user-facing

  // --- API Config ---
  static const String baseUrl = 'https://api.vacalvers.com/api-clo-packaging-app';
  static const String appId = '2';
  static const String apiKey = '022782f3-c4aa-443a-9f14-7698c648a137';

  // --- Theme helper ---
  Color get _primary => AppColors.navyblue;

  // guard for auto navigation to avoid double pushes
  bool _welcomeNavigated = false;
  Timer? _welcomeTimer;

  @override
  void initState() {
    super.initState();
    _hydrateFromPrefs();
    _restoreCachedWarehouses();
    _fetchWarehouses();
  }

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ========== PERSISTENCE ==========

  Future<void> _hydrateFromPrefs() async {
    final p = await SharedPreferences.getInstance();
    final savedPhone = p.getString('username');
    final savedWarehouseId = p.getString('warehouse');
    final remember = p.getBool('rememberMe') ?? true;

    setState(() {
      _rememberMe = remember;
      if (remember && savedPhone != null) _phoneCtrl.text = savedPhone;
      if (remember && savedWarehouseId != null && savedWarehouseId.isNotEmpty) {
        _selectedWarehouseId = savedWarehouseId;
      }
    });
  }

  Future<void> _restoreCachedWarehouses() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('cached_warehouses');
    if (raw != null && raw.isNotEmpty) {
      try {
        final cached = List<Map<String, dynamic>>.from(jsonDecode(raw));
        setState(() => _warehouses = cached);
        _syncSelectedWarehouseLabel();
      } catch (_) {
        // ignore parsing errors for cache
      }
    }
  }

  Future<void> _cacheWarehouses(List<Map<String, dynamic>> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('cached_warehouses', jsonEncode(list));
  }

  Future<void> _saveRememberMe() async {
    final p = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await p.setString('username', _phoneCtrl.text.trim());
      await p.setString('warehouse', _selectedWarehouseId ?? '');
      await p.setBool('rememberMe', true);
    } else {
      await p.remove('username');
      await p.remove('warehouse');
      await p.setBool('rememberMe', false);
    }
  }

  Future<void> _saveLoginSession(Map<String, dynamic> res) async {
    final p = await SharedPreferences.getInstance();
    final data = res['data'];
    final user = data['user'];
    final token = data['token'];

    await p.setBool('isLoggedIn', true);
    await p.setString('authToken', token ?? '');
    await p.setString('currentUser', _phoneCtrl.text.trim());
    await p.setString('currentWarehouse', _selectedWarehouseId ?? '');
    await p.setString(
      'currentWarehouseLabel',
      _selectedWarehouseLabel ?? '',
    );
    await p.setString('loginTime', DateTime.now().toIso8601String());

    final userId = user['id'] is int ? user['id'] : int.tryParse('${user['id']}') ?? 0;
    await p.setInt('userId', userId);

    await p.setString('userName', '${user['name'] ?? ''}');
    await p.setString('userPhone', '${user['phone'] ?? ''}');

    final warehouseId = user['warehouse_id'] is int ? user['warehouse_id'] : int.tryParse('${user['warehouse_id']}') ?? 0;
    await p.setInt('warehouseId', warehouseId);

    final isReadonly = user['is_readonly'] is int ? user['is_readonly'] : int.tryParse('${user['is_readonly']}') ?? 0;
    await p.setInt('isReadonly', isReadonly);

    if (data['stock_physical_locations'] != null) {
      await p.setString(
        'stockLocations',
        jsonEncode(data['stock_physical_locations']),
      );
    }
  }

  // ========== NETWORK ==========

  Future<void> _fetchWarehouses() async {
    if (mounted) setState(() => _loadingWarehouses = true);
    try {
      final uri = Uri.parse('$baseUrl/app_info/warehouse_list').replace(
        queryParameters: {'app_id': appId, 'api_key': apiKey},
      );

      debugPrint('Fetching warehouses from: $uri');

      final res = await http
          .get(
        uri,
        headers: const {'Accept': 'application/json'},
      )
          .timeout(const Duration(seconds: 30));

      debugPrint('Warehouse API response status: ${res.statusCode}');
      debugPrint('Response body: ${res.body}');

      if (res.statusCode == 200) {
        try {
          final j = jsonDecode(res.body);
          debugPrint('Decoded JSON: $j');

          final status = (j['status'] ?? '').toString().toLowerCase();
          if (status == 'success' && j['data'] != null) {
            final data = j['data'];
            if (data is! List) {
              debugPrint('Expected List but got: ${data.runtimeType}');
              _toast('Invalid warehouse data format');
              return;
            }

            final list = List<Map<String, dynamic>>.from(data)
              ..sort((a, b) =>
                  a['label'].toString().compareTo(b['label'].toString()));

            debugPrint('Fetched ${list.length} warehouses');

            if (mounted) {
              setState(() => _warehouses = list);
              await _cacheWarehouses(list);
              _syncSelectedWarehouseLabel();
            }
          } else {
            final errorMsg =
            j['message']?.toString().trim().isNotEmpty == true
                ? j['message'].toString()
                : 'Unable to load warehouses';
            debugPrint('API Error: $errorMsg');
            _toast(errorMsg);
          }
        } catch (e) {
          debugPrint('JSON parsing error: $e');
          _toast('Error processing warehouse data');
        }
      } else {
        debugPrint('API Error ${res.statusCode}: ${res.body}');
        _toast('Warehouse API error (${res.statusCode})');
      }
    } on http.ClientException catch (e) {
      debugPrint('Network error: $e');
      _toast('Network error: ${e.message}');
    } on TimeoutException {
      debugPrint('Request timed out');
      _toast('Request timed out. Please check your connection.');
    } catch (e, stack) {
      debugPrint('Unexpected error: $e\n$stack');
      _toast('Failed to load warehouses');
    } finally {
      if (mounted) setState(() => _loadingWarehouses = false);
    }
  }

  void _syncSelectedWarehouseLabel() {
    if (_selectedWarehouseId == null) return;
    final m =
    _warehouses.where((e) => e['id'].toString() == _selectedWarehouseId);
    if (m.isNotEmpty) {
      _selectedWarehouseLabel = m.first['label']?.toString();
    }
  }

  Future<Map<String, dynamic>?> _performLogin() async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');
      final res = await http.post(
        url,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'app_id': appId,
          'api_key': apiKey,
          'phone': _phoneCtrl.text.trim(),
          'password': _passCtrl.text,
          'warehouse': _selectedWarehouseId ?? '',
        }),
      );

      debugPrint('Login status: ${res.statusCode}');
      debugPrint('Login body: ${res.body}');

      final j = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final status = (j['status'] ?? '').toString().toLowerCase();
        if (status == 'success' && j['data'] != null) {
          return j;
        }

        final msg =
        j['message']?.toString().trim().isNotEmpty == true
            ? j['message'].toString()
            : 'Login failed. Please try again.';
        _showError(msg);
        return null;
      } else {
        _showError('Login API error (${res.statusCode}).');
        return null;
      }
    } catch (e) {
      debugPrint('Login error: $e');
      _showError('Network error. Please check your connection.');
      return null;
    }
  }

  // ========== DIALOGS / TOASTS ==========

  void _toast(String msg) {
    if (!mounted) return;
    Get.rawSnackbar(
      message: msg,
      duration: const Duration(seconds: 2),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
    );
  }

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Login Failed'),
        content: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(msg),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String body) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(body),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Shows welcome dialog and navigates to home after 3 seconds or when dismissed
  void _welcomeAutoGo() {
    if (_welcomeNavigated) return;
    _welcomeNavigated = true; // ડબલ નેવિગેશન અટકાવવા માટે તરત જ સેટ કરો

    // 1. વેલકમ ડાયલોગ બતાવો
    showCupertinoDialog(
      context: context,
      barrierDismissible: false, // યુઝર બહાર ક્લિક કરીને બંધ ન કરી શકે
      builder: (_) => PopScope(
        canPop: false, // Android બેક બટનથી પણ બંધ ન કરી શકે
        child: const CupertinoAlertDialog(
          title: Text('Welcome back'),
          content: Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('DeoDap employee • CLO Management System'),
          ),
        ),
      ),
    ).then((_) {

      _welcomeTimer?.cancel();
      if (mounted) {
        Get.offAllNamed(AppRoutes.home);
      }
    });


    _welcomeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;


      Navigator.of(context, rootNavigator: true).pop();
    });
  }

  // ========== ACTIONS ==========

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWarehouseId == null) {
      _showError('Please select a warehouse.');
      return;
    }

    setState(() => _loading = true);
    final res = await _performLogin();
    if (!mounted) return;

    if (res != null) {
      await _saveRememberMe();
      await _saveLoginSession(res);
      setState(() => _loading = false);
      _welcomeAutoGo(); // auto dialog + navigation
    } else {
      setState(() => _loading = false);
    }
  }

  // ========== UI ==========

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final base = size.width;
    final isTablet = base >= 720;

    final titleSize =
    (isTablet ? base * 0.035 : base * 0.075).clamp(20, 34).toDouble();
    final labelSize =
    (isTablet ? base * 0.018 : base * 0.040).clamp(12, 18).toDouble();
    final horizontal = (base * 0.08).clamp(18, 36).toDouble();
    final logoHeight = (isTablet ? 140 : 120).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding:
            EdgeInsets.symmetric(horizontal: horizontal, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Header section (logo + title + subtitle) ---
                  LoginHeader(
                    logoHeight: logoHeight,
                    titleSize: titleSize,
                    labelSize: labelSize,
                  ),

                  const SizedBox(height: 24),

                  // --- Form + card section ---
                  _buildLoginCard(),

                  const SizedBox(height: 18),

                  // --- Footer section ---
                  const LoginFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Login Card (form, warehouse, remember, button, links) ----------
  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Phone
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                label: 'Phone Number',
                hint: 'Enter phone number',
                icon: CupertinoIcons.phone,
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) {
                  return 'Phone number is required';
                }
                if (!RegExp(r'^\d{10,15}$').hasMatch(t)) {
                  return 'Enter valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Password
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              decoration: _inputDecoration(
                label: 'Password',
                hint: 'Enter password',
                icon: CupertinoIcons.lock,
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? CupertinoIcons.eye
                        : CupertinoIcons.eye_slash,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Password is required';
                }
                if (v.length < 2) {
                  return 'Minimum 2 characters';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),

            // Warehouse picker
            _warehouseSelector(context),

            const SizedBox(height: 14),

            // Remember me + loader
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (v) =>
                      setState(() => _rememberMe = v ?? false),
                  activeColor: _primary,
                ),
                const Text('Remember Me'),
                const Spacer(),
                if (_loadingWarehouses)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CupertinoActivityIndicator(radius: 8),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Login button
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                onPressed: _loading ? null : _submit,
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: _primary,
                borderRadius: BorderRadius.circular(12),
                child: _loading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CupertinoActivityIndicator(),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Login',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      CupertinoIcons.arrow_right_circle_fill,
                      color: Colors.white,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Links row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LinkButton(
                  label: 'Forgot Password?',
                  onTap: () => _showInfoDialog(
                    'Password Reset',
                    'Contact your admin to change your password.',
                  ),
                ),
                _LinkButton(
                  label: 'Sign Up',
                  onTap: () => _showInfoDialog(
                    'Registration',
                    'Your admin can register your account.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Warehouse selector ----------
  Widget _warehouseSelector(BuildContext context) {
    final chosen = _selectedWarehouseLabel ?? 'Select warehouse';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openWarehouseDialog(context),
      child: InputDecorator(
        decoration: _inputDecoration(
          label: 'Warehouse',
          hint: 'Choose from list',
          icon: CupertinoIcons.house,
          suffix: const Icon(CupertinoIcons.chevron_down),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            chosen,
            style: TextStyle(
              color: _selectedWarehouseLabel == null
                  ? Colors.black45
                  : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openWarehouseDialog(BuildContext context) async {
    if (_warehouses.isEmpty && !_loadingWarehouses) {
      _fetchWarehouses();
    }

    String filter = '';

    await showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final items = _warehouses
                .where((w) {
              if (filter.isEmpty) return true;
              final label = (w['label'] ?? '').toString();
              return label
                  .toLowerCase()
                  .contains(filter.toLowerCase());
            })
                .toList()
              ..sort((a, b) =>
                  a['label'].toString().compareTo(b['label'].toString()));

            return CupertinoAlertDialog(
              title: const Text('Select Warehouse'),
              content: Column(
                children: [
                  const SizedBox(height: 10),
                  _CupertinoSearchField(
                    hintText: 'Search by warehouse name',
                    onChanged: (v) =>
                        setSheet(() => filter = v.trim()),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 260,
                    child: _loadingWarehouses && _warehouses.isEmpty
                        ? const Center(
                      child: CupertinoActivityIndicator(),
                    )
                        : (items.isEmpty
                        ? const Center(
                      child: Text(
                        'No results',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CupertinoPopupSurface(
                        isSurfacePainted: true,
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          physics:
                          const BouncingScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                          const Divider(
                            height: 1,
                            color: Color(0xFFE5E7EB),
                          ),
                          itemBuilder: (_, i) {
                            final w = items[i];
                            final id = w['id'].toString();
                            final label =
                            w['label'].toString();
                            final selected =
                                _selectedWarehouseId == id;

                            return _CupertinoListTile(
                              title: label,
                              selected: selected,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                _primary.withOpacity(
                                    0.10),
                                child: Icon(
                                  CupertinoIcons.house_fill,
                                  color: _primary,
                                  size: 18,
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedWarehouseId = id;
                                  _selectedWarehouseLabel =
                                      label;
                                });
                                Navigator.of(ctx).pop();
                                _toast(
                                    'Warehouse set: $label');
                              },
                            );
                          },
                        ),
                      ),
                    )),
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                CupertinoDialogAction(
                  onPressed: () async {
                    await _fetchWarehouses();
                    setSheet(() {});
                  },
                  isDefaultAction: true,
                  child: const Text('Refresh'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------- Input decoration ----------
  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7F7F8),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primary, width: 1),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.red, width: 1),
      ),
    );
  }
}

/// ====================
/// HEADER WIDGET
/// ====================
class LoginHeader extends StatelessWidget {
  final double logoHeight;
  final double titleSize;
  final double labelSize;

  const LoginHeader({
    super.key,
    required this.logoHeight,
    required this.titleSize,
    required this.labelSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Center(
            child: Image.asset(
              'assets/images/login.png',
              height: logoHeight,
              fit: BoxFit.contain,
            ),
          ),
        ),

        // Title
        Text(
          'CLO Warehouse Management',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            textStyle: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your credentials to continue',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            textStyle: TextStyle(
              color: AppColors.textMuted,
              fontSize: labelSize,
            ),
          ),
        ),
      ],
    );
  }
}

/// ====================
/// FOOTER WIDGET
/// ====================
class LoginFooter extends StatelessWidget {
  const LoginFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      '© ${DateTime.now().year} DeoDap • All rights reserved.',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.black54,
        fontSize: 12,
      ),
    );
  }
}

/// --- Tapable text link ---
class _LinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkButton({required this.label, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.navyblue,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

/// --- Lightweight iOS search box ---
class _CupertinoSearchField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;

  const _CupertinoSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      placeholder: hintText,
      prefix: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.0),
        child: Icon(
          CupertinoIcons.search,
          size: 18,
          color: Color(0xFF6B7280),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      onChanged: onChanged,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      clearButtonMode: OverlayVisibilityMode.editing,
    );
  }
}

/// --- Minimal iOS list tile for the popup ---
class _CupertinoListTile extends StatelessWidget {
  final String title;
  final bool selected;
  final Widget? leading;
  final VoidCallback? onTap;

  const _CupertinoListTile({
    super.key,
    required this.title,
    this.selected = false,
    this.leading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              if (leading != null) leading!,
              if (leading != null) const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: Tween(begin: 0.8, end: 1.0).animate(anim),
                  child: child,
                ),
                child: selected
                    ? const Icon(
                  CupertinoIcons.check_mark_circled_solid,
                  color: Color(0xFF34C759),
                  key: ValueKey('sel'),
                )
                    : const SizedBox.shrink(
                  key: ValueKey('nosel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}