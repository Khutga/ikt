import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:macro_dashboard/config/econometrics_chart_builder.dart';
import '../services/api_service.dart';
import '../services/econometrics_api_service.dart';
import '../services/international_api_service.dart';
import '../models/models.dart';
import '../models/international_models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/plotly_chart.dart';

/// Ekonometrik Analiz Ekranı v2
///
/// Yenilikler:
/// - Veri kaynağı seçimi: TCMB (yurtiçi) / Dünya Bankası (uluslararası)
/// - Dünya Bankası modunda: gösterge + ülke seçimi → her ülke = 1 seri
/// - Her yöntem için sonuç grafikleri (IRF, FEVD, Volatilite, Korelasyon vb.)
///
/// Tez: "Sürdürülebilir Kalkınma Sürecinde Yeşil Ekonomiye Geçişin Rolü"
class EconometricsScreen extends StatefulWidget {
  const EconometricsScreen({super.key});

  @override
  State<EconometricsScreen> createState() => _EconometricsScreenState();
}

class _EconometricsScreenState extends State<EconometricsScreen> {
  final _api = ApiService();
  final _econApi = EconometricsApiService();
  final _intlApi = InternationalApiService();
  final _chartBuilder = EconometricsChartBuilder();

  // ── Veri kaynağı ──
  String _dataSource = 'tcmb'; // 'tcmb' | 'worldbank'

  // ── TCMB state ──
  List<Indicator> _indicators = [];
  bool _loadingIndicators = true;
  String? _error;

  // ── Dünya Bankası state ──
  List<IntlIndicator> _intlIndicators = [];
  List<Country> _countries = [];
  bool _loadingIntl = false;
  IntlIndicator? _selectedIntlIndicator;
  final Set<String> _selectedCountryCodes = {'TUR'};
  int _startYear = 2000;
  int _endYear = DateTime.now().year;

  // ── Ortak seçim state ──
  EconMethod? _selectedMethod;
  final List<Indicator> _selectedIndicators = []; // TCMB modu
  int _dependentIndex = 0;
  String _period = '5y';
  final Map<String, dynamic> _params = {};

  // ── Analiz state ──
  bool _isAnalyzing = false;
  Map<String, dynamic>? _result;
  String? _analysisError;

  // ── Grafik state ──
  List<Map<String, dynamic>> _charts = [];

  @override
  void initState() {
    super.initState();
    _loadIndicators();
  }

  Future<void> _loadIndicators() async {
    try {
      final indicators = await _api.getIndicators();
      final valid = indicators.where((i) => i.lastValue != null).toList();
      if (!mounted) return;
      setState(() {
        _indicators = valid;
        _loadingIndicators = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingIndicators = false;
      });
    }
  }

  Future<void> _loadIntlData() async {
    if (_intlIndicators.isNotEmpty) return; // Zaten yüklü
    setState(() => _loadingIntl = true);
    try {
      final results = await Future.wait([
        _intlApi.getIntlIndicators(),
        _intlApi.getCountries(),
      ]);
      if (!mounted) return;
      setState(() {
        _intlIndicators = results[0] as List<IntlIndicator>;
        _countries = results[1] as List<Country>;
        if (_intlIndicators.isNotEmpty && _selectedIntlIndicator == null) {
          _selectedIntlIndicator = _intlIndicators.first;
        }
        _loadingIntl = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Uluslararası veriler yüklenemedi: $e';
        _loadingIntl = false;
      });
    }
  }

  // ── Analiz çalıştır ──

  Future<void> _runAnalysis() async {
    if (_selectedMethod == null) return;

    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
      _result = null;
      _charts = [];
    });

    try {
      List<Map<String, dynamic>> seriesData;

      if (_dataSource == 'worldbank') {
        seriesData = await _buildIntlSeriesData();
      } else {
        seriesData = await _buildTcmbSeriesData();
      }

      if (seriesData.isEmpty) {
        throw Exception('Veri bulunamadı. Lütfen seçimlerinizi kontrol edin.');
      }

      // Minimum seri kontrolü
      if (seriesData.length < _selectedMethod!.minSeries) {
        throw Exception(
          '${_selectedMethod!.nameTr} için en az ${_selectedMethod!.minSeries} seri gerekli, '
          '${seriesData.length} seri bulundu.',
        );
      }

      final result = await _econApi.runAnalysis(
        method: _selectedMethod!.id,
        seriesData: seriesData,
        params: _params,
        dependentIndex: _dependentIndex,
      );

      if (!mounted) return;

      final resultData = result['result'] as Map<String, dynamic>? ?? result;

      // Grafikleri oluştur
      final charts = _buildChartsForMethod(_selectedMethod!.id, resultData);

      setState(() {
        _result = resultData;
        _charts = charts;
        _isAnalyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analysisError = e.toString();
        _isAnalyzing = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _buildTcmbSeriesData() async {
    final seriesData = <Map<String, dynamic>>[];
    for (final ind in _selectedIndicators) {
      final ts = await _api.getTimeSeriesData(ind.id, period: _period);
      seriesData.add(ts.toAnalysisFormat());
    }
    return seriesData;
  }

  Future<List<Map<String, dynamic>>> _buildIntlSeriesData() async {
    if (_selectedIntlIndicator == null || _selectedCountryCodes.length < 1) {
      return [];
    }

    final comparison = await _intlApi.getIntlComparison(
      indicatorId: _selectedIntlIndicator!.id,
      countryCodes: _selectedCountryCodes.toList(),
      startYear: _startYear,
      endYear: _endYear,
    );

    final seriesData = <Map<String, dynamic>>[];

    for (final countrySeries in comparison.series) {
      if (countrySeries.data.isEmpty) continue;

      final flag = countrySeries.flagEmoji ?? '';
      final name =
          '$flag ${countrySeries.nameTr} - ${_selectedIntlIndicator!.nameTr}';

      seriesData.add({
        'indicator_id': _selectedIntlIndicator!.id,
        'name': name.trim(),
        'code':
            '${countrySeries.isoCode}_${_selectedIntlIndicator!.sourceCode}',
        'unit': _selectedIntlIndicator!.unit,
        'data': countrySeries.data
            .map((d) => {
                  'date': d.date,
                  'value': d.value,
                })
            .toList(),
      });
    }

    return seriesData;
  }

  // ── Grafik oluşturma ──

  List<Map<String, dynamic>> _buildChartsForMethod(
    String method,
    Map<String, dynamic> result,
  ) {
    final charts = <Map<String, dynamic>>[];

    switch (method) {
      case 'unit_root':
        final chart = _chartBuilder.buildUnitRootChart(result);
        if (chart != null)
          charts.add({'title': 'ADF Birim Kök Testi', 'config': chart});
        break;

      case 'granger':
        final chart = _chartBuilder.buildGrangerChart(result);
        if (chart != null)
          charts.add({'title': 'Granger Nedensellik', 'config': chart});
        break;

      case 'var_model':
        // IRF grafikleri
        if (result['irf'] is Map<String, dynamic>) {
          final irfCharts = _chartBuilder.buildIrfCharts(result['irf']);
          charts.addAll(irfCharts);
        }
        // FEVD grafikleri
        if (result['fevd'] is Map<String, dynamic>) {
          final fevdCharts = _chartBuilder.buildFevdCharts(result['fevd']);
          charts.addAll(fevdCharts);
        }
        break;

      case 'garch':
        final volChart = _chartBuilder.buildVolatilityChart(result);
        if (volChart != null)
          charts.add({'title': 'Koşullu Volatilite', 'config': volChart});
        break;

      case 'ols':
        final coefChart = _chartBuilder.buildCoefficientsChart(result);
        if (coefChart != null)
          charts.add({'title': 'Regresyon Katsayıları', 'config': coefChart});
        break;

      case 'correlation':
        final heatmap = _chartBuilder.buildCorrelationHeatmap(result);
        if (heatmap != null)
          charts.add({'title': 'Korelasyon Isı Haritası', 'config': heatmap});
        final rolling = _chartBuilder.buildRollingCorrelationChart(result);
        if (rolling != null)
          charts.add({'title': 'Rolling Korelasyon', 'config': rolling});
        break;

      case 'full_analysis':
        charts.addAll(_chartBuilder.buildFullAnalysisCharts(result));
        break;
    }

    return charts;
  }

  // ═══════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.science, size: 20, color: Color(0xFF4ECDC4)),
            SizedBox(width: 8),
            Text('Ekonometrik Analiz'),
          ],
        ),
      ),
      body: _loadingIndicators
          ? const StateWidget(isLoading: true)
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 0. Veri kaynağı seçici
                    _buildDataSourceSelector(),
                    const SizedBox(height: 16),

                    // 1. Yöntem seçimi
                    _buildMethodSelector(),
                    const SizedBox(height: 16),

                    // 2. Gösterge / Ülke seçimi
                    if (_selectedMethod != null) ...[
                      if (_dataSource == 'tcmb')
                        _buildTcmbIndicatorSelector()
                      else ...[
                        if (_loadingIntl)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF4ECDC4))),
                          )
                        else ...[
                          _buildIntlIndicatorSelector(),
                          const SizedBox(height: 12),
                          _buildIntlCountrySelector(),
                          const SizedBox(height: 12),
                          _buildYearRange(),
                        ],
                      ],
                      const SizedBox(height: 12),
                    ],

                    // 3. Periyot (sadece TCMB)
                    if (_selectedMethod != null &&
                        _dataSource == 'tcmb' &&
                        _selectedIndicators.isNotEmpty) ...[
                      _buildPeriodAndParams(),
                      const SizedBox(height: 12),
                    ],

                    // 4. Bağımlı değişken seçimi
                    if (_selectedMethod != null &&
                        _selectedMethod!.needsDependent &&
                        _canRunAnalysis &&
                        _getEffectiveSeriesCount() >= 2)
                      _buildDependentSelector(),

                    // 5. Analiz butonu
                    if (_selectedMethod != null) _buildAnalyzeButton(),

                    // Hata
                    if (_analysisError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Text(_analysisError!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12)),
                        ),
                      ),

                    // ═══ GRAFİKLER ═══
                    if (_charts.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      ..._charts.map((chart) {
                        final config = chart['config'] as Map<String, dynamic>;
                        final title = chart['title'] as String? ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (title.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.insert_chart,
                                          size: 16, color: Color(0xFF45B7D1)),
                                      const SizedBox(width: 6),
                                      Text(title,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              PlotlyChart(
                                plotlyConfig: config,
                                height: 320,
                                darkMode: isDark,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    // ═══ SONUÇLAR ═══
                    if (_result != null) ...[
                      const SizedBox(height: 24),
                      _buildResults(),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════
  //  VERİ KAYNAĞI SEÇİCİ
  // ═══════════════════════════════════════════

  Widget _buildDataSourceSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Row(
        children: [
          _sourceTab('tcmb', '🇹🇷 TCMB (Yurtiçi)', Icons.account_balance),
          const SizedBox(width: 4),
          _sourceTab('worldbank', '🌍 Dünya Bankası', Icons.public),
        ],
      ),
    );
  }

  Widget _sourceTab(String value, String label, IconData icon) {
    final isSelected = _dataSource == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _dataSource = value;
            _result = null;
            _charts = [];
            _analysisError = null;
          });
          if (value == 'worldbank') _loadIntlData();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF4ECDC4).withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.4))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color:
                      isSelected ? const Color(0xFF4ECDC4) : Colors.grey[500]),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color:
                        isSelected ? const Color(0xFF4ECDC4) : Colors.grey[400],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  YÖNTEM SEÇİCİ
  // ═══════════════════════════════════════════

  Widget _buildMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.analytics, size: 18, color: Color(0xFF4ECDC4)),
            const SizedBox(width: 8),
            Text('Analiz Yöntemi',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[300])),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: EconometricsApiService.methods.map((method) {
            final isSelected = _selectedMethod?.id == method.id;
            final color =
                Color(int.parse(method.color.replaceFirst('#', '0xFF')));

            return GestureDetector(
              onTap: () => setState(() {
                _selectedMethod = method;
                _selectedIndicators.clear();
                _result = null;
                _charts = [];
                _analysisError = null;
              }),
              child: Container(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.15)
                      : const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : const Color(0xFF2A2A4A),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_getMethodIcon(method.icon),
                            size: 18,
                            color: isSelected ? color : Colors.grey[500]),
                        const Spacer(),
                        if (isSelected)
                          Icon(Icons.check_circle, size: 16, color: color),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(method.nameTr,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? color : Colors.grey[300])),
                    const SizedBox(height: 2),
                    Text(method.description,
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  TCMB GÖSTERGE SEÇİCİ
  // ═══════════════════════════════════════════

  Widget _buildTcmbIndicatorSelector() {
    final method = _selectedMethod!;
    return Card(
      elevation: 0,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2A2A4A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Gösterge Seç (TCMB)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[300])),
                const Spacer(),
                Text('${_selectedIndicators.length}/${method.maxSeries}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
            Text(
                'En az ${method.minSeries}, en fazla ${method.maxSeries} gösterge',
                style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _indicators.map((ind) {
                final isSelected = _selectedIndicators.contains(ind);
                return FilterChip(
                  label: Text(_shortenName(ind.nameTr),
                      style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? Colors.black : Colors.grey[300])),
                  selected: isSelected,
                  selectedColor: const Color(0xFF4ECDC4),
                  backgroundColor: const Color(0xFF16213E),
                  checkmarkColor: Colors.black,
                  side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF4ECDC4)
                          : const Color(0xFF2A2A4A)),
                  onSelected: (val) {
                    setState(() {
                      if (val &&
                          _selectedIndicators.length < method.maxSeries) {
                        _selectedIndicators.add(ind);
                      } else {
                        _selectedIndicators.remove(ind);
                      }
                      _result = null;
                      _charts = [];
                    });
                  },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                );
              }).toList(),
            ),
            if (_selectedIndicators.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedIndicators.clear();
                  _result = null;
                  _charts = [];
                }),
                child: Text('Seçimi temizle',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        decoration: TextDecoration.underline)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  DÜNYA BANKASI GÖSTERGE SEÇİCİ
  // ═══════════════════════════════════════════

  Widget _buildIntlIndicatorSelector() {
    if (_intlIndicators.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  'Uluslararası gösterge bulunamadı. Backend\'de seed verilerinin yüklendiğinden emin olun.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<int>(
      value: _selectedIntlIndicator?.id,
      decoration: const InputDecoration(
        labelText: 'Gösterge (Dünya Bankası)',
        prefixIcon: Icon(Icons.public, size: 20),
        border: OutlineInputBorder(),
        isDense: true,
      ),
      isExpanded: true,
      items: _intlIndicators.map((ind) {
        return DropdownMenuItem(
          value: ind.id,
          child: Text('${ind.nameTr} (${ind.unit})',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (id) {
        if (id != null) {
          setState(() {
            _selectedIntlIndicator =
                _intlIndicators.firstWhere((i) => i.id == id);
            _result = null;
            _charts = [];
          });
        }
      },
    );
  }

  // ═══════════════════════════════════════════
  //  ÜLKE SEÇİCİ
  // ═══════════════════════════════════════════

  Widget _buildIntlCountrySelector() {
    final method = _selectedMethod!;

    return Card(
      elevation: 0,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2A2A4A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Ülke Seç',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[300])),
                const Spacer(),
                Text('${_selectedCountryCodes.length}/${method.maxSeries}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
            Text(
                'Her ülke = 1 seri. En az ${method.minSeries}, en fazla ${method.maxSeries}.',
                style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _countries.map((country) {
                final isSelected =
                    _selectedCountryCodes.contains(country.isoCode);
                return FilterChip(
                  label: Text('${country.flagEmoji ?? ''} ${country.nameTr}',
                      style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.black : Colors.grey[300])),
                  selected: isSelected,
                  selectedColor: const Color(0xFF4ECDC4),
                  backgroundColor: const Color(0xFF16213E),
                  checkmarkColor: Colors.black,
                  side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : const Color(0xFF2A2A4A)),
                  onSelected: (val) {
                    setState(() {
                      if (val &&
                          _selectedCountryCodes.length < method.maxSeries) {
                        _selectedCountryCodes.add(country.isoCode);
                      } else {
                        _selectedCountryCodes.remove(country.isoCode);
                      }
                      _result = null;
                      _charts = [];
                    });
                  },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                );
              }).toList(),
            ),
            // Hızlı seçim
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _quickGroup('TR vs AB', ['TUR', 'DEU', 'FRA', 'GBR']),
                _quickGroup('TR vs BRICS', ['TUR', 'BRA', 'RUS', 'IND', 'CHN']),
                _quickGroup('TR vs G7', ['TUR', 'USA', 'DEU', 'GBR', 'FRA']),
                _quickGroup('Temizle', ['TUR']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickGroup(String label, List<String> codes) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      onPressed: () {
        setState(() {
          _selectedCountryCodes.clear();
          _selectedCountryCodes.addAll(codes);
          _result = null;
          _charts = [];
        });
      },
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      backgroundColor: const Color(0xFF16213E),
      side: const BorderSide(color: Color(0xFF2A2A4A)),
    );
  }

  // ═══════════════════════════════════════════
  //  YIL ARALIĞI
  // ═══════════════════════════════════════════

  Widget _buildYearRange() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Başlangıç Yılı',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            controller: TextEditingController(text: _startYear.toString()),
            style: const TextStyle(fontSize: 13),
            onSubmitted: (val) {
              final v = int.tryParse(val);
              if (v != null && v >= 1960 && v < _endYear)
                setState(() => _startYear = v);
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('→', style: TextStyle(fontSize: 16)),
        ),
        Expanded(
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Bitiş Yılı',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            controller: TextEditingController(text: _endYear.toString()),
            style: const TextStyle(fontSize: 13),
            onSubmitted: (val) {
              final v = int.tryParse(val);
              if (v != null && v > _startYear && v <= DateTime.now().year)
                setState(() => _endYear = v);
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  PERİYOT & BAĞIMLI DEĞİŞKEN
  // ═══════════════════════════════════════════

  Widget _buildPeriodAndParams() {
    return Row(
      children: [
        Text('Periyot: ',
            style: TextStyle(fontSize: 13, color: Colors.grey[400])),
        const SizedBox(width: 8),
        ...['1y', '3y', '5y', '10y', 'max'].map((p) {
          final isSelected = p == _period;
          final label = {
            '1y': '1Y',
            '3y': '3Y',
            '5y': '5Y',
            '10y': '10Y',
            'max': 'Tümü'
          }[p]!;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.black : null)),
              selected: isSelected,
              selectedColor: const Color(0xFF4ECDC4),
              backgroundColor: const Color(0xFF1A1A2E),
              side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF4ECDC4)
                      : const Color(0xFF2A2A4A)),
              onSelected: (_) => setState(() => _period = p),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDependentSelector() {
    final seriesNames = _dataSource == 'worldbank'
        ? _selectedCountryCodes.map((code) {
            final country =
                _countries.where((c) => c.isoCode == code).firstOrNull;
            return '${country?.flagEmoji ?? ''} ${country?.nameTr ?? code}';
          }).toList()
        : _selectedIndicators.map((i) => i.nameTr).toList();

    if (seriesNames.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        value: _dependentIndex < seriesNames.length ? _dependentIndex : 0,
        decoration: const InputDecoration(
          labelText: 'Bağımlı Değişken (Y)',
          prefixIcon: Icon(Icons.arrow_forward, size: 18),
          border: OutlineInputBorder(),
          isDense: true,
        ),
        isExpanded: true,
        items: seriesNames.asMap().entries.map((e) {
          return DropdownMenuItem(
              value: e.key,
              child: Text(e.value, style: const TextStyle(fontSize: 13)));
        }).toList(),
        onChanged: (val) {
          if (val != null) setState(() => _dependentIndex = val);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  ANALİZ BUTONU
  // ═══════════════════════════════════════════

  bool get _canRunAnalysis {
    if (_selectedMethod == null) return false;
    final count = _getEffectiveSeriesCount();
    return count >= _selectedMethod!.minSeries && !_isAnalyzing;
  }

  int _getEffectiveSeriesCount() {
    if (_dataSource == 'worldbank') {
      return _selectedCountryCodes.length;
    }
    return _selectedIndicators.length;
  }

  Widget _buildAnalyzeButton() {
    final method = _selectedMethod!;
    final count = _getEffectiveSeriesCount();
    final sourceLabel = _dataSource == 'worldbank' ? 'ülke' : 'gösterge';

    return FilledButton.icon(
      onPressed: _canRunAnalysis ? _runAnalysis : null,
      icon: _isAnalyzing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.play_arrow),
      label: Text(_isAnalyzing
          ? 'Analiz ediliyor...'
          : '${method.nameTr} Çalıştır ($count $sourceLabel)'),
    );
  }

  // ═══════════════════════════════════════════
  //  SONUÇLAR
  // ═══════════════════════════════════════════

  Widget _buildResults() {
    if (_result == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.assessment, size: 20, color: Color(0xFF4ECDC4)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${_selectedMethod?.nameTr ?? "Analiz"} Sonuçları',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF4ECDC4))),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Veri kaynağı bilgisi
        Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                  _dataSource == 'worldbank'
                      ? Icons.public
                      : Icons.account_balance,
                  size: 14,
                  color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                _dataSource == 'worldbank'
                    ? 'Kaynak: Dünya Bankası | ${_selectedCountryCodes.join(", ")} | $_startYear-$_endYear'
                    : 'Kaynak: TCMB EVDS | Periyot: $_period',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ),

        // Yorum kartı
        if (_result!['interpretation_tr'] != null)
          _buildInterpretationCard(_result!['interpretation_tr']),

        // Yönteme göre detaylı sonuçlar
        if (_selectedMethod?.id == 'unit_root') _buildUnitRootResults(),
        if (_selectedMethod?.id == 'granger') _buildGrangerResults(),
        if (_selectedMethod?.id == 'cointegration')
          _buildCointegrationResults(),
        if (_selectedMethod?.id == 'descriptive') _buildDescriptiveResults(),
        if (_selectedMethod?.id == 'ols') _buildOlsResults(),
        if (_selectedMethod?.id == 'garch') _buildGarchResults(),
        if (_selectedMethod?.id == 'full_analysis') _buildFullAnalysisResults(),

        // Ham JSON toggle
        _buildRawJsonToggle(),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  SONUÇ RENDER FONKSİYONLARI
  //  (Mevcut koddan taşındı, değişiklik yok)
  // ═══════════════════════════════════════════

  Widget _buildInterpretationCard(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        color: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(0xFFFFA726).withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.lightbulb, size: 16, color: Color(0xFFFFA726)),
                SizedBox(width: 8),
                Text('Yorum',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFFFFA726))),
              ]),
              const SizedBox(height: 8),
              Text(text,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[300], height: 1.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitRootResults() {
    final seriesResults = _result!['series_results'] as List? ?? [_result!];
    return Column(
      children: seriesResults.map<Widget>((sr) {
        final name = sr['series_name'] ?? '';
        final io = sr['integration_order'];
        final interp = sr['interpretation_tr'] ?? '';
        return Card(
          elevation: 0,
          color: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF2A2A4A))),
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: io == 0
                                ? const Color(0xFF4ECDC4).withOpacity(0.2)
                                : const Color(0xFFFFA726).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(io != null ? 'I($io)' : 'I(?)',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: io == 0
                                    ? const Color(0xFF4ECDC4)
                                    : const Color(0xFFFFA726))),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    for (final level in ['levels', 'first_diff', 'second_diff'])
                      if (sr[level] != null &&
                          sr[level] is Map &&
                          sr[level]['adf'] != null)
                        _buildTestRow(
                            level == 'levels'
                                ? 'Düzey'
                                : level == 'first_diff'
                                    ? '1. Fark'
                                    : '2. Fark',
                            sr[level]),
                    const SizedBox(height: 8),
                    Text(interp,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                            height: 1.5)),
                  ])),
        );
      }).toList(),
    );
  }

  Widget _buildTestRow(String label, Map<String, dynamic> data) {
    final adf = data['adf'] as Map<String, dynamic>?;
    final kpss = data['kpss'] as Map<String, dynamic>?;
    if (adf == null) return const SizedBox();
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
              width: 60,
              child: Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
          Expanded(
              child: Text(
                  'ADF: ${adf['statistic']}${adf['stars'] ?? ""} (p=${adf['p_value']})',
                  style: TextStyle(
                      fontSize: 11,
                      color: adf['is_stationary'] == true
                          ? const Color(0xFF4ECDC4)
                          : Colors.grey[400]))),
          if (kpss != null && kpss['statistic'] != null)
            Text('KPSS: ${kpss['statistic']}',
                style: TextStyle(
                    fontSize: 11,
                    color: kpss['is_stationary'] == true
                        ? const Color(0xFF4ECDC4)
                        : Colors.grey[400])),
        ]));
  }

  Widget _buildGrangerResults() {
    final tests = _result!['tests'] as List? ?? [];
    final summary = _result!['summary_tr'] ?? '';
    return Card(
        elevation: 0,
        color: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2A2A4A))),
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ...tests.map<Widget>((test) {
                final isCausal = test['is_granger_cause'] == true;
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Icon(isCausal ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: isCausal
                              ? const Color(0xFF4ECDC4)
                              : Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(test['direction'] ?? '',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isCausal
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isCausal
                                      ? const Color(0xFF4ECDC4)
                                      : Colors.grey[500]))),
                      Text('p=${test['best_p_value']}',
                          style: TextStyle(
                              fontSize: 11,
                              color: isCausal
                                  ? const Color(0xFF4ECDC4)
                                  : Colors.grey[600])),
                    ]));
              }),
              if (summary.isNotEmpty) ...[
                const Divider(height: 20, color: Color(0xFF2A2A4A)),
                Text(summary,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[400], height: 1.5)),
              ],
            ])));
  }

  Widget _buildCointegrationResults() {
    final eg = _result!['engle_granger'] as Map<String, dynamic>?;
    if (eg == null) return const SizedBox();
    final isCoint = eg['is_cointegrated'] == true;
    return Card(
        elevation: 0,
        color: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2A2A4A))),
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                  child: Column(children: [
                Icon(isCoint ? Icons.link : Icons.link_off,
                    size: 36,
                    color: isCoint
                        ? const Color(0xFF4ECDC4)
                        : const Color(0xFFFF6B6B)),
                const SizedBox(height: 8),
                Text(isCoint ? 'Eşbütünleşme VAR' : 'Eşbütünleşme YOK',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isCoint
                            ? const Color(0xFF4ECDC4)
                            : const Color(0xFFFF6B6B))),
              ])),
              const SizedBox(height: 12),
              _kv('Test İstatistiği', '${eg['statistic']}${eg['stars'] ?? ""}'),
              _kv('p-değeri', '${eg['p_value']}'),
              if (eg['critical_values'] != null)
                _kv('Kritik Değerler',
                    '1%: ${eg['critical_values']['1%']}, 5%: ${eg['critical_values']['5%']}, 10%: ${eg['critical_values']['10%']}'),
            ])));
  }

  Widget _buildDescriptiveResults() {
    final vars = _result!['variables'] as List? ?? [];
    return Card(
      elevation: 0,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2A2A4A))),
      child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DataTable(
              columnSpacing: 16,
              dataRowMinHeight: 28,
              dataRowMaxHeight: 32,
              headingRowHeight: 32,
              columns: const [
                DataColumn(
                    label: Text('Değişken', style: TextStyle(fontSize: 11))),
                DataColumn(label: Text('N', style: TextStyle(fontSize: 11))),
                DataColumn(label: Text('Ort.', style: TextStyle(fontSize: 11))),
                DataColumn(
                    label: Text('Medyan', style: TextStyle(fontSize: 11))),
                DataColumn(label: Text('Std', style: TextStyle(fontSize: 11))),
                DataColumn(label: Text('Min', style: TextStyle(fontSize: 11))),
                DataColumn(label: Text('Max', style: TextStyle(fontSize: 11))),
                DataColumn(
                    label: Text('Çarpıklık', style: TextStyle(fontSize: 11))),
                DataColumn(
                    label: Text('Basıklık', style: TextStyle(fontSize: 11))),
                DataColumn(label: Text('JB', style: TextStyle(fontSize: 11))),
              ],
              rows: vars.map<DataRow>((v) {
                final jb = v['jarque_bera'] as Map<String, dynamic>? ?? {};
                return DataRow(cells: [
                  DataCell(Text(_shortenName(v['name'] ?? ''),
                      style: const TextStyle(fontSize: 10))),
                  DataCell(
                      Text('${v['n']}', style: const TextStyle(fontSize: 10))),
                  DataCell(Text('${v['mean']}',
                      style: const TextStyle(fontSize: 10))),
                  DataCell(Text('${v['median']}',
                      style: const TextStyle(fontSize: 10))),
                  DataCell(Text('${v['std']}',
                      style: const TextStyle(fontSize: 10))),
                  DataCell(Text('${v['min']}',
                      style: const TextStyle(fontSize: 10))),
                  DataCell(Text('${v['max']}',
                      style: const TextStyle(fontSize: 10))),
                  DataCell(Text('${v['skewness']}',
                      style: const TextStyle(fontSize: 10))),
                  DataCell(Text('${v['kurtosis']}',
                      style: const TextStyle(fontSize: 10))),
                  DataCell(Text('${jb['statistic'] ?? "-"}${jb['stars'] ?? ""}',
                      style: const TextStyle(fontSize: 10))),
                ]);
              }).toList(),
            ),
          )),
    );
  }

  Widget _buildOlsResults() {
    final r = _result!;
    final coefs = r['coefficients'] as Map<String, dynamic>? ?? {};
    return Card(
        elevation: 0,
        color: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2A2A4A))),
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _kv('R²', '${r['r_squared']}'),
              _kv('Düzeltilmiş R²', '${r['adj_r_squared']}'),
              _kv('F-istatistiği', '${r['f_statistic']} (p=${r['f_pvalue']})'),
              _kv('Durbin-Watson', '${r['durbin_watson']}'),
              _kv('AIC / BIC', '${r['aic']} / ${r['bic']}'),
              const Divider(height: 20, color: Color(0xFF2A2A4A)),
              const Text('Katsayılar',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              ...coefs.entries.map((e) {
                final c = e.value as Map<String, dynamic>;
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      SizedBox(
                          width: 100,
                          child: Text(e.key,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[400]))),
                      Expanded(
                          child: Text(
                              '${c['value']}${c['stars'] ?? ""} (t=${c['t_stat']}, p=${c['p_value']})',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: c['significant'] == true
                                      ? const Color(0xFF4ECDC4)
                                      : Colors.grey[500]))),
                    ]));
              }),
            ])));
  }

  Widget _buildGarchResults() {
    final model = _result!['garch_model'] as Map<String, dynamic>?;
    final archLm = _result!['arch_lm_test'] as Map<String, dynamic>?;
    return Card(
        elevation: 0,
        color: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2A2A4A))),
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (archLm != null) ...[
                _kv('ARCH LM Testi',
                    'p=${archLm['lm_p_value']} ${archLm['has_arch_effect'] == true ? "→ ARCH etkisi VAR" : "→ ARCH etkisi yok"}'),
                const Divider(height: 16, color: Color(0xFF2A2A4A)),
              ],
              if (model != null && model['error'] == null) ...[
                _kv('Model', '${model['specification']}'),
                _kv('AIC / BIC', '${model['aic']} / ${model['bic']}'),
                const SizedBox(height: 8),
                if (model['parameters'] != null)
                  ...((model['parameters'] as Map<String, dynamic>)
                      .entries
                      .map((e) {
                    final p = e.value as Map<String, dynamic>;
                    return _kv(e.key,
                        '${p['value']}${p['stars'] ?? ""} (p=${p['p_value']})');
                  })),
              ],
            ])));
  }

  Widget _buildFullAnalysisResults() {
    final sections = _result!['sections'] as Map<String, dynamic>? ?? {};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (sections['descriptive'] != null) ...[
        const Text('📊 Tanımlayıcı İstatistik',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        Builder(builder: (_) {
          final old = _result;
          _result = sections['descriptive'] as Map<String, dynamic>;
          final w = _buildDescriptiveResults();
          _result = old;
          return w;
        }),
        const SizedBox(height: 16),
      ],
      if (sections['unit_root'] != null) ...[
        const Text('🔬 Birim Kök Testleri',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        ...(sections['unit_root'] as List).map<Widget>((ur) {
          final interp = ur['interpretation_tr'] ?? '';
          final io = ur['integration_order'];
          return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2A2A4A))),
                child: Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text('I(${io ?? "?"})',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4ECDC4))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          '${ur['series_name']}: ${interp.split('.').first}.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[300]))),
                ]),
              ));
        }),
        const SizedBox(height: 16),
      ],
      if (sections['granger'] != null &&
          sections['granger']['summary_tr'] != null)
        _buildInterpretationCard(sections['granger']['summary_tr']),
      if (sections['cointegration'] != null &&
          sections['cointegration']['interpretation_tr'] != null)
        _buildInterpretationCard(
            sections['cointegration']['interpretation_tr']),
    ]);
  }

  // ── Ham JSON ──
  bool _showRawJson = false;
  Widget _buildRawJsonToggle() {
    return Column(children: [
      const SizedBox(height: 16),
      InkWell(
        onTap: () => setState(() => _showRawJson = !_showRawJson),
        child: Row(children: [
          Icon(_showRawJson ? Icons.expand_less : Icons.expand_more,
              size: 18, color: Colors.grey[600]),
          Text('Ham JSON',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ]),
      ),
      if (_showRawJson)
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: const Color(0xFF0F0F23),
              borderRadius: BorderRadius.circular(8)),
          child: SelectableText(
            const JsonEncoder.withIndent('  ').convert(_result),
            style: TextStyle(
                fontSize: 9, fontFamily: 'monospace', color: Colors.grey[500]),
          ),
        ),
    ]);
  }

  // ═══════════════════════════════════════════
  //  YARDIMCI
  // ═══════════════════════════════════════════

  Widget _kv(String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500))),
        ]));
  }

  String _shortenName(String name) {
    if (name.length <= 18) return name;
    name = name
        .replaceAll('(Döviz Alış)', '')
        .replaceAll('(Genel)', '')
        .replaceAll('Ağırlıklı Ortalama ', 'Ort. ')
        .replaceAll('Endeksi', 'End.');
    return name.trim().length > 20
        ? '${name.trim().substring(0, 18)}...'
        : name.trim();
  }

  IconData _getMethodIcon(String name) {
    return switch (name) {
      'science' => Icons.science,
      'link' => Icons.link,
      'call_split' => Icons.call_split,
      'hub' => Icons.hub,
      'border_all' => Icons.border_all,
      'show_chart' => Icons.show_chart,
      'timeline' => Icons.timeline,
      'table_chart' => Icons.table_chart,
      'auto_awesome' => Icons.auto_awesome,
      _ => Icons.analytics,
    };
  }
}
