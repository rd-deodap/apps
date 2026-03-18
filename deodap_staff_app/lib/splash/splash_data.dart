import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UpdateResult {
  final bool blocked;
  const UpdateResult({required this.blocked});
}

class AppUpdateService {
  final String apiUrl;

  const AppUpdateService({
    required this.apiUrl,
  });

  /// Returns UpdateResult(blocked: true) if a dialog is shown and app flow must stop.
  Future<UpdateResult> checkAndHandle({
    required BuildContext context,
    required String currentVersion,
    required VoidCallback onContinue, // call when user chooses Skip or Try Again completes
  }) async {
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode != 200) {
        return const UpdateResult(blocked: false);
      }

      final Map<String, dynamic> data = json.decode(response.body);

      final String latestVersion = (data['latest_version'] ?? '0.0.0').toString();
      final String downloadLink = (data['download_link'] ?? '').toString();
      final bool forceUpdate = (data['force_update'] ?? false) == true;
      final String message = (data['message'] ?? 'Update available').toString();

      // If latest > current, block and show dialog
      if (isNewVersion(latestVersion, currentVersion)) {
        if (downloadLink.trim().isEmpty) {
          _showMaintenanceDialog(
            context: context,
            message: message,
            onTryAgain: () async {
              Navigator.of(context).pop(); // close dialog
              // re-check
              final res = await checkAndHandle(
                context: context,
                currentVersion: currentVersion,
                onContinue: onContinue,
              );
              // If not blocked anymore, continue app flow
              if (!res.blocked) onContinue();
            },
          );
        } else {
          _showUpdateDialog(
            context: context,
            latestVersion: latestVersion,
            downloadLink: downloadLink,
            forceUpdate: forceUpdate,
            message: message,
            onSkip: () {
              Navigator.of(context).pop(); // close dialog
              onContinue();
            },
          );
        }

        return const UpdateResult(blocked: true);
      }

      return const UpdateResult(blocked: false);
    } catch (_) {
      // If API fails, do not block splash flow
      return const UpdateResult(blocked: false);
    }
  }

  bool isNewVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map((e) => int.parse(e)).toList();
      final currentParts = current.split('.').map((e) => int.parse(e)).toList();

      final maxLen = latestParts.length > currentParts.length
          ? latestParts.length
          : currentParts.length;

      for (int i = 0; i < maxLen; i++) {
        final l = i < latestParts.length ? latestParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;

        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  void _showMaintenanceDialog({
    required BuildContext context,
    required String message,
    required VoidCallback onTryAgain,
  }) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return PopScope(
          canPop: false,
          child: CupertinoAlertDialog(
            title: const Text('Server Maintenance ⚠️'),
            content: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Try Again'),
                onPressed: onTryAgain,
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('Exit App'),
                onPressed: () => SystemNavigator.pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUpdateDialog({
    required BuildContext context,
    required String latestVersion,
    required String downloadLink,
    required bool forceUpdate,
    required String message,
    required VoidCallback onSkip,
  }) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (_) {
        return PopScope(
          canPop: !forceUpdate,
          child: CupertinoAlertDialog(
            title: const Text('Update Available 🚀'),
            content: Text('$message\n\nv$latestVersion'),
            actions: [
              if (!forceUpdate)
                CupertinoDialogAction(
                  child: const Text('Skip'),
                  onPressed: onSkip,
                ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => openDownloadLink(context, downloadLink),
                child: const Text('Update Now'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> openDownloadLink(BuildContext context, String url) async {
    try {
      if (url.trim().isEmpty) throw 'URL is empty';
      var u = url.trim();
      if (!u.startsWith('http')) u = 'https://$u';

      final uri = Uri.parse(u);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $u';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }
}
