import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';

class AppUpdateInfo {
  final String version;
  final String changelog;
  final String downloadUrl;
  final DateTime publishedAt;

  AppUpdateInfo({
    required this.version,
    required this.changelog,
    required this.downloadUrl,
    required this.publishedAt,
  });
}

enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  installing,
  error,
  upToDate,
}

class AutoUpdateService {
  static const _lastCheckKey = 'last_update_check';
  static const _repoUrl =
      'https://api.github.com/repos/lucasliet/tremedometro/releases/latest';

  static const bool isWanderboy = bool.fromEnvironment(
    'WANDERBOY',
    defaultValue: false,
  );

  final Dio _dio;
  StreamSubscription<OtaEvent>? _otaSubscription;

  UpdateStatus _status = UpdateStatus.idle;
  AppUpdateInfo? _updateInfo;
  double _progress = 0;
  String? _errorMessage;

  UpdateStatus get status => _status;
  AppUpdateInfo? get updateInfo => _updateInfo;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;

  AutoUpdateService({Dio? dio}) : _dio = dio ?? Dio();

  Future<AppUpdateInfo?> checkForUpdate({bool force = false}) async {
    if (kIsWeb) {
      debugPrint('[AutoUpdateService] Skipping check - web platform');
      return null;
    }

    if (isWanderboy) {
      debugPrint('[AutoUpdateService] Wanderboy mode - auto-update disabled');
      return null;
    }

    _status = UpdateStatus.checking;
    debugPrint('[AutoUpdateService] Starting update check (force: $force)');

    if (!force && !await _shouldCheckForUpdate()) {
      debugPrint('[AutoUpdateService] Skipping - too soon since last check');
      _status = UpdateStatus.idle;
      return null;
    }

    try {
      debugPrint('[AutoUpdateService] Fetching latest release from GitHub...');
      final response = await _dio.get(
        _repoUrl,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
        ),
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[AutoUpdateService] GitHub API returned status ${response.statusCode}',
        );
        _status = UpdateStatus.idle;
        return null;
      }

      final data = response.data;
      final rawTagName = data['tag_name'] as String;
      debugPrint(
        '[AutoUpdateService] GitHub latest release tag: "$rawTagName"',
      );

      final tagWithoutV = rawTagName.replaceAll('v', '');
      final versionParts = tagWithoutV.split('+');
      final latestVersionStr = versionParts[0];
      debugPrint(
        '[AutoUpdateService] Latest version (parsed): "$latestVersionStr"',
      );

      final changelog = data['body'] as String? ?? '';
      final assets = data['assets'] as List;

      String? architecture;
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final abis = androidInfo.supportedAbis;
      debugPrint('[AutoUpdateService] Supported ABIs: $abis');

      if (abis.contains('arm64-v8a')) {
        architecture = 'arm64-v8a';
      } else if (abis.contains('armeabi-v7a')) {
        architecture = 'armeabi-v7a';
      }
      debugPrint('[AutoUpdateService] Selected architecture: $architecture');

      final apkAsset =
          assets.firstWhereOrNull((asset) {
            final name = (asset['name'] as String).toLowerCase();
            if (!name.endsWith('.apk')) return false;

            if (architecture != null) {
              return name.contains(architecture);
            }
            return true;
          }) ??
          assets.firstWhereOrNull(
            (asset) => (asset['name'] as String).endsWith('.apk'),
          );

      if (apkAsset == null) {
        debugPrint(
          '[AutoUpdateService] No matching APK asset found in release',
        );
        _status = UpdateStatus.idle;
        return null;
      }

      debugPrint(
        '[AutoUpdateService] Selected APK: ${apkAsset['name']} for arch: $architecture',
      );

      final downloadUrl = apkAsset['browser_download_url'] as String;
      final publishedAtStr = data['published_at'] as String?;
      final publishedAt = publishedAtStr != null
          ? DateTime.tryParse(publishedAtStr) ?? DateTime.now()
          : DateTime.now();

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionStr = packageInfo.version;
      debugPrint(
        '[AutoUpdateService] Current app version: "$currentVersionStr"',
      );

      final currentVersion = Version.parse(
        currentVersionStr.replaceAll('v', ''),
      );
      final latestVersion = Version.parse(latestVersionStr);

      debugPrint(
        '[AutoUpdateService] Version comparison: Current: $currentVersion | Latest: $latestVersion',
      );

      await _updateLastCheckTime();

      if (latestVersion > currentVersion) {
        debugPrint('[AutoUpdateService] Update available!');
        _updateInfo = AppUpdateInfo(
          version: latestVersionStr,
          changelog: changelog,
          downloadUrl: downloadUrl,
          publishedAt: publishedAt,
        );
        _status = UpdateStatus.available;
        return _updateInfo;
      } else {
        debugPrint('[AutoUpdateService] No update needed - app is up to date');
        _status = UpdateStatus.upToDate;
      }
    } catch (e, stack) {
      debugPrint('[AutoUpdateService] Auto-check update failed: $e');
      debugPrint('$stack');
      _status = UpdateStatus.error;
      _errorMessage = e.toString();
    }

    return null;
  }

  void startUpdate({
    void Function(double)? onProgress,
    void Function(String)? onError,
  }) {
    debugPrint('[AutoUpdateService] startUpdate() called');
    final info = _updateInfo;
    if (info == null) {
      debugPrint('[AutoUpdateService] startUpdate() aborted - info is null');
      return;
    }

    debugPrint('[AutoUpdateService] URL: ${info.downloadUrl}');
    _otaSubscription?.cancel();
    _status = UpdateStatus.downloading;
    _progress = 0;

    try {
      debugPrint('[AutoUpdateService] Calling OtaUpdate().execute()...');
      _otaSubscription = OtaUpdate()
          .execute(
            info.downloadUrl,
            destinationFilename: 'tremedometro_update.apk',
          )
          .listen(
            (OtaEvent event) {
              debugPrint(
                '[AutoUpdateService] OTA Event: ${event.status} (${event.value})',
              );
              switch (event.status) {
                case OtaStatus.DOWNLOADING:
                  _progress = double.tryParse(event.value ?? '0') ?? 0;
                  onProgress?.call(_progress);
                  break;
                case OtaStatus.INSTALLING:
                  debugPrint('[AutoUpdateService] Starting installation');
                  _status = UpdateStatus.installing;
                  break;
                case OtaStatus.INSTALLATION_DONE:
                  debugPrint(
                    '[AutoUpdateService] Installation prompt triggered',
                  );
                  _status = UpdateStatus.idle;
                  _otaSubscription?.cancel();
                  _otaSubscription = null;
                  break;
                case OtaStatus.ALREADY_RUNNING_ERROR:
                case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                case OtaStatus.INTERNAL_ERROR:
                case OtaStatus.DOWNLOAD_ERROR:
                case OtaStatus.CHECKSUM_ERROR:
                case OtaStatus.INSTALLATION_ERROR:
                case OtaStatus.CANCELED:
                  debugPrint(
                    '[AutoUpdateService] OTA Update Failed: ${event.status.name}',
                  );
                  _status = UpdateStatus.error;
                  _errorMessage = 'Erro na atualização: ${event.status.name}';
                  onError?.call(_errorMessage!);
                  _otaSubscription?.cancel();
                  _otaSubscription = null;
                  break;
              }
            },
            onError: (e, stack) {
              debugPrint('[AutoUpdateService] OTA Update Stream Error: $e');
              _status = UpdateStatus.error;
              _errorMessage = e.toString();
              onError?.call(_errorMessage!);
              _otaSubscription?.cancel();
              _otaSubscription = null;
            },
          );
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = e.toString();
      onError?.call(_errorMessage!);
    }
  }

  Future<bool> _shouldCheckForUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckMillis = prefs.getInt(_lastCheckKey) ?? 0;
    final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMillis);
    final now = DateTime.now();

    return now.difference(lastCheck).inDays >= 1;
  }

  Future<void> _updateLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  void dispose() {
    _otaSubscription?.cancel();
  }
}
