import 'package:flutter/material.dart';
import '../config/chart_config_builder.dart';
import '../models/international_models.dart';
import '../services/international_api_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/plotly_chart.dart';

/// Ülkeler Arası Kıyaslama Ekranı
///
/// Dünya Bankası verileriyle Türkiye'yi diğer ülkelerle karşılaştırır.
/// Gösterge seç → Ülkeleri seç → Grafik ve tablo görüntüle
class CountryComparisonScreen extends StatefulWidget {
  const CountryComparisonScreen({super.key});

  @override
  State<CountryComparisonScreen> createState() =>
      _CountryComparisonScreenState();
}

class _CountryComparisonScreenState extends State<CountryComparisonScreen> {
  final _intlApi = InternationalApiService();
  final _chartBuilder = ChartConfigBuilder();

  // Veri state
  List<Country> _countries = [];
  List<IntlIndicator> _indicators = [];
  bool _loadingInit = true;
  String? _error;

  // Seçim state
  IntlIndicator? _selectedIndicator;
  final Set<String> _selectedCountryCodes = {'TUR'};  // Türkiye her zaman seçili
  int _startYear = 2010;
  int _endYear = DateTime.now().year;

  // Sonuç state
  bool _isComparing = false;
  IntlComparisonResult? _result;
  Map<String, dynamic>? _plotlyConfig;

  // Ülke renk haritası
  static const Map<String, String> _countryColors = {
    'TUR': '#FF6B6B', 'USA': '#4ECDC4', 'DEU': '#45B7D1',
    'GBR': '#96CEB4', 'FRA': '#FFEAA7', 'JPN': '#DDA0DD',
    'CHN': '#F7DC6F', 'BRA': '#85C1E9', 'ARG': '#F1948A',
    'RUS': '#98D8C8', 'IND': '#BB86FC', 'ZAF': '#FF7043',
    'MEX': '#03DAC6', 'KOR': '#CF6679', 'SAU': '#FFA726',
    'POL': '#66BB6A', 'IDN': '#AB47BC', 'EGY': '#26A69A',
    'NGA': '#EF5350', 'GRC': '#42A5F5',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _intlApi.getCountries(),
        _intlApi.getIntlIndicators(),
      ]);

      setState(() {
        _countries = results[0] as List<Country>;
        _indicators = results[1] as List<IntlIndicator>;
        _loadingInit = false;

        // Varsayılan olarak ilk göstergeyi seç
        if (_indicators.isNotEmpty) {
          _selectedIndicator = _indicators.first;
        }
        // Varsayılan ülkeler: TUR + USA + DEU
        _selectedCountryCodes.addAll(['USA', 'DEU']);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingInit = false;
      });
    }
  }

  Future<void> _runComparison() async {
    if (_selectedIndicator == null || _selectedCountryCodes.length < 2) return;

    setState(() {
      _isComparing = true;
      _error = null;
      _plotlyConfig = null;
      _result = null;
    });

    try {
      final result = await _intlApi.getIntlComparison(
        indicatorId: _selectedIndicator!.id,
        countryCodes: _selectedCountryCodes.toList(),
        startYear: _startYear,
        endYear: _endYear,
      );

      // Plotly config oluştur
      final seriesData = <Map<String, dynamic>>[];
      for (final s in result.series) {
        if (s.data.isEmpty) continue;
        final color = _countryColors[s.isoCode] ?? '#999';
        seriesData.add({
          'name': '${s.flagEmoji ?? ''} ${s.nameTr}',
          'unit': _selectedIndicator!.unit,
          'data': s.data.map((d) => {'date': d.date, 'value': d.value}).toList(),
          '_color': color,
        });
      }

      Map<String, dynamic>? config;
      if (seriesData.isNotEmpty) {
        config = _chartBuilder.build(
          chartType: 'line',
          seriesData: seriesData,
          title: _selectedIndicator!.nameTr,
        );
      }

      setState(() {
        _result = result;
        _plotlyConfig = config;
        _isComparing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Kıyaslama hatası: $e';
        _isComparing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ülke Kıyaslama'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            tooltip: 'Kaynak: Dünya Bankası',
            onPressed: _showSourceInfo,
          ),
        ],
      ),
      body: _loadingInit
          ? const StateWidget(isLoading: true)
          : _error != null && _result == null && _indicators.isEmpty
              ? StateWidget(error: _error, onRetry: _loadInitialData)
              : SafeArea(
                  child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Kaynak bilgisi
                      _buildSourceBadge(),
                      const SizedBox(height: 12),

                      // ⚠️ Gösterge yoksa uyarı
                      if (_indicators.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(children: [
                                Icon(Icons.warning_amber, size: 18, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Gösterge bulunamadı',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange)),
                              ]),
                              const SizedBox(height: 6),
                              Text(
                                'Uluslararası göstergeler henüz yüklenmemiş. '
                                'Backend\'de schema_v2_migration.sql çalıştırıldığından '
                                've fetch_international.php ile veriler çekildiğinden emin olun.',
                                style: TextStyle(fontSize: 12, color: Colors.grey[400], height: 1.5),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _loadInitialData,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Tekrar Dene', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Gösterge seçici
                      if (_indicators.isNotEmpty) ...[
                        _buildIndicatorSelector(),
                        const SizedBox(height: 16),
                      ],

                      // Ülke seçici
                      _buildCountrySelector(),
                      const SizedBox(height: 12),

                      // Yıl aralığı
                      _buildYearRange(),
                      const SizedBox(height: 16),

                      // Karşılaştır butonu
                      FilledButton.icon(
                        onPressed: _selectedIndicator != null &&
                                _selectedCountryCodes.length >= 2 &&
                                !_isComparing
                            ? _runComparison
                            : null,
                        icon: _isComparing
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.public),
                        label: Text(_isComparing
                            ? 'Karşılaştırılıyor...'
                            : 'Karşılaştır (${_selectedCountryCodes.length} ülke)'),
                      ),

                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline, size: 16, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_error!,
                                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Grafik
                      if (_plotlyConfig != null) ...[
                        const SizedBox(height: 24),
                        PlotlyChart(
                          plotlyConfig: _plotlyConfig!,
                          height: 380,
                          darkMode: isDark,
                        ),
                      ],

                      // Son değerler tablosu
                      if (_result != null && _result!.series.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildLatestValuesTable(),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildSourceBadge() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.public, size: 16, color: Color(0xFF45B7D1)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Veri Kaynağı: Dünya Bankası Open Data • Yıllık veriler',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorSelector() {
    // Kategoriye göre grupla
    final byCategory = <String, List<IntlIndicator>>{};
    for (final ind in _indicators) {
      final cat = ind.categoryNameTr ?? 'Diğer';
      byCategory.putIfAbsent(cat, () => []).add(ind);
    }

    return DropdownButtonFormField<int>(
      value: _selectedIndicator?.id,
      decoration: const InputDecoration(
        labelText: 'Gösterge',
        prefixIcon: Icon(Icons.assessment, size: 20),
        border: OutlineInputBorder(),
        isDense: true,
      ),
      isExpanded: true,
      items: _indicators.map((ind) {
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
          setState(() {
            _selectedIndicator = _indicators.firstWhere((i) => i.id == id);
          });
        }
      },
    );
  }

  Widget _buildCountrySelector() {
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
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[300])),
                const Spacer(),
                Text('${_selectedCountryCodes.length}/10',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _countries.map((country) {
                final isSelected = _selectedCountryCodes.contains(country.isoCode);
                final isTurkey = country.isoCode == 'TUR';
                final color = _countryColors[country.isoCode];

                return FilterChip(
                  label: Text(
                    '${country.flagEmoji ?? ''} ${country.nameTr}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.black : Colors.grey[300],
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: color != null
                      ? Color(int.parse(color.replaceFirst('#', '0xFF')))
                      : const Color(0xFF4ECDC4),
                  backgroundColor: const Color(0xFF16213E),
                  checkmarkColor: Colors.black,
                  side: BorderSide(
                    color: isSelected
                        ? Colors.transparent
                        : const Color(0xFF2A2A4A),
                  ),
                  onSelected: isTurkey
                      ? null // Türkiye kaldırılamaz
                      : (val) {
                          setState(() {
                            if (val && _selectedCountryCodes.length < 10) {
                              _selectedCountryCodes.add(country.isoCode);
                            } else {
                              _selectedCountryCodes.remove(country.isoCode);
                            }
                          });
                        },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('🇹🇷 Türkiye her zaman dahil',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                const Spacer(),
                if (_selectedCountryCodes.length > 1)
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedCountryCodes.clear();
                      _selectedCountryCodes.add('TUR');
                    }),
                    child: Text('Sadece Türkiye',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500],
                            decoration: TextDecoration.underline)),
                  ),
              ],
            ),
            // Hızlı seçim grupları
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _quickGroupChip('G7', ['TUR', 'USA', 'DEU', 'GBR', 'FRA', 'JPN']),
                _quickGroupChip('BRICS+', ['TUR', 'BRA', 'RUS', 'IND', 'CHN', 'ZAF']),
                _quickGroupChip('Komşular', ['TUR', 'GRC', 'RUS', 'EGY']),
                _quickGroupChip('Gelişmekte', ['TUR', 'BRA', 'MEX', 'ARG', 'IDN', 'IND']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickGroupChip(String label, List<String> codes) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      onPressed: () {
        setState(() {
          _selectedCountryCodes.clear();
          _selectedCountryCodes.addAll(codes);
        });
      },
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      backgroundColor: const Color(0xFF16213E),
      side: const BorderSide(color: Color(0xFF2A2A4A)),
    );
  }

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
              if (v != null && v >= 1960 && v < _endYear) {
                setState(() => _startYear = v);
              }
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
              if (v != null && v > _startYear && v <= DateTime.now().year) {
                setState(() => _endYear = v);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLatestValuesTable() {
    final series = _result!.series.where((s) => s.data.isNotEmpty).toList();
    if (series.isEmpty) return const SizedBox();

    // Her ülkenin son değerini al ve sırala
    final entries = series.map((s) {
      final last = s.data.last;
      return _TableEntry(
        flag: s.flagEmoji ?? '',
        name: s.nameTr,
        iso: s.isoCode,
        value: last.value,
        date: last.date,
      );
    }).toList();

    // Değere göre sırala (büyükten küçüğe)
    entries.sort((a, b) => b.value.compareTo(a.value));

    return Card(
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
            Row(
              children: [
                const Icon(Icons.leaderboard, size: 18, color: Color(0xFF4ECDC4)),
                const SizedBox(width: 8),
                const Text('Son Değerler (Sıralama)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                Text(_selectedIndicator?.unit ?? '',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 12),
            ...entries.asMap().entries.map((e) {
              final idx = e.key;
              final entry = e.value;
              final isTurkey = entry.iso == 'TUR';

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: isTurkey
                      ? const Color(0xFFFF6B6B).withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isTurkey
                      ? Border.all(color: const Color(0xFFFF6B6B).withOpacity(0.2))
                      : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '#${idx + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: idx == 0
                              ? const Color(0xFFFFD700)
                              : Colors.grey[500],
                        ),
                      ),
                    ),
                    Text(entry.flag, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isTurkey ? FontWeight.bold : FontWeight.normal,
                          color: isTurkey ? const Color(0xFFFF6B6B) : null,
                        ),
                      ),
                    ),
                    Text(
                      entry.value.toStringAsFixed(_selectedIndicator?.decimalPlaces ?? 2),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isTurkey ? const Color(0xFFFF6B6B) : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      entry.date.substring(0, 4),
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
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

  void _showSourceInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.35,
        minChildSize: 0.2,
        maxChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('Veri Kaynağı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Dünya Bankası Open Data API', style: TextStyle(color: Colors.grey[300])),
              const SizedBox(height: 8),
              Text('Veriler yıllık bazda güncellenir. Son veri genellikle 1-2 yıl gecikmeli olabilir.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400], height: 1.5)),
              const SizedBox(height: 8),
              Text('URL: api.worldbank.org/v2/',
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.grey[500])),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableEntry {
  final String flag;
  final String name;
  final String iso;
  final double value;
  final String date;

  _TableEntry({
    required this.flag,
    required this.name,
    required this.iso,
    required this.value,
    required this.date,
  });
}