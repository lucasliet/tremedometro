import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppVersion {
  final String version;
  final int buildNumber;

  AppVersion(this.version, this.buildNumber);

  List<int> _normalizeVersion(String version) {
    final parts = version.split('.');
    final normalized = <int>[];

    for (var i = 0; i < 3; i++) {
      if (i < parts.length) {
        normalized.add(int.tryParse(parts[i]) ?? 0);
      } else {
        normalized.add(0);
      }
    }

    return normalized;
  }

  bool isNewerThan(AppVersion other) {
    final thisParts = _normalizeVersion(version);
    final otherParts = _normalizeVersion(other.version);

    for (var i = 0; i < 3; i++) {
      if (thisParts[i] > otherParts[i]) return true;
      if (thisParts[i] < otherParts[i]) return false;
    }

    return buildNumber > other.buildNumber;
  }

  @override
  String toString() => '$version+$buildNumber';
}

class ReleaseInfo {
  final AppVersion version;
  final String downloadUrl;
  final String releaseUrl;
  final String changelog;

  ReleaseInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseUrl,
    required this.changelog,
  });
}

class AutoUpdateService {
  static const String _repoOwner = 'lucasliet';
  static const String _repoName = 'tremedometro';
  static const String _lastCheckKey = 'last_update_check';
  static const Duration _checkInterval = Duration(hours: 24);

  final http.Client _httpClient;
  AppVersion? _currentVersion;

  AutoUpdateService({
    http.Client? httpClient,
    AppVersion? currentVersion,
  })  : _httpClient = httpClient ?? http.Client(),
        _currentVersion = currentVersion;

  Future<AppVersion> _getCurrentVersion() async {
    if (_currentVersion != null) return _currentVersion!;

    final packageInfo = await PackageInfo.fromPlatform();
    _currentVersion = AppVersion(
      packageInfo.version,
      int.tryParse(packageInfo.buildNumber) ?? 1,
    );

    return _currentVersion!;
  }

  Future<ReleaseInfo?> checkForUpdate() async {
    try {
      final currentVersion = await _getCurrentVersion();
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getString(_lastCheckKey);

      if (lastCheck != null) {
        final lastCheckTime = DateTime.parse(lastCheck);
        if (DateTime.now().difference(lastCheckTime) < _checkInterval) {
          debugPrint('AutoUpdate: Última verificação muito recente, pulando');
          return null;
        }
      }

      debugPrint('AutoUpdate: Verificando última release no GitHub...');

      final url = Uri.parse(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
      );

      final response = await _httpClient.get(url).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) {
        debugPrint(
          'AutoUpdate: Falha ao buscar release (${response.statusCode})',
        );
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String?;

      if (tagName == null) {
        debugPrint('AutoUpdate: Tag não encontrada na release');
        return null;
      }

      final versionString = tagName.startsWith('v')
          ? tagName.substring(1)
          : tagName;

      final versionParts = versionString.split('+');
      final version = versionParts[0];
      final buildNumber = versionParts.length > 1
          ? int.tryParse(versionParts[1]) ?? 1
          : 1;

      final remoteVersion = AppVersion(version, buildNumber);

      debugPrint(
        'AutoUpdate: Versão atual: $currentVersion, Remota: $remoteVersion',
      );

      if (!remoteVersion.isNewerThan(currentVersion)) {
        debugPrint('AutoUpdate: Aplicativo está atualizado');
        await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
        return null;
      }

      final assets = data['assets'] as List<dynamic>?;
      String? apkUrl;

      if (assets != null) {
        for (var asset in assets) {
          final name = asset['name'] as String?;
          if (name != null && name.toLowerCase().endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
      }

      final releaseUrl = data['html_url'] as String? ??
          'https://github.com/$_repoOwner/$_repoName/releases/latest';

      final changelog = data['body'] as String? ?? 'Sem notas de atualização';

      await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());

      return ReleaseInfo(
        version: remoteVersion,
        downloadUrl: apkUrl ?? releaseUrl,
        releaseUrl: releaseUrl,
        changelog: changelog,
      );
    } catch (e) {
      debugPrint('AutoUpdate: Erro ao verificar atualização: $e');
      return null;
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
