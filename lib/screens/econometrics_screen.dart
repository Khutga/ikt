import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/econometrics_api_service.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

/// Ekonometrik Analiz Ekranı
///
/// Tez: "Sürdürülebilir Kalkınma Sürecinde Yeşil Ekonomiye Geçişin Rolü"
///
/// Akış: Yöntem seç → Gösterge seç → Analiz çalıştır → Sonuçları görüntüle
class EconometricsScreen extends StatefulWidget {
  const EconometricsScreen({super.key});

  @override
  State<EconometricsScreen> createState() => _EconometricsScreenState();
}

class _EconometricsScreenState extends State<EconometricsScreen> {
  final _api = ApiService();
  final _econApi = EconometricsApiService();

  // Veri state
  List<Indicator> _indicators = [];
  bool _loadingIndicators = true;
  String? _error;

  // Seçim state
  EconMethod? _selectedMethod;
  final List<Indicator> _selectedIndicators = [];
  int _dependentIndex = 0;
  String _period = '5y';
  final Map<String, dynamic> _params = {};

  // Analiz state
  bool _isAnalyzing = false;
  Map<String, dynamic>? _result;
  String? _analysisError;

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

  Future<void> _runAnalysis() async {
    if (_selectedMethod == null || _selectedIndicators.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
      _result = null;
    });

    try {
      // Her gösterge için veri çek
      final seriesData = <Map<String, dynamic>>[];
      for (final ind in _selectedIndicators) {
        final ts = await _api.getTimeSeriesData(ind.id, period: _period);
        seriesData.add(ts.toAnalysisFormat());
      }

      final result = await _econApi.runAnalysis(
        method: _selectedMethod!.id,
        seriesData: seriesData,
        params: _params,
        dependentIndex: _dependentIndex,
      );

      if (!mounted) return;
      setState(() {
        _result = result['result'] as Map<String, dynamic>? ?? result;
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

  @override
  Widget build(BuildContext context) {
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
                    // 1. Yöntem seçimi
                    _buildMethodSelector(),
                    const SizedBox(height: 16),

                    // 2. Gösterge seçimi
                    if (_selectedMethod != null) ...[
                      _buildIndicatorSelector(),
                      const SizedBox(height: 12),
                    ],

                    // 3. Periyot
                    if (_selectedMethod != null && _selectedIndicators.isNotEmpty) ...[
                      _buildPeriodAndParams(),
                      const SizedBox(height: 16),

                      // Bağımlı değişken seçimi
                      if (_selectedMethod!.needsDependent &&
                          _selectedIndicators.length >= 2)
                        _buildDependentSelector(),

                      // Analiz butonu
                      _buildAnalyzeButton(),
                    ],

                    // Hata
                    if (_analysisError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Text(_analysisError!,
                              style: const TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                      ),

                    // Sonuçlar
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
            final color = Color(
                int.parse(method.color.replaceFirst('#', '0xFF')));

            return GestureDetector(
              onTap: () => setState(() {
                _selectedMethod = method;
                _selectedIndicators.clear();
                _result = null;
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
                        Icon(
                          _getMethodIcon(method.icon),
                          size: 18,
                          color: isSelected ? color : Colors.grey[500],
                        ),
                        const Spacer(),
                        if (isSelected)
                          Icon(Icons.check_circle, size: 16, color: color),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      method.nameTr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? color : Colors.grey[300],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      method.description,
                      style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
  //  GÖSTERGE SEÇİCİ
  // ═══════════════════════════════════════════

  Widget _buildIndicatorSelector() {
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
                Text('Gösterge Seç',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[300])),
                const Spacer(),
                Text(
                  '${_selectedIndicators.length}/${method.maxSeries}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            Text(
              'En az ${method.minSeries}, en fazla ${method.maxSeries} gösterge',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _indicators.map((ind) {
                final isSelected = _selectedIndicators.contains(ind);
                return FilterChip(
                  label: Text(
                    _shortenName(ind.nameTr),
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.black : Colors.grey[300],
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF4ECDC4),
                  backgroundColor: const Color(0xFF16213E),
                  checkmarkColor: Colors.black,
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF4ECDC4)
                        : const Color(0xFF2A2A4A),
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val && _selectedIndicators.length < method.maxSeries) {
                        _selectedIndicators.add(ind);
                      } else {
                        _selectedIndicators.remove(ind);
                      }
                      _result = null;
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
  //  PERİYOT & PARAMETRE
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
                    color: isSelected ? Colors.black : null,
                  )),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        value: _dependentIndex < _selectedIndicators.length
            ? _dependentIndex
            : 0,
        decoration: const InputDecoration(
          labelText: 'Bağımlı Değişken (Y)',
          prefixIcon: Icon(Icons.arrow_forward, size: 18),
          border: OutlineInputBorder(),
          isDense: true,
        ),
        isExpanded: true,
        items: _selectedIndicators.asMap().entries.map((e) {
          return DropdownMenuItem(
            value: e.key,
            child: Text(e.value.nameTr, style: const TextStyle(fontSize: 13)),
          );
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

  Widget _buildAnalyzeButton() {
    final method = _selectedMethod!;
    final canRun = _selectedIndicators.length >= method.minSeries && !_isAnalyzing;

    return FilledButton.icon(
      onPressed: canRun ? _runAnalysis : null,
      icon: _isAnalyzing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.play_arrow),
      label: Text(_isAnalyzing
          ? 'Analiz ediliyor...'
          : '${method.nameTr} Çalıştır'),
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
              child: Text(
                '${_selectedMethod?.nameTr ?? "Analiz"} Sonuçları',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF4ECDC4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Yorum kartı
        if (_result!['interpretation_tr'] != null)
          _buildInterpretationCard(_result!['interpretation_tr']),

        // Sonuç detayları — yönteme göre farklı render
        if (_selectedMethod?.id == 'unit_root') _buildUnitRootResults(),
        if (_selectedMethod?.id == 'granger') _buildGrangerResults(),
        if (_selectedMethod?.id == 'cointegration') _buildCointegrationResults(),
        if (_selectedMethod?.id == 'descriptive') _buildDescriptiveResults(),
        if (_selectedMethod?.id == 'ols') _buildOlsResults(),
        if (_selectedMethod?.id == 'garch') _buildGarchResults(),
        if (_selectedMethod?.id == 'full_analysis') _buildFullAnalysisResults(),

        // Ham JSON (geliştirme / detay)
        _buildRawJsonToggle(),
      ],
    );
  }

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
              const Row(
                children: [
                  Icon(Icons.lightbulb, size: 16, color: Color(0xFFFFA726)),
                  SizedBox(width: 8),
                  Text('Yorum',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFFFFA726))),
                ],
              ),
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

  // ── Birim Kök Sonuçları ──
  Widget _buildUnitRootResults() {
    final data = _result!;
    // Tek seri veya çoklu seri
    final seriesResults = data['series_results'] as List? ?? [data];

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
            side: const BorderSide(color: Color(0xFF2A2A4A)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: io == 0
                            ? const Color(0xFF4ECDC4).withOpacity(0.2)
                            : const Color(0xFFFFA726).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        io != null ? 'I($io)' : 'I(?)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: io == 0
                              ? const Color(0xFF4ECDC4)
                              : const Color(0xFFFFA726),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // ADF tablosu
                for (final level in ['levels', 'first_diff', 'second_diff'])
                  if (sr[level] != null && sr[level] is Map && sr[level]['adf'] != null)
                    _buildTestRow(
                      level == 'levels'
                          ? 'Düzey'
                          : level == 'first_diff'
                              ? '1. Fark'
                              : '2. Fark',
                      sr[level],
                    ),
                const SizedBox(height: 8),
                Text(interp,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[400], height: 1.5)),
              ],
            ),
          ),
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
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ),
          Expanded(
            child: Text(
              'ADF: ${adf['statistic']}${adf['stars'] ?? ""} (p=${adf['p_value']})',
              style: TextStyle(
                fontSize: 11,
                color: adf['is_stationary'] == true
                    ? const Color(0xFF4ECDC4)
                    : Colors.grey[400],
              ),
            ),
          ),
          if (kpss != null && kpss['statistic'] != null)
            Text(
              'KPSS: ${kpss['statistic']}',
              style: TextStyle(
                fontSize: 11,
                color: kpss['is_stationary'] == true
                    ? const Color(0xFF4ECDC4)
                    : Colors.grey[400],
              ),
            ),
        ],
      ),
    );
  }

  // ── Granger Sonuçları ──
  Widget _buildGrangerResults() {
    final tests = _result!['tests'] as List? ?? [];
    final summary = _result!['summary_tr'] ?? '';

    return Card(
      elevation: 0,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2A2A4A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...tests.map<Widget>((test) {
              final isCausal = test['is_granger_cause'] == true;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      isCausal ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: isCausal
                          ? const Color(0xFF4ECDC4)
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        test['direction'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isCausal ? FontWeight.w600 : FontWeight.normal,
                          color: isCausal
                              ? const Color(0xFF4ECDC4)
                              : Colors.grey[500],
                        ),
                      ),
                    ),
                    Text(
                      'p=${test['best_p_value']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isCausal
                            ? const Color(0xFF4ECDC4)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (summary.isNotEmpty) ...[
              const Divider(height: 20, color: Color(0xFF2A2A4A)),
              Text(summary,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[400], height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Eşbütünleşme ──
  Widget _buildCointegrationResults() {
    final eg = _result!['engle_granger'] as Map<String, dynamic>?;
    if (eg == null) return const SizedBox();

    final isCoint = eg['is_cointegrated'] == true;

    return Card(
      elevation: 0,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2A2A4A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Icon(
                    isCoint ? Icons.link : Icons.link_off,
                    size: 36,
                    color: isCoint
                        ? const Color(0xFF4ECDC4)
                        : const Color(0xFFFF6B6B),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isCoint ? 'Eşbütünleşme VAR' : 'Eşbütünleşme YOK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCoint
                          ? const Color(0xFF4ECDC4)
                          : const Color(0xFFFF6B6B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _kv('Test İstatistiği', '${eg['statistic']}${eg['stars'] ?? ""}'),
            _kv('p-değeri', '${eg['p_value']}'),
            if (eg['critical_values'] != null)
              _kv('Kritik Değerler',
                  '1%: ${eg['critical_values']['1%']}, 5%: ${eg['critical_values']['5%']}, 10%: ${eg['critical_values']['10%']}'),
          ],
        ),
      ),
    );
  }

  // ── Tanımlayıcı İstatistik ──
  Widget _buildDescriptiveResults() {
    final vars = _result!['variables'] as List? ?? [];
    return Card(
      elevation: 0,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2A2A4A)),
      ),
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
              DataColumn(label: Text('Değişken', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('N', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Ort.', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Medyan', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Std', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Min', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Max', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Çarpıklık', style: TextStyle(fontSize: 11))),
              DataColumn(label: Text('Basıklık', style: TextStyle(fontSize: 11))),
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
                DataCell(Text(
                    '${jb['statistic'] ?? "-"}${jb['stars'] ?? ""}',
                    style: const TextStyle(fontSize: 10))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── OLS ──
  Widget _buildOlsResults() {
    final r = _result!;
    final coefs = r['coefficients'] as Map<String, dynamic>? ?? {};

    return Card(
      elevation: 0,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2A2A4A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(e.key,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[400])),
                    ),
                    Expanded(
                      child: Text(
                        '${c['value']}${c['stars'] ?? ""} (t=${c['t_stat']}, p=${c['p_value']})',
                        style: TextStyle(
                          fontSize: 11,
                          color: c['significant'] == true
                              ? const Color(0xFF4ECDC4)
                              : Colors.grey[500],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── GARCH ──
  Widget _buildGarchResults() {
    final model = _result!['garch_model'] as Map<String, dynamic>?;
    final archLm = _result!['arch_lm_test'] as Map<String, dynamic>?;

    return Card(
      elevation: 0,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2A2A4A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
          ],
        ),
      ),
    );
  }

  // ── Tam Analiz ──
  Widget _buildFullAnalysisResults() {
    final sections = _result!['sections'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  border: Border.all(color: const Color(0xFF2A2A4A)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
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
                              fontSize: 11, color: Colors.grey[300])),
                    ),
                  ],
                ),
              ),
            );
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
      ],
    );
  }

  // ── Ham JSON Toggle ──
  bool _showRawJson = false;
  Widget _buildRawJsonToggle() {
    return Column(
      children: [
        const SizedBox(height: 16),
        InkWell(
          onTap: () => setState(() => _showRawJson = !_showRawJson),
          child: Row(
            children: [
              Icon(
                _showRawJson ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: Colors.grey[600],
              ),
              Text('Ham JSON',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ),
        if (_showRawJson)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F23),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(_result),
              style: TextStyle(
                  fontSize: 9, fontFamily: 'monospace', color: Colors.grey[500]),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  YARDIMCI
  // ═══════════════════════════════════════════

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
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
