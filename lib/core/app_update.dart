/// "New version available" for the Android app.
///
/// Android copies are installed from an APK file, so they never update by
/// themselves. Each new APK is published as a GitHub release (see
/// tool/release_android.ps1); the app compares that release with its own
/// version and offers the download. The web version updates by itself and
/// iPhones use the web version, so only Android checks.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.downloadUrl,
    required this.notes,
  });

  /// The newer version, e.g. "1.0.3".
  final String version;

  /// The APK file of that version.
  final Uri downloadUrl;

  /// What changed, as written in the release.
  final String notes;

  static final Uri _latestRelease = Uri.parse(
    'https://api.github.com/repos/MusaDladla/daily-juice-authors/releases/latest',
  );

  /// The newer release for this phone, or null when the app is up to date,
  /// offline, or not the Android app. Never throws.
  static Future<AppUpdate?> checkOnAndroid() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final current = (await PackageInfo.fromPlatform()).version;
      final response = await http
          .get(
            _latestRelease,
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final release = jsonDecode(response.body);
      if (release is! Map<String, dynamic>) return null;
      return fromRelease(release, current);
    } catch (_) {
      return null; // No connection or GitHub unavailable: try next time.
    }
  }

  /// The update described by a GitHub [release], if it is newer than
  /// [current] and has an APK attached.
  static AppUpdate? fromRelease(Map<String, dynamic> release, String current) {
    final tag = release['tag_name'];
    if (tag is! String) return null;
    final version = tag.replaceFirst(RegExp('^[vV]'), '');
    if (compareVersions(version, current) <= 0) return null;
    final assets = release['assets'];
    if (assets is! List) return null;
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = asset['name'], url = asset['browser_download_url'];
      if (name is String && url is String && name.endsWith('.apk')) {
        final body = release['body'];
        return AppUpdate(
          version: version,
          downloadUrl: Uri.parse(url),
          notes: body is String ? body.trim() : '',
        );
      }
    }
    return null;
  }

  /// Compares "1.0.10" with "1.0.9" part by part: >0 when [a] is newer.
  static int compareVersions(String a, String b) {
    List<int> parts(String v) => v
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList();
    final x = parts(a), y = parts(b);
    for (var i = 0; i < x.length || i < y.length; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d;
    }
    return 0;
  }
}
