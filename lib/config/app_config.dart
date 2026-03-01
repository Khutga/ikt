/// Uygulama yapılandırması
/// 
/// Ortam değişkenlerine göre API URL'leri ayarlanır.
/// Release build'de production URL kullanılır.
class AppConfig {
  // PHP Backend API
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://seyidzade.sbs/apis/ikt/api.php', // Android emulator → localhost
  );

  // Python Analiz Servisi (doğrudan çağrı gerekirse)
  static const String pythonServiceUrl = String.fromEnvironment(
    'PYTHON_URL',
    defaultValue: 'https://seyidzade.sbs/ikt',
  );

  // Uygulama bilgileri
  static const String appName = 'Makroekonomik Dashboard';
  static const String appVersion = '1.0.0';

  // Varsayılan periyotlar
  static const List<Map<String, String>> periods = [
    {'label': '1A', 'value': '1m'},
    {'label': '3A', 'value': '3m'},
    {'label': '6A', 'value': '6m'},
    {'label': '1Y', 'value': '1y'},
    {'label': '3Y', 'value': '3y'},
    {'label': '5Y', 'value': '5y'},
    {'label': '10Y', 'value': '10y'},
    {'label': 'Tümü', 'value': 'max'},
  ];

  // Grafik tipleri
  static const List<Map<String, String>> chartTypes = [
    {'label': 'Çizgi', 'value': 'line', 'icon': 'show_chart'},
    {'label': 'Alan', 'value': 'area', 'icon': 'area_chart'},
    {'label': 'Çubuk', 'value': 'bar', 'icon': 'bar_chart'},
    {'label': 'Saçılım', 'value': 'scatter', 'icon': 'scatter_plot'},
  ];

  // Cache süreleri (dakika)
  static const int dataCacheDuration = 30;
  static const int analysisCacheDuration = 60;
}
