import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Ekonometrik Analiz API Servisi
///
/// Python mikroservisindeki /econometrics endpoint'i ile iletişim.
/// Birim kök, eşbütünleşme, Granger, VAR, ARDL, GARCH analizleri.
class EconometricsApiService {
  static final EconometricsApiService _instance =
      EconometricsApiService._internal();
  factory EconometricsApiService() => _instance;
  EconometricsApiService._internal();

  final String _baseUrl = AppConfig.apiBaseUrl;
  final Duration _timeout = const Duration(seconds: 600);

  /// Desteklenen ekonometrik yöntemler listesi
  static const List<EconMethod> methods = [
    EconMethod(
      id: 'unit_root',
      nameTr: 'Birim Kök Testleri',
      icon: 'science',
      description: 'ADF, PP, KPSS — Serinin durağanlık kontrolü',
      minSeries: 1,
      maxSeries: 5,
      color: '#FF6B6B',
    ),
    EconMethod(
      id: 'cointegration',
      nameTr: 'Eşbütünleşme Testi',
      icon: 'link',
      description: 'Engle-Granger, Johansen — Uzun dönem ilişki',
      minSeries: 2,
      maxSeries: 2,
      color: '#4ECDC4',
    ),
    EconMethod(
      id: 'granger',
      nameTr: 'Granger Nedensellik',
      icon: 'call_split',
      description: 'X → Y nedensellik ilişkisi',
      minSeries: 2,
      maxSeries: 5,
      color: '#45B7D1',
    ),
    EconMethod(
      id: 'var_model',
      nameTr: 'VAR Modeli',
      icon: 'hub',
      description: 'Vektör Otoregresyon + IRF + Varyans Ayrıştırma',
      minSeries: 2,
      maxSeries: 5,
      color: '#96CEB4',
    ),
    EconMethod(
      id: 'ardl',
      nameTr: 'ARDL Sınır Testi',
      icon: 'border_all',
      description: 'Pesaran sınır testi — karma I(0)/I(1)',
      minSeries: 2,
      maxSeries: 5,
      color: '#FFEAA7',
      needsDependent: true,
    ),
    EconMethod(
      id: 'garch',
      nameTr: 'ARCH/GARCH',
      icon: 'show_chart',
      description: 'Volatilite modelleme ve şok analizi',
      minSeries: 1,
      maxSeries: 1,
      color: '#DDA0DD',
    ),
    EconMethod(
      id: 'ols',
      nameTr: 'OLS Regresyon',
      icon: 'timeline',
      description: 'Regresyon analizi + diagnostik testler',
      minSeries: 2,
      maxSeries: 5,
      color: '#F7DC6F',
      needsDependent: true,
    ),
    EconMethod(
      id: 'descriptive',
      nameTr: 'Tanımlayıcı İstatistik',
      icon: 'table_chart',
      description: 'Tez tablosu formatında istatistikler',
      minSeries: 1,
      maxSeries: 10,
      color: '#85C1E9',
    ),
    EconMethod(
      id: 'full_analysis',
      nameTr: 'Tam Tez Analizi',
      icon: 'auto_awesome',
      description: 'Tanımlayıcı + Birim kök + Korelasyon + Granger + Eşbütünleşme',
      minSeries: 2,
      maxSeries: 5,
      color: '#4ECDC4',
    ),
  ];

  /// Ekonometrik analiz çalıştır
  /// PHP proxy üzerinden Python servisine gider.
  Future<Map<String, dynamic>> runAnalysis({
    required String method,
    required List<Map<String, dynamic>> seriesData,
    Map<String, dynamic> params = const {},
    int dependentIndex = 0,
  }) async {
    // ★ FIX: PHP json_decode('{}', true) = [] sorunu
    // params boşsa hiç gönderme, Python kendi default {} kullanır.
    // params doluysa gönder.
    final body = <String, dynamic>{
      'method': method,
      'series_data': seriesData,
      'dependent_index': dependentIndex,
    };

    if (params.isNotEmpty) {
      body['params'] = params;
    }

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {'action': 'econometrics'},
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw EconException('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        String errorMessage = data['error'] ?? data['message'] ?? 'Bilinmeyen hata';
        if (data.containsKey('detail') && data['detail'] != null && data['detail'].toString().isNotEmpty) {
           errorMessage += '\nDetay: ${data['detail']}';
        }
        throw EconException(errorMessage);
      }

      return data['data'] ?? data;
    } catch (e) {
      if (e is EconException) rethrow;
      throw EconException('Bağlantı hatası: $e');
    }
  }

  /// Python servisi sağlık kontrolü
  Future<Map<String, dynamic>> healthCheck() async {
    final uri = Uri.parse(AppConfig.pythonServiceUrl).replace(path: '/health');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'offline', 'error': e.toString()};
    }
  }
}

/// Ekonometrik yöntem tanımı
class EconMethod {
  final String id;
  final String nameTr;
  final String icon;
  final String description;
  final int minSeries;
  final int maxSeries;
  final String color;
  final bool needsDependent;

  const EconMethod({
    required this.id,
    required this.nameTr,
    required this.icon,
    required this.description,
    required this.minSeries,
    required this.maxSeries,
    required this.color,
    this.needsDependent = false,
  });
}

class EconException implements Exception {
  final String message;
  EconException(this.message);

  @override
  String toString() => 'EconException: $message';
}