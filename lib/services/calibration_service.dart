import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _kCalibrationEndpoint = 'https://keyvaluedb.deno.dev';
const _kReferenceKey = 'blueguava_v1_ref';
const _kLocalCacheKey = 'blueguava_v1_ref_cache';

class CalibrationService {
  // Padrão de referência caso API falhe (GuavaPrime 15 = BlueGuava 1.0)
  static const double kDefaultReference = 15.0;

  Future<double> fetchWandersonReference() async {
    double? cachedValue = await _loadFromCache();

    // Dispara atualização em background se possível, ou aguarda se não tiver cache
    if (cachedValue != null) {
      // Cache-first: retorna cache e atualiza silenciosamente em background
      _fetchAndCacheFromApi().then((newValue) {
        if (newValue != null && newValue != cachedValue) {
          // Poderíamos notificar via Stream no futuro, por enquanto apenas atualiza cache
          debugPrint('Referência atualizada em background: $newValue');
        }
      });
      return cachedValue;
    } else {
      // Sem cache: aguarda API
      final apiValue = await _fetchAndCacheFromApi();
      return apiValue ?? kDefaultReference;
    }
  }

  Future<double?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getDouble(_kLocalCacheKey);
      if (val != null && val > 0) return val;
    } catch (e) {
      // ignore
    }
    return null;
  }

  Future<double?> _fetchAndCacheFromApi() async {
    try {
      final uri = Uri.parse('$_kCalibrationEndpoint/get?key=$_kReferenceKey');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final value = double.tryParse(data[0]?['value']?.toString() ?? '');

        if (value != null && value > 0) {
          await _saveToCache(value);
          return value;
        }
      } else {
        debugPrint('API Error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception fetching reference: $e');
    }
    return null; // Retorna null se falhar para o caller decidir o fallback
  }

  Future<void> _saveToCache(double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kLocalCacheKey, value);
    } catch (e) {
      // ignore
    }
  }

  Future<bool> updateWandersonReference(double newAverage) async {
    // Atualiza localmente também
    await _saveToCache(newAverage);

    try {
      final uri = Uri.parse('$_kCalibrationEndpoint/set');
      final body = jsonEncode({
        'keys': [_kReferenceKey],
        'value': newAverage.toString(),
      });

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}
