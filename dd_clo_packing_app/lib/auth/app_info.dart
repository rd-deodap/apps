// lib/common/app_info.dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// ====== API CONFIG (same as other WMS screens) ======
const String _kBaseUrl = 'https://api.vacalvers.com/api-clo-packaging-app';
const String _kAppId = '2';
const String _kApiKey = '022782f3-c4aa-443a-9f14-7698c648a137';

// ====== THEME ======
const Color kIOSPurple = Color(0xFF011D3E);
const Color kBg = Color(0xFFF7F8FA);

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data; // parsed "data" object from API

  Color get _primaryBlue => kIOSPurple;

  @override
  void initState() {
    super.initState();
    _fetchAppInfo();
  }

  Future<void> _fetchAppInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Using GET with query parameters: /app_info?app_id=1&api_key=...
      final uri = Uri.parse('$_kBaseUrl/app_info').replace(queryParameters: {
        'app_id': _kAppId,
        'api_key': _kApiKey,
      });

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final jsonBody = json.decode(res.body) as Map<String, dynamic>;
        if (jsonBody['status'] == 'success' && jsonBody['data'] != null) {
          setState(() {
            _data = Map<String, dynamic>.from(jsonBody['data']);
          });
        } else {
          setState(() {
            _error = jsonBody['message']?.toString().trim().isNotEmpty == true
                ? jsonBody['message'].toString()
                : 'Unable to load app info.';
          });
        }
      } else {
        setState(() {
          _error = 'Server error: ${res.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load app info.\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _launchUrlExternal(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('Could not open: ${uri.toString()}'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // ====== UI HELPERS ======

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 0.4,
          color: CupertinoColors.systemGrey,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _group(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _cell({
    required String title,
    String? value,
    Widget? trailing,
    bool isFirst = false,
    bool isLast = false,
    VoidCallback? onTap,
    TextStyle? valueStyle,
  }) {
    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(12) : Radius.zero,
      bottom: isLast ? const Radius.circular(12) : Radius.zero,
    );

    final textValue = value ?? '';

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        color: CupertinoColors.systemBackground,
        child: CupertinoButton(
          onPressed: onTap,
          padding: EdgeInsets.zero,
          pressedOpacity: onTap == null ? 1.0 : 0.6,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: isLast
                    ? BorderSide.none
                    : const BorderSide(
                        color: CupertinoColors.separator,
                        width: 0.3,
                      ),
              ),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.systemGrey,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        textValue.isEmpty ? '—' : textValue,
                        style: valueStyle ??
                            const TextStyle(
                              fontSize: 16,
                              color: CupertinoColors.label,
                              decoration: TextDecoration.none,
                            ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    final isOffline = (_data?['is_offline'] ?? 0) == 1;
    final color =
        isOffline ? CupertinoColors.systemRed : CupertinoColors.systemGreen;
    final label = isOffline ? 'Offline Mode' : 'Online';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOffline
                ? CupertinoIcons.wifi_exclamationmark
                : CupertinoIcons.wifi,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 2),
            color: Colors.black12,
          ),
        ],
      ),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 32,
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Row(
              children: [
                Icon(
                  CupertinoIcons.back,
                  size: 22,
                  color: CupertinoColors.label,
                ),
                SizedBox(width: 2),
                Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.label,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'App Info',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_data != null) _buildStatusChip() else const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildTopState() {
    if (_loading && _data == null) {
      return const Row(
        children: [
          CupertinoActivityIndicator(),
          SizedBox(width: 8),
          Text(
            'Loading app information…',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unable to load app info',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.systemRed,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error!,
            style: const TextStyle(
              fontSize: 13,
              color: CupertinoColors.systemGrey,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: _primaryBlue,
            onPressed: _fetchAppInfo,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (_data == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _data?['brand_name'] ?? 'DeoDap',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _data?['name'] ?? 'DeoDap Packaging App',
          style: const TextStyle(
            fontSize: 15,
            color: CupertinoColors.systemGrey,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CupertinoTheme(
        data: CupertinoTheme.of(context).copyWith(primaryColor: _primaryBlue),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    CupertinoSliverRefreshControl(onRefresh: _fetchAppInfo),

                    // TOP STATE
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: _buildTopState(),
                      ),
                    ),

                    if (_data != null) ...[
                      // GENERAL
                      SliverToBoxAdapter(
                        child: _sectionHeader('General'),
                      ),
                      SliverToBoxAdapter(
                        child: _group([
                          _cell(
                            isFirst: true,
                            title: 'App Name',
                            value: _data?['name']?.toString(),
                          ),
                          _cell(
                            title: 'Brand Name',
                            value: _data?['brand_name']?.toString(),
                          ),
                          _cell(
                            isLast: true,
                            title: 'Version',
                            value: _data?['version']?.toString(),
                          ),
                        ]),
                      ),

                      // IDENTIFIERS
                      SliverToBoxAdapter(
                        child: _sectionHeader('Identifiers'),
                      ),
                      SliverToBoxAdapter(
                        child: _group([
                          _cell(
                            isFirst: true,
                            title: 'App ID',
                            value: _data?['id']?.toString(),
                          ),
                          _cell(
                            title: 'Warehouse ID',
                            value: _data?['warehouse_id']?.toString(),
                          ),
                          _cell(
                            title: 'Pixel Tracking ID',
                            value:
                                _data?['pixel_tracking_id']?.toString(),
                            valueStyle: const TextStyle(
                              fontSize: 15,
                              color: CupertinoColors.label,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          _cell(
                            isLast: true,
                            title: 'Google Analytics Tracking ID',
                            value: _data?['google_analytics_tracking_id']
                                ?.toString(),
                            valueStyle: const TextStyle(
                              fontSize: 15,
                              color: CupertinoColors.label,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ]),
                      ),

                      // ASSETS
                      SliverToBoxAdapter(
                        child: _sectionHeader('Assets & Token'),
                      ),
                      SliverToBoxAdapter(
                        child: _group([
                          _cell(
                            isFirst: true,
                            title: 'Assets Base URL',
                            value: _data?['assets_base_url']?.toString(),
                            trailing: (_data?['assets_base_url'] != null &&
                                    (_data!['assets_base_url'] as String)
                                        .trim()
                                        .isNotEmpty)
                                ? const Icon(
                                    CupertinoIcons
                                        .arrow_up_right_square,
                                    size: 18,
                                    color: CupertinoColors.activeBlue,
                                  )
                                : null,
                            onTap: (_data?['assets_base_url'] != null &&
                                    (_data!['assets_base_url'] as String)
                                        .trim()
                                        .isNotEmpty)
                                ? () {
                                    final url = _data!['assets_base_url']
                                        .toString()
                                        .trim();
                                    _launchUrlExternal(Uri.parse(url));
                                  }
                                : null,
                          ),
                          _cell(
                            isLast: true,
                            title: 'Token',
                            value: _data?['token']?.toString(),
                            valueStyle: const TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.systemGrey,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ]),
                      ),
                    ],

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 24),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
