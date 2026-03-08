import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/international_models.dart';

/// Uluslararası Veri API Servisi
///
/// Ülke kıyaslama, Dünya Bankası verileri ve
/// sürdürülebilirlik göstergeleri için API katmanı.
class InternationalApiService {
  static final InternationalApiService _instance =
      InternationalApiService._internal();
  factory InternationalApiService() => _instance;
  InternationalApiService._internal();

  final String _baseUrl = AppConfig.apiBaseUrl;
  final Duration _timeout = const Duration(seconds: 30);

  // =========================================
  // ÜLKELER
  // =========================================

  /// Aktif ülke listesini döner
  Future<List<Country>> getCountries() async {
    final data = await _get({'action': 'countries'});
    final list = data['data'] as List;
    return list.map((e) => Country.fromJson(e)).toList();
  }

  // =========================================
  // ULUSLARARASI GÖSTERGELER
  // =========================================

  /// Uluslararası gösterge listesi
  Future<List<IntlIndicator>> getIntlIndicators({String? categoryCode}) async {
    final params = <String, String>{'action': 'intl_indicators'};
    if (categoryCode != null) params['category'] = categoryCode;

    final data = await _get(params);
    final list = data['data'] as List;
    return list.map((e) => IntlIndicator.fromJson(e)).toList();
  }

  // =========================================
  // ÜLKE KIYASLAMA
  // =========================================

  /// Ülkeler arası kıyaslama verisi çeker
  Future<IntlComparisonResult> getIntlComparison({
    required int indicatorId,
    required List<String> countryCodes,
    int startYear = 2000,
    int? endYear,
  }) async {
    final data = await _get({
      'action': 'intl_compare',
      'indicator': indicatorId.toString(),
      'countries': countryCodes.join(','),
      'start': startYear.toString(),
      'end': (endYear ?? DateTime.now().year).toString(),
    });

    return IntlComparisonResult.fromJson(data);
  }

  /// Tüm göstergelerin son değerleri (ülke bazlı)
  Future<List<IntlLatestEntry>> getIntlLatest({
    List<String>? countryCodes,
  }) async {
    final params = <String, String>{'action': 'intl_latest'};
    if (countryCodes != null && countryCodes.isNotEmpty) {
      params['countries'] = countryCodes.join(',');
    }

    final data = await _get(params);
    final list = data['data'] as List;
    return list.map((e) => IntlLatestEntry.fromJson(e)).toList();
  }

  // =========================================
  // SÜRDÜRÜLEBİLİRLİK
  // =========================================

  /// Sürdürülebilirlik dashboard verisi
  Future<Map<String, dynamic>> getSustainabilityDashboard({
    List<String>? countryCodes,
  }) async {
    final params = <String, String>{'action': 'sustainability'};
    if (countryCodes != null && countryCodes.isNotEmpty) {
      params['countries'] = countryCodes.join(',');
    }

    final data = await _get(params);
    return data['data'] as Map<String, dynamic>;
  }

  // =========================================
  // VERİ GÜNCELLEME (Admin)
  // =========================================

  /// Tek bir uluslararası göstergeyi güncelle
  Future<Map<String, dynamic>> triggerIntlFetch(int indicatorId) async {
    return await _get({
      'action': 'intl_fetch',
      'indicator': indicatorId.toString(),
    });
  }

  /// Tüm uluslararası verileri güncelle
  Future<Map<String, dynamic>> triggerIntlFetchAll() async {
    return await _get({'action': 'intl_fetch_all'});
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
      throw IntlApiException('Bağlantı hatası: $e');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw IntlApiException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data.containsKey('error')) {
      throw IntlApiException(data['error'] ?? 'Bilinmeyen hata');
    }

    return data;
  }
}

class IntlApiException implements Exception {
  final String message;
  IntlApiException(this.message);

  @override
  String toString() => 'IntlApiException: $message';
}