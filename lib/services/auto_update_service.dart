import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
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
  final int? fileSizeBytes;

  ReleaseInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseUrl,
    required this.changelog,
    this.fileSizeBytes,
  });
}

class AutoUpdateService {
  static const String _repoOwner = 'lucasliet';
  static const String _repoName = 'tremedometro';
  static const String _updateInstalledKey = 'update_installed';
  static const MethodChannel _channel =
      MethodChannel('br.com.lucasliet.blueguava/update');

  final http.Client _httpClient;
  final Dio _dio;
  AppVersion? _currentVersion;
  String? _deviceAbi;

  AutoUpdateService({
    http.Client? httpClient,
    Dio? dio,
    AppVersion? currentVersion,
  })  : _httpClient = httpClient ?? http.Client(),
        _dio = dio ?? Dio(),
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

  Future<String> _getDeviceAbi() async {
    if (kIsWeb) return 'universal';
    if (_deviceAbi != null) return _deviceAbi!;

    try {
      final String abi = await _channel.invokeMethod('getDeviceAbi');
      _deviceAbi = abi;
      debugPrint('AutoUpdate: Device ABI: $abi');
      return abi;
    } catch (e) {
      debugPrint('AutoUpdate: Erro ao obter ABI, usando universal: $e');
      _deviceAbi = 'universal';
      return 'universal';
    }
  }

  String _selectApkForAbi(List<dynamic> assets, String abi) {
    final abiPatterns = {
      'arm64-v8a': ['arm64-v8a', 'arm64'],
      'armeabi-v7a': ['armeabi-v7a', 'armeabi'],
      'x86_64': ['x86_64', 'x86-64'],
      'x86': ['x86'],
    };

    final patterns = abiPatterns[abi] ?? [];

    for (var pattern in patterns) {
      for (var asset in assets) {
        final name = asset['name'] as String?;
        if (name != null &&
            name.toLowerCase().endsWith('.apk') &&
            name.toLowerCase().contains(pattern.toLowerCase())) {
          return asset['browser_download_url'] as String;
        }
      }
    }

    for (var asset in assets) {
      final name = asset['name'] as String?;
      if (name != null && name.toLowerCase().endsWith('.apk')) {
        debugPrint('AutoUpdate: APK específico não encontrado, usando: $name');
        return asset['browser_download_url'] as String;
      }
    }

    throw Exception('Nenhum APK encontrado na release');
  }

  Future<ReleaseInfo?> checkForUpdate() async {
    try {
      if (kIsWeb) {
        debugPrint('AutoUpdate: Pulando verificação na plataforma web');
        return null;
      }

      await _cleanupOldApk();

      final currentVersion = await _getCurrentVersion();
      final deviceAbi = await _getDeviceAbi();

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
        return null;
      }

      final assets = data['assets'] as List<dynamic>?;
      if (assets == null || assets.isEmpty) {
        debugPrint('AutoUpdate: Nenhum asset encontrado na release');
        return null;
      }

      String apkUrl;
      int? fileSize;

      try {
        apkUrl = _selectApkForAbi(assets, deviceAbi);

        final selectedAsset = assets.firstWhere(
          (asset) => asset['browser_download_url'] == apkUrl,
          orElse: () => null,
        );

        if (selectedAsset != null) {
          fileSize = selectedAsset['size'] as int?;
        }

        debugPrint('AutoUpdate: APK selecionado: $apkUrl');
      } catch (e) {
        debugPrint('AutoUpdate: Erro ao selecionar APK: $e');
        return null;
      }

      final releaseUrl = data['html_url'] as String? ??
          'https://github.com/$_repoOwner/$_repoName/releases/latest';

      final changelog = data['body'] as String? ?? 'Sem notas de atualização';

      return ReleaseInfo(
        version: remoteVersion,
        downloadUrl: apkUrl,
        releaseUrl: releaseUrl,
        changelog: changelog,
        fileSizeBytes: fileSize,
      );
    } catch (e) {
      debugPrint('AutoUpdate: Erro ao verificar atualização: $e');
      return null;
    }
  }

  Future<String> downloadAndInstallUpdate(
    ReleaseInfo releaseInfo, {
    void Function(double)? onProgress,
  }) async {
    try {
      if (kIsWeb) {
        throw Exception('Download não suportado na plataforma web');
      }

      final cacheDir = await getTemporaryDirectory();
      final apkDir = Directory('${cacheDir.path}/apk');
      if (!await apkDir.exists()) {
        await apkDir.create(recursive: true);
      }

      final apkPath = '${apkDir.path}/update.apk';
      final apkFile = File(apkPath);

      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      debugPrint('AutoUpdate: Baixando APK para: $apkPath');

      await _dio.download(
        releaseInfo.downloadUrl,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            final progress = received / total;
            onProgress(progress);
          }
        },
      );

      debugPrint('AutoUpdate: Download concluído, instalando...');

      await _channel.invokeMethod('installApk', {'apkPath': apkPath});

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_updateInstalledKey, apkPath);

      debugPrint('AutoUpdate: Instalação iniciada');

      return apkPath;
    } catch (e) {
      debugPrint('AutoUpdate: Erro ao baixar/instalar: $e');
      rethrow;
    }
  }

  Future<void> _cleanupOldApk() async {
    try {
      if (kIsWeb) return;

      final prefs = await SharedPreferences.getInstance();
      final oldApkPath = prefs.getString(_updateInstalledKey);

      if (oldApkPath != null) {
        final oldApkFile = File(oldApkPath);
        if (await oldApkFile.exists()) {
          await oldApkFile.delete();
          debugPrint('AutoUpdate: APK antigo removido: $oldApkPath');
        }
        await prefs.remove(_updateInstalledKey);
      }
    } catch (e) {
      debugPrint('AutoUpdate: Erro ao limpar APK antigo: $e');
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
