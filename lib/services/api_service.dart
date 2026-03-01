import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/models.dart';

/// API Servisi - PHP Backend ile iletişim katmanı
///
/// Grafik config'i artık yerel olarak üretilir (ChartConfigBuilder).
/// Python servisi sadece istatistiksel analiz için kullanılır (opsiyonel).
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String _baseUrl = AppConfig.apiBaseUrl;
  final Duration _timeout = const Duration(seconds: 30);

  // =========================================
  // KATEGORİLER
  // =========================================

  Future<List<Category>> getCategories() async {
    final data = await _get({'action': 'categories'});
    final list = data['data'] as List;
    return list.map((e) => Category.fromJson(e)).toList();
  }

  // =========================================
  // GÖSTERGELER
  // =========================================

  Future<List<Indicator>> getIndicators(
      {int? categoryId, String? categoryCode}) async {
    final params = <String, String>{'action': 'indicators'};
    if (categoryId != null) params['category'] = categoryId.toString();
    if (categoryCode != null) params['category_code'] = categoryCode;

    final data = await _get(params);
    final list = data['data'] as List;
    return list.map((e) => Indicator.fromJson(e)).toList();
  }

  Future<Indicator> getIndicatorDetail(int id) async {
    final data = await _get({'action': 'indicator', 'id': id.toString()});
    return Indicator.fromJson(data['data']);
  }

  Future<List<Indicator>> searchIndicators(String query) async {
    if (query.length < 2) return [];
    final data = await _get({'action': 'search', 'q': query});
    final list = data['data'] as List;
    return list.map((e) => Indicator.fromJson(e)).toList();
  }

  // =========================================
  // ZAMAN SERİSİ VERİSİ
  // =========================================

  Future<TimeSeries> getTimeSeriesData(int indicatorId,
      {String period = '1y'}) async {
    final data = await _get({
      'action': 'data',
      'id': indicatorId.toString(),
      'period': period,
    });
    return TimeSeries.fromJson(data);
  }

  Future<TimeSeries> getTimeSeriesDataByRange(
    int indicatorId,
    String startDate,
    String endDate,
  ) async {
    final data = await _get({
      'action': 'data',
      'id': indicatorId.toString(),
      'start': startDate,
      'end': endDate,
    });
    return TimeSeries.fromJson(data);
  }

  Future<List<TimeSeries>> getComparisonData(
    List<int> indicatorIds, {
    String period = '5y',
  }) async {
    final data = await _get({
      'action': 'compare',
      'ids': indicatorIds.join(','),
      'period': period,
    });

    final series = data['series'] as List;
    return series.map((s) {
      return TimeSeries(
        indicator: Indicator.fromJson(s['indicator']),
        data: (s['data'] as List).map((d) => DataPoint.fromJson(d)).toList(),
        periodStart: data['period']?['start'] ?? '',
        periodEnd: data['period']?['end'] ?? '',
      );
    }).toList();
  }

  // =========================================
  // DASHBOARD
  // =========================================

  Future<Map<String, DashboardCategory>> getLatestValues() async {
    final data = await _get({'action': 'latest'});

    if (data['data'] is List) {
      return {};
    }

    final grouped = data['data'] as Map<String, dynamic>;
    return grouped
        .map((key, value) => MapEntry(key, DashboardCategory.fromJson(value)));
  }

  Future<Map<String, dynamic>> getSystemStats() async {
    final data = await _get({'action': 'stats'});
    return data['data'];
  }

  // =========================================
  // ANALİZ (Python proxy — opsiyonel)
  // =========================================

  /// Analiz isteği gönderir (PHP → Python proxy)
  /// Python servisi çalışmıyorsa hata fırlatır.
  Future<AnalysisResult> analyze({
    required String type,
    required List<int> indicatorIds,
    String period = '5y',
    Map<String, dynamic> params = const {},
  }) async {
    final body = {
      'type': type,
      'indicator_ids': indicatorIds,
      'period': period,
      'params': params,
    };

    final data = await _post({'action': 'analyze'}, body);
    return AnalysisResult.fromJson(data['data'] ?? data);
  }

  // =========================================
  // HTTP YARDIMCI
  // =========================================

  Future<Map<String, dynamic>> _get(Map<String, String> params) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

    try {
      final response = await http.get(uri).timeout(_timeout);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Bağlantı hatası: $e');
    }
  }

  Future<Map<String, dynamic>> _post(
    Map<String, String> queryParams,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45)); // Analiz için daha uzun timeout

      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Bağlantı hatası: $e');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw ApiException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data.containsKey('error')) {
      throw ApiException(data['error'] ?? data['message'] ?? 'Bilinmeyen hata');
    }

    return data;
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}