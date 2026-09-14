import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/// The repo whose GitHub Releases carry the signed APK. Same endpoint CI
/// publishes to, so shipping an update is: tag, wait, tap.
const String kRepo = 'scenicprints/gymfolio';

class UpdateInfo {
  final String version;
  final String tag;
  final String? apkUrl;
  final String releaseUrl;
  final String? notes;

  UpdateInfo({
    required this.version,
    required this.tag,
    required this.apkUrl,
    required this.releaseUrl,
    this.notes,
  });
}

String _stripV(String s) {
  s = s.trim();
  return s.startsWith('v') ? s.substring(1) : s;
}

/// >0 if [a] is newer than [b].
int compareVersions(String a, String b) {
  List<int> parse(String s) {
    s = _stripV(s).split('+').first.split('-').first;
    final parts = s.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  final pa = parse(a), pb = parse(b);
  for (var i = 0; i < 3; i++) {
    if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
  }
  return 0;
}

Future<String> currentVersion() async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
}

Future<UpdateInfo?> fetchLatestRelease() async {
  final res = await http.get(
    Uri.parse('https://api.github.com/repos/$kRepo/releases/latest'),
    headers: {'Accept': 'application/vnd.github+json'},
  ).timeout(const Duration(seconds: 12));
  if (res.statusCode != 200) return null;

  final data = json.decode(res.body) as Map<String, dynamic>;
  final tag = (data['tag_name'] as String?) ?? '';
  String? apkUrl;
  for (final a in (data['assets'] as List? ?? const [])) {
    final name = (a['name'] as String?) ?? '';
    if (name.toLowerCase().endsWith('.apk')) {
      apkUrl = a['browser_download_url'] as String?;
      break;
    }
  }
  return UpdateInfo(
    version: _stripV(tag),
    tag: tag,
    apkUrl: apkUrl,
    releaseUrl:
        (data['html_url'] as String?) ?? 'https://github.com/$kRepo/releases',
    notes: data['body'] as String?,
  );
}

Future<UpdateInfo?> checkForUpdate() async {
  try {
    final current = await currentVersion();
    final latest = await fetchLatestRelease();
    if (latest == null) return null;
    return compareVersions(latest.version, current) > 0 ? latest : null;
  } catch (_) {
    return null;
  }
}

/// Silent launch check — only ever surfaces UI when there is something new.
Future<void> autoCheck(BuildContext context) async {
  if (kIsWeb) return;
  final info = await checkForUpdate();
  if (info != null && context.mounted) {
    await showUpdateDialog(context, info);
  }
}

Future<void> manualCheck(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  if (kIsWeb) {
    messenger.showSnackBar(
        const SnackBar(content: Text('Updates only apply to the Android build.')));
    return;
  }
  messenger
      .showSnackBar(const SnackBar(content: Text('Checking for updates…')));
  final current = await currentVersion();
  final latest = await fetchLatestRelease();
  if (!context.mounted) return;
  messenger.hideCurrentSnackBar();

  if (latest == null) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Could not reach GitHub. Check your connection.')));
    return;
  }
  if (compareVersions(latest.version, current) > 0) {
    await showUpdateDialog(context, latest);
  } else {
    messenger.showSnackBar(
        SnackBar(content: Text("You're on the latest version (v$current).")));
  }
}

Future<void> launchDownload(UpdateInfo info) async {
  final url = info.apkUrl ?? info.releaseUrl;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Downloads the APK in-app and hands it straight to Android's installer.
/// Android still shows its own confirm screen — this only removes the
/// file-hunting in between.
Future<void> downloadAndInstall(
  UpdateInfo info, {
  void Function(double? progress, String status)? onStatus,
}) async {
  final url = info.apkUrl ?? info.releaseUrl;
  final client = http.Client();
  try {
    onStatus?.call(null, 'Connecting…');
    final resp = await client.send(http.Request('GET', Uri.parse(url)));
    final total = resp.contentLength ?? 0;

    final dir =
        await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    // Reuse one file and clear leftovers so updates never pile up on device.
    try {
      for (final f in dir.listSync()) {
        if (f is File && f.path.toLowerCase().endsWith('.apk')) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}

    final file = File('${dir.path}/gymfolio-update.apk');
    final sink = file.openWrite();
    var received = 0;
    await for (final chunk in resp.stream) {
      received += chunk.length;
      sink.add(chunk);
      final p = total > 0 ? received / total : null;
      onStatus?.call(
          p, 'Downloading… ${p != null ? '${(p * 100).round()}%' : ''}');
    }
    await sink.close();

    onStatus?.call(1.0, 'Opening installer…');
    await OpenFilex.open(file.path,
        type: 'application/vnd.android.package-archive');
  } finally {
    client.close();
  }
}

Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Tone.surface,
      title: const Text('Update available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GymFolio ${info.tag} is ready to install.'),
          if ((info.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(info.notes!.trim(),
                    style: const TextStyle(fontSize: 13, color: Tone.dim)),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () {
            final messenger = ScaffoldMessenger.of(context);
            Navigator.pop(context);
            messenger.showSnackBar(
                const SnackBar(content: Text('Downloading update…')));
            downloadAndInstall(info).catchError((_) {
              messenger.showSnackBar(const SnackBar(
                  content: Text(
                      'Update download failed — try again from Settings.')));
            });
          },
          child: const Text('Update'),
        ),
      ],
    ),
  );
}
