import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:macro_dashboard/config/chart_config_builder.dart';

import '../services/api_service.dart';
import '../services/explainer_service.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../widgets/plotly_chart.dart';

/// Grafik Detay Ekranı
///
/// Hafta 2:
///   🎓 AppBar'da "Bu ne?" toggle → eğitim kartı (education_tr JSON)
///   💡 Grafik altında "Bana Açıkla" toggle → otomatik yorum
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
  final _chartBuilder = ChartConfigBuilder();
  final _explainer = ExplainerService();

  String _period = '1y';
  String _chartType = 'line';
  bool _isLoading = true;
  String? _error;

  TimeSeries? _timeSeries;
  Map<String, dynamic>? _plotlyConfig;
  Map<String, dynamic>? _trendResult;

  // ★ Hafta 2 state
  bool _showEducation = false;
  bool _showExplain = false;
  Map<String, dynamic>? _educationData;
  String? _explainText;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      final ts = await _api.getTimeSeriesData(
        widget.indicatorId, period: _period,
      );
      _timeSeries = ts;

      if (ts.data.isEmpty) {
        setState(() { _error = 'Bu periyotta veri bulunamadı.'; _isLoading = false; });
        return;
      }

      final config = _chartBuilder.build(
        chartType: _chartType,
        seriesData: [ts.toAnalysisFormat()],
        title: ts.indicator.nameTr,
      );

      // Eğitim verisi parse
      _educationData = _parseEdu(ts.indicator.educationTr);

      // Otomatik yorum üret
      _explainText = _explainer.explain(ts);

      _loadTrendAnalysis();

      setState(() { _plotlyConfig = config; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Map<String, dynamic>? _parseEdu(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; }
    catch (_) { return null; }
  }

  Future<void> _loadTrendAnalysis() async {
    try {
      final r = await _api.analyze(
        type: 'trend',
        indicatorIds: [widget.indicatorId],
        period: _period,
      );
      if (mounted) setState(() => _trendResult = r.result);
    } catch (_) {}
  }

  void _onPeriodChanged(String p) { _period = p; _loadData(); }

  void _onChartTypeChanged(String t) {
    if (_timeSeries != null && _timeSeries!.data.isNotEmpty) {
      setState(() {
        _chartType = t;
        _plotlyConfig = _chartBuilder.build(
          chartType: t,
          seriesData: [_timeSeries!.toAnalysisFormat()],
          title: _timeSeries!.indicator.nameTr,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.indicatorName, style: const TextStyle(fontSize: 16)),
        actions: [
          // 🎓 Eğitim toggle
          if (_educationData != null)
            IconButton(
              icon: Icon(
                _showEducation ? Icons.school : Icons.school_outlined,
                size: 22,
                color: _showEducation ? const Color(0xFF4ECDC4) : null,
              ),
              tooltip: 'Bu ne?',
              onPressed: () => setState(() => _showEducation = !_showEducation),
            ),
          // ℹ️ Detay
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
                  // ── 🎓 Eğitim kartı ──
                  if (_showEducation && _educationData != null)
                    _buildEducationCard(),

                  // ── Son değer ──
                  if (_timeSeries != null) _buildValueHeader(theme),

                  // ── Periyot ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: PeriodSelector(selected: _period, onChanged: _onPeriodChanged),
                  ),

                  // ── Grafik tipi ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ChartTypeSelector(selected: _chartType, onChanged: _onChartTypeChanged),
                  ),

                  const SizedBox(height: 8),

                  // ── Plotly grafik ──
                  if (_plotlyConfig != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: PlotlyChart(plotlyConfig: _plotlyConfig!, height: 350, darkMode: isDark),
                    ),

                  // ── 💡 Bana Açıkla toggle ──
                  _buildExplainToggle(),

                  // ── Otomatik yorum ──
                  if (_showExplain && _explainText != null)
                    _buildExplainCard(),

                  // ── Trend ──
                  if (_trendResult != null) _buildTrendSection(theme),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════
  //  🎓 EĞİTİM KARTI
  // ═══════════════════════════════════════════

  Widget _buildEducationCard() {
    final d = _educationData!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        elevation: 0,
        color: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(0xFF4ECDC4).withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık + kapat
              Row(children: [
                const Icon(Icons.school, size: 20, color: Color(0xFF4ECDC4)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Bu Gösterge Nedir?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4ECDC4))),
                ),
                InkWell(
                  onTap: () => setState(() => _showEducation = false),
                  child: Icon(Icons.close, size: 18, color: Colors.grey[500]),
                ),
              ]),
              const SizedBox(height: 14),

              if (d['nedir'] != null)
                _eduBlock('📖 Nedir?', d['nedir']),
              if (d['neden_onemli'] != null) ...[
                const SizedBox(height: 12),
                _eduBlock('💡 Neden Önemli?', d['neden_onemli']),
              ],
              if (d['nasil_okunur'] != null) ...[
                const SizedBox(height: 12),
                _eduBlock('🔍 Nasıl Okunur?', d['nasil_okunur']),
              ],

              // İlişkili göstergeler chip'leri
              if (d['iliskili'] != null) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: [
                    Text('İlişkili: ', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ...(d['iliskili'] as List).map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(t.toString(),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF4ECDC4))),
                    )),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _eduBlock(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        Text(body, style: TextStyle(fontSize: 13, color: Colors.grey[300], height: 1.5)),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  💡 BANA AÇIKLA
  // ═══════════════════════════════════════════

  Widget _buildExplainToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _showExplain = !_showExplain),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _showExplain
                ? const Color(0xFF4ECDC4).withOpacity(0.1)
                : const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _showExplain
                  ? const Color(0xFF4ECDC4).withOpacity(0.4)
                  : const Color(0xFF2A2A4A),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showExplain ? Icons.lightbulb : Icons.lightbulb_outline,
                size: 18,
                color: _showExplain ? const Color(0xFF4ECDC4) : Colors.grey[400],
              ),
              const SizedBox(width: 8),
              Text('Bana Açıkla',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500,
                  color: _showExplain ? const Color(0xFF4ECDC4) : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplainCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        elevation: 0,
        color: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(0xFFFFA726).withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.lightbulb, size: 18, color: Color(0xFFFFA726)),
                SizedBox(width: 8),
                Text('Otomatik Yorum',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFFFA726))),
              ]),
              const SizedBox(height: 12),
              Text(_explainText!,
                style: TextStyle(fontSize: 13, color: Colors.grey[300], height: 1.6)),
              const SizedBox(height: 10),
              Text('Bu yorum veri analizi ile otomatik üretilmiştir, yatırım tavsiyesi değildir.',
                style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  DEĞİŞMEYEN KISIMLAR (Hafta 1'den)
  // ═══════════════════════════════════════════

  Widget _buildValueHeader(ThemeData theme) {
    final ts = _timeSeries!;
    final last = ts.data.isNotEmpty ? ts.data.last.value : null;
    final prev = ts.data.length > 1 ? ts.data[ts.data.length - 2].value : null;
    double? chg;
    if (last != null && prev != null && prev != 0) {
      chg = ((last - prev) / prev) * 100;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              last?.toStringAsFixed(ts.indicator.decimalPlaces) ?? '-',
              style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(ts.indicator.unit,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          const SizedBox(width: 12),
          if (chg != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (chg >= 0 ? const Color(0xFF4ECDC4) : const Color(0xFFFF6B6B))
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${chg >= 0 ? '+' : ''}${chg.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: chg >= 0 ? const Color(0xFF4ECDC4) : const Color(0xFFFF6B6B),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        elevation: 0,
        color: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2A2A4A)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.trending_up, size: 18, color: Color(0xFF4ECDC4)),
                SizedBox(width: 8),
                Text('Trend Analizi', style: TextStyle(fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              _row('Trend yönü', trend['direction_tr'] ?? ''),
              if (trend['r_squared'] != null)
                _row('R²', (trend['r_squared'] as num).toStringAsFixed(3)),
              if (_trendResult!['volatility_pct'] != null)
                _row('Volatilite', '%${(_trendResult!['volatility_pct'] as num).toStringAsFixed(1)}'),
              _row('Dönem yükseği', _trendResult!['period_high']?.toString() ?? '-'),
              _row('Dönem düşüğü', _trendResult!['period_low']?.toString() ?? '-'),
              if (recent['last_3_months'] != null) ...[
                const Divider(height: 20, color: Color(0xFF2A2A4A)),
                _row('Son 3 ay', '%${recent['last_3_months']['percent_change']}'),
              ],
              if (recent['last_12_months'] != null)
                _row('Son 12 ay', '%${recent['last_12_months']['percent_change']}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
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
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ind.nameTr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(ind.nameEn, style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 16),
            _row('EVDS Kodu', ind.evdsCode),
            _row('Birim', ind.unit),
            _row('Frekans', ind.frequency),
            _row('Kaynak', ind.source),
            _row('Veri sayısı', '${_timeSeries!.data.length}'),
            _row('Dönem', '${_timeSeries!.periodStart} → ${_timeSeries!.periodEnd}'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}