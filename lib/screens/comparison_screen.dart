import 'package:flutter/material.dart';
import 'package:macro_dashboard/config/chart_config_builder.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../widgets/plotly_chart.dart';

/// Karşılaştırma Ekranı
class ComparisonScreen extends StatefulWidget {
  final int? initialIndicatorId;

  const ComparisonScreen({super.key, this.initialIndicatorId});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  final _api = ApiService();
  final _chartBuilder = ChartConfigBuilder();

  Indicator? _indicatorA;
  Indicator? _indicatorB;

  List<Indicator> _allIndicators = [];     // Ham liste
  List<Indicator> _validIndicators = [];   // Sadece verisi olanlar
  bool _loadingIndicators = true;

  String _period = '5y';
  bool _normalize = true;
  bool _isAnalyzing = false;
  String? _error;
  String? _warning;
  Map<String, dynamic>? _overlayConfig;
  Map<String, dynamic>? _scatterConfig;
  Map<String, dynamic>? _correlationResult;

  int _lagDays = 0;

  @override
  void initState() {
    super.initState();
    _loadIndicators();
  }

  Future<void> _loadIndicators() async {
    try {
      final indicators = await _api.getIndicators();
      // Sadece son değeri olan (verisi olan) göstergeleri filtrele
      final valid = indicators.where((i) => i.lastValue != null).toList();

      setState(() {
        _allIndicators = indicators;
        _validIndicators = valid;
        _loadingIndicators = false;

        if (widget.initialIndicatorId != null) {
          _indicatorA = valid.firstWhere(
            (i) => i.id == widget.initialIndicatorId,
            orElse: () => valid.first,
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

  /// Periyotları genişten dara dener, veri bulana kadar
  Future<List<TimeSeries>> _fetchWithFallback(List<int> ids) async {
    final periodsToTry = <String>[_period];
    const allPeriods = ['1m', '3m', '6m', '1y', '3y', '5y', '10y', 'max'];
    final selectedIdx = allPeriods.indexOf(_period);

    for (int i = selectedIdx + 1; i < allPeriods.length; i++) {
      if (!periodsToTry.contains(allPeriods[i])) {
        periodsToTry.add(allPeriods[i]);
      }
    }

    for (final period in periodsToTry) {
      try {
        final series = await _api.getComparisonData(ids, period: period);
        if (series.any((s) => s.data.isNotEmpty)) {
          if (period != _period) {
            _warning =
                '${_periodLabel(_period)} periyodunda yeterli veri bulunamadı, '
                '${_periodLabel(period)} periyodu kullanıldı.';
          }
          return series;
        }
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  String _periodLabel(String value) {
    const labels = {
      '1m': '1 Ay', '3m': '3 Ay', '6m': '6 Ay', '1y': '1 Yıl',
      '3y': '3 Yıl', '5y': '5 Yıl', '10y': '10 Yıl', 'max': 'Tümü',
    };
    return labels[value] ?? value;
  }

  Future<void> _runAnalysis() async {
    if (_indicatorA == null || _indicatorB == null) return;

    setState(() {
      _isAnalyzing = true;
      _error = null;
      _warning = null;
      _overlayConfig = null;
      _scatterConfig = null;
      _correlationResult = null;
    });

    try {
      final series = await _fetchWithFallback(
        [_indicatorA!.id, _indicatorB!.id],
      );

      if (series.isEmpty || series.every((s) => s.data.isEmpty)) {
        setState(() {
          _error = 'Her iki gösterge için de hiçbir periyotta veri bulunamadı.';
          _isAnalyzing = false;
        });
        return;
      }

      final nonEmptySeries = series.where((s) => s.data.isNotEmpty).toList();
      final seriesDataForChart =
          nonEmptySeries.map((s) => s.toAnalysisFormat()).toList();

      if (series.length == 2 && nonEmptySeries.length == 1) {
        final emptySeries = series.firstWhere((s) => s.data.isEmpty);
        _warning = (_warning != null ? '${_warning!}\n' : '') +
            '${emptySeries.indicator.nameTr} için veri bulunamadı, '
                'sadece ${nonEmptySeries.first.indicator.nameTr} gösteriliyor.';
      }

      final overlayConfig = _chartBuilder.build(
        chartType: 'line',
        seriesData: seriesDataForChart,
        title: '${_indicatorA!.nameTr} vs ${_indicatorB!.nameTr}',
        overlay: !_normalize && nonEmptySeries.length > 1,
        normalize: _normalize && nonEmptySeries.length > 1,
      );

      Map<String, dynamic>? scatterConfig;
      if (nonEmptySeries.length >= 2) {
        scatterConfig = _chartBuilder.build(
          chartType: 'scatter',
          seriesData: seriesDataForChart,
          title: 'Korelasyon Saçılım Grafiği',
        );
      }

      Map<String, dynamic>? correlationResult;
      if (nonEmptySeries.length >= 2) {
        try {
          final analysisResult = await _api.analyze(
            type: 'correlation',
            indicatorIds: [_indicatorA!.id, _indicatorB!.id],
            period: _period,
            params: {'lag': _lagDays},
          );
          correlationResult = analysisResult.result;
        } catch (_) {}
      }

      setState(() {
        _overlayConfig = overlayConfig;
        _scatterConfig = scatterConfig;
        _correlationResult = correlationResult;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Veri çekme hatası: $e';
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
                  // Verisi olmayan gösterge sayısını göster
                  if (_allIndicators.length != _validIndicators.length)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${_validIndicators.length} gösterge listeleniyor '
                        '(${_allIndicators.length - _validIndicators.length} tanesi henüz verisi olmadığı için gizlendi)',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ),

                  _buildSelector('Gösterge A', _indicatorA, (val) {
                    setState(() => _indicatorA = val);
                  }),
                  const SizedBox(height: 12),
                  _buildSelector('Gösterge B', _indicatorB, (val) {
                    setState(() => _indicatorB = val);
                  }),

                  const SizedBox(height: 16),

                  PeriodSelector(
                    selected: _period,
                    onChanged: (val) => setState(() => _period = val),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Normalize (0-100)',
                              style: TextStyle(fontSize: 13)),
                          value: _normalize,
                          onChanged: (val) =>
                              setState(() => _normalize = val),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Gecikme (gün)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (val) =>
                              _lagDays = int.tryParse(val) ?? 0,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

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
                    label: Text(
                        _isAnalyzing ? 'Analiz ediliyor...' : 'Analiz Et'),
                  ),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13)),
                    ),

                  if (_warning != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _warning!,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

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
                    Text('Saçılım Grafiği',
                        style: theme.textTheme.titleSmall),
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
    // Kategoriye göre grupla
    final grouped = <String, List<Indicator>>{};
    for (final ind in _validIndicators) {
      final cat = ind.categoryNameTr ?? 'Diğer';
      grouped.putIfAbsent(cat, () => []).add(ind);
    }

    return DropdownButtonFormField<int>(
      value: selected?.id,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      isExpanded: true,
      items: _validIndicators.map((ind) {
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
          final ind = _validIndicators.firstWhere((i) => i.id == id);
          onChanged(ind);
        }
      },
    );
  }
}