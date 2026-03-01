import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../widgets/plotly_chart.dart';


/// Grafik Detay Ekranı
///
/// Tek bir göstergenin zaman serisini interaktif Plotly grafiğinde gösterir.
/// Periyot ve grafik tipi değiştirilebilir.
/// Trend analizi ve istatistik bilgileri de gösterilir.
class ChartScreen extends StatefulWidget {
  final int indicatorId;
  final String indicatorName;

  const ChartScreen({
    super.key,
    required this.indicatorId,
    required this.indicatorName,
  });

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  final _api = ApiService();

  String _period = '1y';
  String _chartType = 'line';
  bool _isLoading = true;
  String? _error;

  TimeSeries? _timeSeries;
  Map<String, dynamic>? _plotlyConfig;
  Map<String, dynamic>? _trendResult;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Zaman serisi verisini çek
      final ts = await _api.getTimeSeriesData(widget.indicatorId, period: _period);
      _timeSeries = ts;

      // 2. Plotly grafik config'i al
      final config = await _api.getChartConfig(
        chartType: _chartType,
        seriesData: [ts.toAnalysisFormat()],
        title: ts.indicator.nameTr,
      );

      // 3. Trend analizi (arka planda)
      _loadTrendAnalysis();

      setState(() {
        _plotlyConfig = config;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTrendAnalysis() async {
    try {
      final result = await _api.analyze(
        type: 'trend',
        indicatorIds: [widget.indicatorId],
        period: _period,
      );
      if (mounted) {
        setState(() => _trendResult = result.result);
      }
    } catch (_) {
      // Trend analizi opsiyonel, hata varsa sessizce geç
    }
  }

  void _onPeriodChanged(String period) {
    _period = period;
    _loadData();
  }

  void _onChartTypeChanged(String type) {
    _chartType = type;
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.indicatorName,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            onPressed: _showIndicatorInfo,
          ),
        ],
      ),
      body: _isLoading || _error != null
          ? StateWidget(isLoading: _isLoading, error: _error, onRetry: _loadData)
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Son değer başlık
                  if (_timeSeries != null) _buildValueHeader(theme),

                  // Periyot seçici
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: PeriodSelector(
                      selected: _period,
                      onChanged: _onPeriodChanged,
                    ),
                  ),

                  // Grafik tipi seçici
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ChartTypeSelector(
                      selected: _chartType,
                      onChanged: _onChartTypeChanged,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Plotly Grafik
                  if (_plotlyConfig != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: PlotlyChart(
                        plotlyConfig: _plotlyConfig!,
                        height: 350,
                        darkMode: isDark,
                      ),
                    ),

                  // Trend analizi sonuçları
                  if (_trendResult != null) _buildTrendSection(theme),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildValueHeader(ThemeData theme) {
    final ts = _timeSeries!;
    final lastValue = ts.data.isNotEmpty ? ts.data.last.value : null;
    final prevValue = ts.data.length > 1 ? ts.data[ts.data.length - 2].value : null;

    double? change;
    if (lastValue != null && prevValue != null && prevValue != 0) {
      change = ((lastValue - prevValue) / prevValue) * 100;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            lastValue?.toStringAsFixed(ts.indicator.decimalPlaces) ?? '-',
            style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          Text(
            ts.indicator.unit,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(width: 12),
          if (change != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: change >= 0
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: change >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendSection(ThemeData theme) {
    final trend = _trendResult!['trend'] ?? {};
    final recent = _trendResult!['recent_changes'] ?? {};
    final direction = trend['direction_tr'] ?? '';
    final rSquared = trend['r_squared'];
    final volatility = _trendResult!['volatility_pct'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.trending_up, size: 18),
                  SizedBox(width: 8),
                  Text('Trend Analizi', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              _infoRow('Trend yönü', direction),
              if (rSquared != null) _infoRow('R²', rSquared.toStringAsFixed(3)),
              if (volatility != null) _infoRow('Volatilite', '%${volatility.toStringAsFixed(1)}'),
              _infoRow('Dönem yükseği', _trendResult!['period_high']?.toString() ?? '-'),
              _infoRow('Dönem düşüğü', _trendResult!['period_low']?.toString() ?? '-'),

              // Son 3 ay değişim
              if (recent['last_3_months'] != null) ...[
                const Divider(height: 20),
                _infoRow(
                  'Son 3 ay değişim',
                  '%${recent['last_3_months']['percent_change']}',
                ),
              ],
              if (recent['last_12_months'] != null)
                _infoRow(
                  'Son 12 ay değişim',
                  '%${recent['last_12_months']['percent_change']}',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showIndicatorInfo() {
    if (_timeSeries == null) return;
    final ind = _timeSeries!.indicator;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ind.nameTr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(ind.nameEn, style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 16),
            _infoRow('EVDS Kodu', ind.evdsCode),
            _infoRow('Birim', ind.unit),
            _infoRow('Frekans', ind.frequency),
            _infoRow('Kaynak', ind.source),
            _infoRow('Veri sayısı', '${_timeSeries!.data.length}'),
            _infoRow('Dönem', '${_timeSeries!.periodStart} → ${_timeSeries!.periodEnd}'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}