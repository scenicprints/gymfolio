import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/// The self-update path.
///
/// Every step here is checked and every failure names itself, because the
/// first version of this was a fire-and-forget snackbar that said "update
/// failed" and nothing else — which is useless the one time it matters.
///
/// In particular `OpenFilex.open` RETURNS a failure, it does not throw. An
/// ignored result is how a denied install permission turns into silence.

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
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  } catch (_) {
    return '0.0.0';
  }
}

Future<UpdateInfo?> fetchLatestRelease() async {
  final res = await http.get(
    Uri.parse('https://api.github.com/repos/$kRepo/releases/latest'),
    headers: {'Accept': 'application/vnd.github+json'},
  ).timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw 'GitHub returned ${res.statusCode} looking for the latest release.';
  }

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

/// Silent launch check — only surfaces UI when there is something new.
Future<void> autoCheck(BuildContext context) async {
  if (kIsWeb) return;
  final info = await checkForUpdate();
  if (info != null && context.mounted) {
    await showUpdateSheet(context, info);
  }
}

Future<void> manualCheck(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  if (kIsWeb) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Updates only apply to the Android build.')));
    return;
  }
  messenger.showSnackBar(const SnackBar(content: Text('Checking…')));

  final current = await currentVersion();
  UpdateInfo? latest;
  Object? err;
  try {
    latest = await fetchLatestRelease();
  } catch (e) {
    err = e;
  }
  if (!context.mounted) return;
  messenger.hideCurrentSnackBar();

  if (latest == null) {
    messenger.showSnackBar(SnackBar(
      content: Text(err == null
          ? 'Could not reach GitHub. Check your connection.'
          : '$err'),
      duration: const Duration(seconds: 6),
    ));
    return;
  }
  if (compareVersions(latest.version, current) > 0) {
    await showUpdateSheet(context, latest);
  } else {
    messenger.showSnackBar(
        SnackBar(content: Text("You're on the latest version (v$current).")));
  }
}

/// What went wrong, in enough detail to act on.
class UpdateFailure {
  final String headline;
  final String detail;
  final bool likelyPermission;
  const UpdateFailure(this.headline, this.detail,
      {this.likelyPermission = false});
}

/// Downloads the APK and hands it to Android's installer. Returns null on
/// success, or the reason it could not.
Future<UpdateFailure?> downloadAndInstall(
  UpdateInfo info, {
  void Function(double? progress, String status)? onStatus,
}) async {
  final url = info.apkUrl;
  if (url == null) {
    return const UpdateFailure('No APK on that release',
        'The release exists but carries no .apk asset. The build may still be running.');
  }

  final client = http.Client();
  File? file;
  try {
    onStatus?.call(null, 'Connecting…');
    final req = http.Request('GET', Uri.parse(url))..followRedirects = true;
    final resp = await client.send(req).timeout(const Duration(seconds: 30));

    // GitHub 302s to a signed asset host. If that is not followed, or the
    // asset is gone, we would happily save an HTML error page as an .apk and
    // hand it to the installer, which reports a parse error and tells you
    // nothing.
    if (resp.statusCode != 200) {
      return UpdateFailure('Download refused',
          'The server answered ${resp.statusCode} for\n$url');
    }

    final total = resp.contentLength ?? 0;
    final dir =
        await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    try {
      for (final f in dir.listSync()) {
        if (f is File && f.path.toLowerCase().endsWith('.apk')) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}

    file = File('${dir.path}/gymfolio-update.apk');
    final sink = file.openWrite();
    var received = 0;
    await for (final chunk in resp.stream) {
      received += chunk.length;
      sink.add(chunk);
      final p = total > 0 ? received / total : null;
      onStatus?.call(p,
          p != null ? 'Downloading ${(p * 100).round()}%' : 'Downloading…');
    }
    await sink.close();

    // Verify we actually have an APK before bothering the installer.
    final size = await file.length();
    if (total > 0 && size != total) {
      return UpdateFailure('Download was cut short',
          'Got $size bytes of $total. Try again on a better connection.');
    }
    final head = await file.openRead(0, 2).first;
    if (head.length < 2 || head[0] != 0x50 || head[1] != 0x4B) {
      return UpdateFailure('That is not an APK',
          'The downloaded file does not start with a zip header, so the '
          'installer would only say "problem parsing the package". '
          '$size bytes from\n$url');
    }

    onStatus?.call(1.0, 'Opening the installer…');
    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );

    // This is the step that used to fail silently: open_filex REPORTS the
    // problem in its return value rather than throwing.
    switch (result.type) {
      case ResultType.done:
        return null;
      case ResultType.permissionDenied:
        return UpdateFailure(
          'Android blocked the install',
          'GymFolio needs "Install unknown apps" for this to work.\n\n'
              'Settings → Apps → GymFolio → Install unknown apps → allow.\n\n'
              '(${result.message})',
          likelyPermission: true,
        );
      case ResultType.noAppToOpen:
        return UpdateFailure(
          'Nothing handled the APK',
          'No installer answered the request. Allow "Install unknown apps" '
              'for GymFolio, or use the browser fallback below.\n\n'
              '(${result.message})',
          likelyPermission: true,
        );
      case ResultType.fileNotFound:
        return UpdateFailure('The download vanished',
            'Saved to ${file.path} but the installer could not find it.');
      case ResultType.error:
        return UpdateFailure('The installer refused it', result.message);
    }
  } on SocketException catch (e) {
    return UpdateFailure('No connection', '$e');
  } catch (e) {
    return UpdateFailure('Update failed', '$e');
  } finally {
    client.close();
  }
}

Future<void> showUpdateSheet(BuildContext context, UpdateInfo info) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _UpdateSheet(info: info),
  );
}

class _UpdateSheet extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateSheet({required this.info});

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  bool _busy = false;
  double? _progress;
  String _status = '';
  UpdateFailure? _failure;
  String _current = '';

  @override
  void initState() {
    super.initState();
    currentVersion().then((v) {
      if (mounted) setState(() => _current = v);
    });
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _failure = null;
      _progress = null;
      _status = 'Starting…';
    });
    final f = await downloadAndInstall(
      widget.info,
      onStatus: (p, s) {
        if (!mounted) return;
        setState(() {
          _progress = p;
          _status = s;
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = f;
      if (f == null) _status = 'Handed to the installer.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.info;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('UPDATE', style: display(30)),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Pill(i.tag, color: Tone.good),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _current.isEmpty ? '' : 'You are on v$_current.',
              style: const TextStyle(color: Tone.dim, fontSize: 13.5),
            ),
            const SizedBox(height: 14),

            if ((i.notes ?? '').trim().isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 190),
                child: SingleChildScrollView(
                  child: Text(i.notes!.trim(),
                      style: const TextStyle(
                          fontSize: 13, color: Tone.dim, height: 1.45)),
                ),
              ),

            if (_busy) ...[
              const SizedBox(height: 18),
              LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: Tone.surfaceHi,
                valueColor: const AlwaysStoppedAnimation(Tone.action),
              ),
              const SizedBox(height: 8),
              Text(_status, style: const TextStyle(color: Tone.dim)),
            ],

            if (!_busy && _failure == null && _status.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.check_circle, color: Tone.good, size: 19),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_status,
                        style: const TextStyle(color: Tone.good))),
              ]),
              const SizedBox(height: 6),
              const Text(
                'Android shows its own confirm screen — that part is not '
                'something an app is allowed to skip.',
                style: TextStyle(color: Tone.faint, fontSize: 12.5, height: 1.4),
              ),
            ],

            if (_failure != null) ...[
              const SizedBox(height: 16),
              Panel(
                rail: Tone.bad,
                fill: Tone.bad.withValues(alpha: 0.09),
                border: Tone.bad.withValues(alpha: 0.45),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_failure!.headline,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 7),
                    SelectableText(
                      _failure!.detail,
                      style: const TextStyle(
                          color: Tone.dim, fontSize: 12.5, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                      text: '${_failure!.headline}\n${_failure!.detail}'));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error copied.')));
                },
                icon: const Icon(Icons.copy, size: 17),
                label: const Text('Copy the error'),
              ),
            ],

            const SizedBox(height: 16),
            if (!_busy)
              FilledButton(
                onPressed: _run,
                child: Text(_failure == null ? 'Update' : 'Try again'),
              ),
            const SizedBox(height: 10),
            // Always available: the browser downloads it to Downloads and you
            // tap it there. Slower, but it works when nothing else does.
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(widget.info.apkUrl ?? widget.info.releaseUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 17),
              label: const Text('Download in the browser instead'),
            ),
          ],
        ),
      ),
    );
  }
}
