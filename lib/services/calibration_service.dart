import 'dart:async';
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

  // Stream para notificar a UI sobre eventos (sucesso, erro, atualizações)
  final _messageController = StreamController<String>.broadcast();
  Stream<String> get messageStream => _messageController.stream;

  Future<double> fetchWandersonReference() async {
    double? cachedValue = await _loadFromCache();

    // Dispara atualização em background se possível, ou aguarda se não tiver cache
    if (cachedValue != null) {
      // Cache-first: retorna cache e atualiza silenciosamente em background
      _fetchAndCacheFromApi(currentCache: cachedValue).then((newValue) {
        // O método _fetchAndCacheFromApi já gerencia a notificação se mudar
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

  Future<double?> _fetchAndCacheFromApi({double? currentCache}) async {
    try {
      final uri = Uri.parse('$_kCalibrationEndpoint/get?key=$_kReferenceKey');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        String? valueStr;

        if (data is Map && data.containsKey('found')) {
          valueStr = data['found']?.toString();
        } else if (data is List && data.isNotEmpty) {
          // Added new parsing condition
          valueStr = data[0]?['value']?.toString();
        } else if (data is Map && data.containsKey('value')) {
          valueStr = data['value']?.toString();
        }

        final value = double.tryParse(valueStr ?? '');

        if (value != null && value > 0) {
          await _saveToCache(value);

          // Se o valor mudou em relação ao que tínhamos (ou se não tínhamos nada e agora temos)
          // Notifica o usuário. Evita spam se for igual.
          if (currentCache != null && (value - currentCache).abs() > 0.1) {
            _messageController.add(
              'Calibração atualizada: ${value.toStringAsFixed(1)}',
            );
          }

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

      if (response.statusCode == 200 || response.statusCode == 201) {
        _messageController.add(
          'Média atualizada com sucesso! (${newAverage.toStringAsFixed(1)})',
        );
        return true;
      } else {
        _messageController.add('Falha na API: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _messageController.add('Erro de conexão: $e');
      return false;
    }
  }

  void dispose() {
    _messageController.close();
  }
}
