import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../widgets/plotly_chart.dart';

/// Karşılaştırma Ekranı
///
/// Kullanıcı iki gösterge seçer, sistem:
/// 1. Her iki seriyi overlay grafik olarak gösterir
/// 2. Korelasyon analizi yapar
/// 3. Scatter plot ile ilişkiyi görselleştirir
class ComparisonScreen extends StatefulWidget {
  final int? initialIndicatorId;

  const ComparisonScreen({super.key, this.initialIndicatorId});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  final _api = ApiService();

  // Seçilen göstergeler
  Indicator? _indicatorA;
  Indicator? _indicatorB;

  // Tüm gösterge listesi (seçim için)
  List<Indicator> _allIndicators = [];
  bool _loadingIndicators = true;

  // Analiz sonuçları
  String _period = '5y';
  bool _normalize = true;
  bool _isAnalyzing = false;
  String? _error;
  Map<String, dynamic>? _overlayConfig;
  Map<String, dynamic>? _scatterConfig;
  Map<String, dynamic>? _correlationResult;

  // Gecikme (lag) parametresi
  int _lagDays = 0;

  @override
  void initState() {
    super.initState();
    _loadIndicators();
  }

  Future<void> _loadIndicators() async {
    try {
      final indicators = await _api.getIndicators();
      setState(() {
        _allIndicators = indicators;
        _loadingIndicators = false;

        // Eğer başlangıç göstergesi varsa seç
        if (widget.initialIndicatorId != null) {
          _indicatorA = indicators.firstWhere(
            (i) => i.id == widget.initialIndicatorId,
            orElse: () => indicators.first,
          );
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Göstergeler yüklenemedi: $e';
        _loadingIndicators = false;
      });
    }
  }

  Future<void> _runAnalysis() async {
    if (_indicatorA == null || _indicatorB == null) return;

    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      // 1. Karşılaştırma verisi çek
      final series = await _api.getComparisonData(
        [_indicatorA!.id, _indicatorB!.id],
        period: _period,
      );
      if (series.any((s) => s.data.isEmpty)) {
        setState(() {
          _error =
              'Seçilen göstergelerden birinde veya ikisinde de bu periyoda ait veri bulunmuyor. Lütfen farklı göstergeler seçin.';
          _isAnalyzing = false;
        });
        return;
      }
      final seriesDataForChart =
          series.map((s) => s.toAnalysisFormat()).toList();

      // 2. Overlay çizgi grafik config'i
      final overlayConfig = await _api.getChartConfig(
        chartType: 'line',
        seriesData: seriesDataForChart,
        title: '${_indicatorA!.nameTr} vs ${_indicatorB!.nameTr}',
        overlay: !_normalize,
        normalize: _normalize,
      );

      // 3. Scatter plot config'i
      final scatterConfig = await _api.getChartConfig(
        chartType: 'scatter',
        seriesData: seriesDataForChart,
        title: 'Korelasyon Saçılım Grafiği',
      );

      // 4. Korelasyon analizi
      final analysisResult = await _api.analyze(
        type: 'correlation',
        indicatorIds: [_indicatorA!.id, _indicatorB!.id],
        period: _period,
        params: {'lag': _lagDays},
      );

      setState(() {
        _overlayConfig = overlayConfig;
        _scatterConfig = scatterConfig;
        _correlationResult = analysisResult.result;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Analiz hatası: $e';
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Karşılaştır & Analiz Et'),
      ),
      body: _loadingIndicators
          ? const StateWidget(isLoading: true)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gösterge seçiciler
                  _buildSelector('Gösterge A', _indicatorA, (val) {
                    setState(() => _indicatorA = val);
                  }),
                  const SizedBox(height: 12),
                  _buildSelector('Gösterge B', _indicatorB, (val) {
                    setState(() => _indicatorB = val);
                  }),

                  const SizedBox(height: 16),

                  // Periyot seçici
                  PeriodSelector(
                    selected: _period,
                    onChanged: (val) => setState(() => _period = val),
                  ),

                  const SizedBox(height: 12),

                  // Seçenekler
                  Row(
                    children: [
                      // Normalize toggle
                      Expanded(
                        child: SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Normalize (0-100)',
                              style: TextStyle(fontSize: 13)),
                          value: _normalize,
                          onChanged: (val) => setState(() => _normalize = val),
                        ),
                      ),
                      // Lag input
                      SizedBox(
                        width: 100,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Gecikme (gün)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => _lagDays = int.tryParse(val) ?? 0,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Analiz butonu
                  FilledButton.icon(
                    onPressed: _indicatorA != null &&
                            _indicatorB != null &&
                            !_isAnalyzing
                        ? _runAnalysis
                        : null,
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.analytics),
                    label:
                        Text(_isAnalyzing ? 'Analiz ediliyor...' : 'Analiz Et'),
                  ),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 13)),
                    ),

                  // Sonuçlar
                  if (_overlayConfig != null) ...[
                    const SizedBox(height: 24),
                    Text('Zaman Serisi Karşılaştırma',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    PlotlyChart(
                      plotlyConfig: _overlayConfig!,
                      height: 350,
                      darkMode: isDark,
                    ),
                  ],

                  if (_correlationResult != null) ...[
                    const SizedBox(height: 16),
                    CorrelationResultCard(result: _correlationResult!),
                  ],

                  if (_scatterConfig != null) ...[
                    const SizedBox(height: 16),
                    Text('Saçılım Grafiği', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    PlotlyChart(
                      plotlyConfig: _scatterConfig!,
                      height: 350,
                      darkMode: isDark,
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSelector(
      String label, Indicator? selected, ValueChanged<Indicator> onChanged) {
    return DropdownButtonFormField<int>(
      value: selected?.id,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      isExpanded: true,
      items: _allIndicators.map((ind) {
        return DropdownMenuItem(
          value: ind.id,
          child: Text(
            '${ind.nameTr} (${ind.unit})',
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (id) {
        if (id != null) {
          final ind = _allIndicators.firstWhere((i) => i.id == id);
          onChanged(ind);
        }
      },
    );
  }
}
